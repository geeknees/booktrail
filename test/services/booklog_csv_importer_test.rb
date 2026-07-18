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

  test "imports Booklog's headerless 17-column Windows-31J export" do
    rows = [
      [ "1", "4478069786", "9784478069783", "", "5", "読み終わった", "", "kindle", "", "2025-07-01 10:00:00", "2025-07-10 20:00:00", "対話で育てるチーム", "山田太郎", "架空出版", "2024", "本", "244" ],
      [ "1", "4101010013", "", "", "", "積読", "", "", "", "2025-07-02 10:00:00", "", "次に読む本", "佐藤花子", "架空書房", "2025", "本", "320" ],
      [ "1", "B000000000", "", "", "", "いま読んでる", "", "kindle", "", "2025-07-03 10:00:00", "", "電子書籍の物語", "鈴木一郎", "架空文庫", "2025", "電子書籍", "180" ]
    ]
    csv = rows.map { |row| CSV.generate_line(row) }.join.encode(Encoding::Windows_31J)

    result = import(csv)

    assert_equal 3, result.result["success"]
    assert_equal 0, result.result["errors"]
    book = Book.find_by!(isbn: "9784478069783")
    assert_equal "架空出版", book.publisher
    assert_equal 244, book.page_count
    assert_equal [ "kindle" ], @user.reading_records.find_by!(book:).tags
    assert Book.exists?(isbn: "4101010013")
    assert_nil Book.find_by!(title: "電子書籍の物語").isbn
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
