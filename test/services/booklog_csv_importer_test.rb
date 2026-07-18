# ABOUTME: Exercises resilient Booklog CSV parsing and idempotent record updates.
# ABOUTME: Ensures malformed rows are isolated instead of aborting an import.
require "test_helper"

class BooklogCsvImporterTest < ActiveSupport::TestCase
  setup { @user = User.create!(name: "読書家") }

  test "imports Japanese headers, skips blank rows, and is idempotent" do
    csv = "\uFEFFISBN,タイトル,著者,評価,読書状況,カテゴリ,タグ,登録日,読了日\n9784152098702,三体,劉慈欣,5,読了,SF,宇宙 科学,2025-01-01,2025-01-20\n\n"

    first = import(csv)
    second = import(csv)

    assert_equal({ "success" => 1, "skipped" => 0, "errors" => 0 }, first.result.slice("success", "skipped", "errors"))
    assert_equal 1, @user.reading_records.count
    assert_equal 1, second.result["skipped"]
  end

  test "keeps valid rows when another row is malformed" do
    csv = "ISBN,タイトル,著者\n9784152098702,三体,劉慈欣\nbad,,誰か\n"
    result = import(csv)

    assert_equal 1, result.result["success"]
    assert_equal 1, result.result["errors"]
    assert_equal "completed_with_errors", result.status
  end

  test "imports a title-only record when ISBN is absent" do
    result = import("タイトル,著者,読書状況\n銀河鉄道の夜,宮沢賢治,読みたい\n")

    assert_equal 1, result.result["success"]
    assert_nil @user.reading_records.first.book.isbn
  end

  private

  def import(content)
    file = Tempfile.new([ "booklog", ".csv" ])
    file.binmode
    file.write(content)
    file.rewind
    BooklogCsvImporter.new(user: @user, file:, filename: "booklog.csv").call
  ensure
    file&.close!
  end
end
