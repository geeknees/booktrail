# ABOUTME: Enriches ISBN books from documented APIs with timeouts and durable caching.
# ABOUTME: Tries openBD first, Google Books second, and preserves CSV data otherwise.
require "net/http"
require "json"

class BookMetadataProvider
  TIMEOUT_SECONDS = 4
  CACHE_TTL = 30.days

  def fetch(isbn)
    Rails.cache.fetch("book-metadata/v1/#{isbn}", expires_in: CACHE_TTL) do
      openbd(isbn) || google_books(isbn) || {}
    end
  end

  private

  def openbd(isbn)
    item = get_json("https://api.openbd.jp/v1/get", isbn:).first
    return unless item
    summary = item.fetch("summary", {})
    onix = item.fetch("onix", {})
    {
      title: summary["title"], author: summary["author"], publisher: summary["publisher"], cover_image_url: summary["cover"],
      published_on: date(summary["pubdate"]), description: onix.dig("CollateralDetail", "TextContent")&.first&.dig("Text"), metadata_source: "openbd"
    }.compact
  rescue NoMethodError
    nil
  end

  def google_books(isbn)
    volume = get_json("https://www.googleapis.com/books/v1/volumes", q: "isbn:#{isbn}").fetch("items", []).first&.fetch("volumeInfo", nil)
    return unless volume
    {
      title: volume["title"], author: Array(volume["authors"]).join("、"), publisher: volume["publisher"], published_on: date(volume["publishedDate"]),
      page_count: volume["pageCount"], description: volume["description"], cover_image_url: volume.dig("imageLinks", "thumbnail"),
      categories: volume["categories"], language: volume["language"], metadata_source: "google_books"
    }.compact
  end

  def get_json(url, parameters)
    uri = URI(url)
    uri.query = URI.encode_www_form(parameters)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Booktrail/1.0"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) { |http| http.request(request) }
    response.value
    JSON.parse(response.body)
  end

  def date(value)
    return if value.blank?
    Date.strptime(value, value.length == 4 ? "%Y" : value.length == 6 ? "%Y%m" : value.include?("-") ? "%Y-%m-%d" : "%Y%m%d")
  rescue Date::Error
    nil
  end
end
