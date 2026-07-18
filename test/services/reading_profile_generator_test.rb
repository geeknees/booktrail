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

  test "recognizes Booklog's current-reading status" do
    user = User.create!(name: "読書家")
    book = Book.create!(title: "読書中の本", categories: [ "科学" ])
    record = user.reading_records.create!(book:, reading_status: "いま読んでる")

    assert_equal 0.8, ReadingProfileGenerator.weight_for(record)
  end

  test "uses tags as reader-safe interests when imported books have no categories" do
    user = User.create!(name: "読書家")
    book = Book.create!(title: "カテゴリのない本", author: "著者")
    user.reading_records.create!(book:, rating: 5, reading_status: "読み終わった", tags: [ "宇宙" ])

    profile = ReadingProfileGenerator.new(user:).call

    assert_includes profile.favorite_topics, "宇宙"
    assert_includes profile.summary, "宇宙"
  end

  test "generates the profile summary in the active locale" do
    user = User.create!(name: "Reader", locale: "en")
    book = Book.create!(title: "Science Story", author: "Author", categories: [ "Science" ], page_count: 300)
    user.reading_records.create!(book:, rating: 5, reading_status: "読了")

    profile = I18n.with_locale(:en) { ReadingProfileGenerator.new(user:).call }

    assert_includes profile.summary, "Science"
    assert_includes profile.summary, "pages"
  end
end
