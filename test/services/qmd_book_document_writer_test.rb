# ABOUTME: Verifies the one-book-one-document QMD indexing contract.
# ABOUTME: Ensures filenames are generated only from controlled identifiers.
require "test_helper"

class QmdBookDocumentWriterTest < ActiveSupport::TestCase
  test "writes compact markdown with book metadata" do
    book = Book.create!(isbn: "9784152098702", title: "三体", author: "劉慈欣", page_count: 448, categories: %w[SF 宇宙], description: "異星文明との接触を描く。")

    QmdBookDocumentWriter.new.call
    content = QmdBookDocumentWriter::DIRECTORY.join("9784152098702.md").read

    assert_includes content, "# 三体"
    assert_includes content, '"SF"'
    assert_operator content.bytesize, :<, 10.kilobytes
  end
end
