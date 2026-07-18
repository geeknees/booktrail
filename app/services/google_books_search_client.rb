# ABOUTME: Fetches public Google Books volumes with bounded unauthenticated queries.
# ABOUTME: Applies timeouts and sends only the explicit discovery query parameters.
require "json"
require "net/http"

class GoogleBooksSearchClient
  ENDPOINT = "https://www.googleapis.com/books/v1/volumes"
  TIMEOUT_SECONDS = 5
  MAX_RETRIES = 3
  MIN_INTERVAL_SECONDS = 0.75

  def initialize(requester: nil, sleeper: Kernel.method(:sleep), clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @requester = requester || method(:request)
    @sleeper = sleeper
    @clock = clock
  end

  def search(query:, limit:, language: "ja")
    uri = URI(ENDPOINT)
    parameters = {
      q: query,
      maxResults: limit.to_i.clamp(1, 40),
      langRestrict: language,
      printType: "books",
      orderBy: "relevance",
      projection: "full"
    }
    parameters[:key] = ENV["GOOGLE_BOOKS_API_KEY"] if ENV["GOOGLE_BOOKS_API_KEY"].present?
    uri.query = URI.encode_www_form(parameters)
    throttle

    attempts = 0
    loop do
      response = @requester.call(uri)
      if response.code == "429" && attempts < MAX_RETRIES
        attempts += 1
        wait = response["Retry-After"].to_i
        @sleeper.call((wait.positive? ? wait : 2**attempts).clamp(1, 15))
        next
      end

      response.value
      @last_request_at = @clock.call
      return JSON.parse(response.body).fetch("items", [])
    end
  end

  private

  def request(uri)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Booktrail/1.0"
      http.request(request)
    end
    response
  end

  def throttle
    return unless @last_request_at

    remaining = MIN_INTERVAL_SECONDS - (@clock.call - @last_request_at)
    @sleeper.call(remaining) if remaining.positive?
  end
end
