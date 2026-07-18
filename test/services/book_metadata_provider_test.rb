# ABOUTME: Verifies prioritized metadata merging across documented book APIs.
# ABOUTME: Ensures discovery fields are filled when openBD has only basic data.
require "test_helper"

class BookMetadataProviderTest < ActiveSupport::TestCase
  test "keeps openBD identity fields and fills missing discovery fields from Google Books" do
    provider_class = Class.new(BookMetadataProvider) do
      private

      def get_json(url, _parameters)
        if url.include?("openbd")
          [ { "summary" => { "title" => "一次情報の本", "author" => "著者", "publisher" => "出版社" }, "onix" => {} } ]
        else
          { "items" => [ { "volumeInfo" => { "title" => "別タイトル", "pageCount" => 320, "description" => "科学を物語で学ぶ本", "categories" => [ "Science" ], "language" => "ja" } } ] }
        end
      end
    end

    metadata = provider_class.new.fetch("9784101010014-test-merge")

    assert_equal "一次情報の本", metadata[:title]
    assert_equal 320, metadata[:page_count]
    assert_equal [ "Science" ], metadata[:categories]
    assert_equal "openbd+google_books", metadata[:metadata_source]
  end
end
