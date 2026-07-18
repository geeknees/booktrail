# ABOUTME: Verifies bounded Google Books parameters and rate-limit recovery.
# ABOUTME: Keeps public catalog discovery reliable without exposing query contents in logs.
require "test_helper"

class GoogleBooksSearchClientTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body, :retry_after) do
    def value
      raise Net::HTTPClientException.new("rate limited", self) unless code == "200"
    end

    def [](name)
      retry_after if name == "Retry-After"
    end
  end

  test "bounds public book search parameters" do
    requested_uri = nil
    requester = ->(uri) {
      requested_uri = uri
      Response.new("200", '{"items":[]}', nil)
    }

    GoogleBooksSearchClient.new(requester:).search(query: 'inauthor:"著者"', limit: 100, language: "ja")

    parameters = URI.decode_www_form(requested_uri.query).to_h
    assert_equal "40", parameters["maxResults"]
    assert_equal "books", parameters["printType"]
    assert_equal "ja", parameters["langRestrict"]
  end

  test "retries a rate-limited request using Retry-After" do
    responses = [ Response.new("429", "{}", "1"), Response.new("200", '{"items":[]}', nil) ]
    waits = []

    GoogleBooksSearchClient.new(requester: ->(_uri) { responses.shift }, sleeper: ->(seconds) { waits << seconds })
      .search(query: 'subject:"Science"', limit: 20, language: "ja")

    assert_equal [ 1 ], waits
    assert_empty responses
  end
end
