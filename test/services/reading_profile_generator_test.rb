# ABOUTME: Verifies that strong positive reading signals dominate profile generation.
# ABOUTME: Protects the public wording from unsupported claims about reader ability.
require "test_helper"

class ReadingProfileGeneratorTest < ActiveSupport::TestCase
  test "high ratings influence preferences while low ratings do not strengthen them" do
    user = User.create!(name: "読書家")
    loved = Book.create!(isbn: "9784152098702", title: "三体", author: "劉慈欣", categories: [ "SF", "宇宙" ], page_count: 448)
    disliked = Book.create!(isbn: "9784101010014", title: "坊っちゃん", author: "夏目漱石", categories: [ "古典" ])
    user.reading_records.create!(book: loved, rating: 5, reading_status: "読了")
    user.reading_records.create!(book: disliked, rating: 1, reading_status: "読了")

    profile = ReadingProfileGenerator.new(user:).call

    assert_includes profile.preferred_categories, "SF"
    refute_includes profile.preferred_categories, "古典"
    refute_match(/読解力|読書レベル/, profile.summary)
  end
end
