# ABOUTME: Verifies consented Google Books discovery with minimized queries.
# ABOUTME: Prevents raw reading titles and repeated external searches from leaking outward.
require "test_helper"

class GoogleBooksCatalogDiscoveryTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:calls) do
    def search(query:, limit:, language:, start_index: 0)
      calls << { query:, limit:, language:, start_index: }
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

  PagedClient = Struct.new(:calls) do
    def search(query:, limit:, language:, start_index: 0)
      calls << { query:, limit:, language:, start_index: }
      Array.new(limit) do |offset|
        number = start_index + offset
        base = format("9780000%05d", number)
        checksum = (10 - base.chars.each_with_index.sum { |digit, index| digit.to_i * (index.even? ? 1 : 3) } % 10) % 10
        {
          "volumeInfo" => {
            "title" => "公開候補#{number}",
            "authors" => [ "公開著者" ],
            "industryIdentifiers" => [ { "type" => "ISBN_13", "identifier" => "#{base}#{checksum}" } ],
            "categories" => [ "Science" ],
            "language" => "ja"
          }
        }
      end
    end
  end

  test "discovers public candidates using authors then public result subjects" do
    profile = profile_with(author: "同意済み著者", summary: "外部へ送らない生の履歴情報")
    client = FakeClient.new([])
    target_size = Book.recommendable.count + 2

    result = GoogleBooksCatalogDiscovery.new(profile:, client:, target_size:).call

    assert_operator result.updated_books, :>=, 2
    assert_equal [ "inauthor:同意済み著者", "subject:Science Fiction" ], client.calls.pluck(:query)
    refute client.calls.any? { |call| call[:query].include?(profile.summary) }
    assert Book.find_by!(isbn: "9784152100009").recommendable?
    assert_equal "google_books_discovery", Book.find_by!(isbn: "9784152100016").metadata_source
  end

  test "uses a digest record instead of sending the same query again" do
    profile = profile_with(author: "再送しない著者", summary: "要約")
    first_client = FakeClient.new([])
    target_size = Book.recommendable.count + 2
    GoogleBooksCatalogDiscovery.new(profile:, client: first_client, target_size:).call
    second_client = FakeClient.new([])

    GoogleBooksCatalogDiscovery.new(profile:, client: second_client, target_size:).call

    assert_equal 2, first_client.calls.length
    assert_empty first_client.calls & second_client.calls
  end

  test "pages until the catalog reaches its target without exceeding it" do
    profile = profile_with(author: "ページング著者", summary: "要約")
    client = PagedClient.new([])
    target_size = Book.recommendable.count + 45

    result = GoogleBooksCatalogDiscovery.new(profile:, client:, target_size:).call

    assert_equal target_size, Book.recommendable.count
    assert_equal [ 0, 20, 40 ], client.calls.pluck(:start_index)
    assert_equal [ 20, 20, 5 ], client.calls.pluck(:limit)
    assert_equal 3, result.external_queries
  end

  test "continues without candidates when Google Books is rate limited" do
    profile = profile_with(author: "制限中の著者", summary: "要約")
    client = Object.new
    client.define_singleton_method(:search) { |**| raise Net::HTTPClientException.new("rate limited", Object.new) }

    result = GoogleBooksCatalogDiscovery.new(profile:, client:, seed_queries: []).call

    assert_equal 0, result.updated_books
    assert_equal 1, result.external_queries
    assert_equal(-1, CatalogDiscoveryQuery.last.result_count)
  end

  test "continues with the next minimized signal after one query fails" do
    profile = profile_with(author: "制限中の著者", summary: "要約")
    profile.update!(favorite_authors: [ "制限中の著者", "継続する著者" ])
    target_size = Book.recommendable.count + 1
    calls = []
    client = Object.new
    client.define_singleton_method(:search) do |query:, **|
      calls << query
      raise Net::HTTPClientException.new("rate limited", Object.new) if query.include?("制限中")

      [ {
        "volumeInfo" => {
          "title" => "継続して取得した公開候補",
          "authors" => [ "公開著者" ],
          "industryIdentifiers" => [ { "type" => "ISBN_13", "identifier" => "9784152100009" } ],
          "categories" => [],
          "language" => "ja"
        }
      } ]
    end

    result = GoogleBooksCatalogDiscovery.new(profile:, client:, target_size:).call

    assert_equal [ "inauthor:制限中の著者", "inauthor:継続する著者" ], calls
    assert_equal 1, result.updated_books
  end

  test "uses public seed queries only after personalized discovery is exhausted" do
    profile = profile_with(author: "候補なし著者", summary: "要約")
    calls = []
    client = Object.new
    client.define_singleton_method(:search) do |query:, **|
      calls << query
      next [] if query.start_with?("inauthor:")

      [ {
        "volumeInfo" => {
          "title" => "固定分野から取得した公開候補",
          "authors" => [ "公開著者" ],
          "industryIdentifiers" => [ { "type" => "ISBN_13", "identifier" => "9784152100009" } ],
          "categories" => [ "Science" ],
          "language" => "ja"
        }
      } ]
    end
    target_size = Book.recommendable.count + 1

    GoogleBooksCatalogDiscovery.new(profile:, client:, target_size:, seed_queries: [ "科学" ]).call

    assert_equal [ "inauthor:候補なし著者", "科学" ], calls
  end

  private

  def profile_with(author:, summary:)
    user = User.create!(name: "読書家#{author}")
    ReadingProfile.create!(user:, summary:, favorite_topics: [ "非送信タグ" ], favorite_authors: [ author ], preferred_categories: [], generated_at: Time.current)
  end
end
