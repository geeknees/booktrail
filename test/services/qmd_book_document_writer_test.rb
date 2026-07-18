# ABOUTME: Verifies the one-book-one-document QMD indexing contract.
# ABOUTME: Ensures filenames are generated only from controlled identifiers.
require "test_helper"

class QmdBookDocumentWriterTest < ActiveSupport::TestCase
  test "writes compact markdown with book metadata" do
    book = Book.create!(isbn: "9784152098702", title: "三体", author: "劉慈欣", page_count: 448, categories: %w[SF 宇宙], description: "異星文明との接触を描く。", recommendable: true)

    QmdBookDocumentWriter.new.call
    content = QmdBookDocumentWriter::DIRECTORY.join("9784152098702.md").read

    assert_includes content, "# 三体"
    assert_includes content, '"SF"'
    assert_operator content.bytesize, :<, 10.kilobytes
  end

  test "removes generated documents for books outside the recommendation catalog" do
    private_book = Book.create!(title: "個人履歴だけの本", author: "著者")
    stale_document = QmdBookDocumentWriter::DIRECTORY.join("book-#{private_book.id}.md")
    FileUtils.mkdir_p(QmdBookDocumentWriter::DIRECTORY)
    File.write(stale_document, "# stale")

    QmdBookDocumentWriter.new.call

    refute stale_document.exist?
  end
end
