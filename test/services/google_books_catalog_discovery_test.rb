# ABOUTME: Verifies consented Google Books discovery with minimized queries.
# ABOUTME: Prevents raw reading titles and repeated external searches from leaking outward.
require "test_helper"

class GoogleBooksCatalogDiscoveryTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:calls) do
    def search(query:, limit:, language:)
      calls << { query:, limit:, language: }
      if query.start_with?("inauthor:")
        [ volume("9784152100009", "著者の未読作品", [ "Science Fiction" ]) ]
      else
        [ volume("9784152100016", "分野を広げる本", [ "Science" ]) ]
      end
    end

    private

    def volume(isbn, title, categories)
      {
        "volumeInfo" => {
          "title" => title,
          "authors" => [ "公開著者" ],
          "industryIdentifiers" => [ { "type" => "ISBN_13", "identifier" => isbn } ],
          "categories" => categories,
          "description" => "科学を物語で考える本",
          "pageCount" => 320,
          "language" => "ja"
        }
      }
    end
  end

  test "discovers public candidates using authors then public result subjects" do
    profile = profile_with(author: "同意済み著者", summary: "外部へ送らない生の履歴情報")
    client = FakeClient.new([])

    result = GoogleBooksCatalogDiscovery.new(profile:, client:).call

    assert_operator result.updated_books, :>=, 2
    assert_equal [ "inauthor:同意済み著者", "subject:Science Fiction" ], client.calls.pluck(:query)
    refute client.calls.any? { |call| call[:query].include?(profile.summary) }
    assert Book.find_by!(isbn: "9784152100009").recommendable?
    assert_equal "google_books_discovery", Book.find_by!(isbn: "9784152100016").metadata_source
  end

  test "uses a digest record instead of sending the same query again" do
    profile = profile_with(author: "再送しない著者", summary: "要約")
    first_client = FakeClient.new([])
    GoogleBooksCatalogDiscovery.new(profile:, client: first_client).call
    second_client = FakeClient.new([])

    GoogleBooksCatalogDiscovery.new(profile:, client: second_client).call

    assert_equal 2, first_client.calls.length
    assert_empty second_client.calls
  end

  test "continues without candidates when Google Books is rate limited" do
    profile = profile_with(author: "制限中の著者", summary: "要約")
    client = Object.new
    client.define_singleton_method(:search) { |**| raise Net::HTTPClientException.new("rate limited", Object.new) }

    result = GoogleBooksCatalogDiscovery.new(profile:, client:).call

    assert_equal 0, result.updated_books
    assert_equal 1, result.external_queries
    assert_equal(-1, CatalogDiscoveryQuery.last.result_count)
  end

  private

  def profile_with(author:, summary:)
    user = User.create!(name: "読書家#{author}")
    ReadingProfile.create!(user:, summary:, favorite_topics: [ "非送信タグ" ], favorite_authors: [ author ], preferred_categories: [], generated_at: Time.current)
  end
end
