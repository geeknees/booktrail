# ABOUTME: Verifies ISBN normalization and catalog integrity rules.
# ABOUTME: Covers the identity boundary shared by imports and metadata enrichment.
require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "normalizes valid ISBN-10 and ISBN-13 values" do
    assert_equal "9784152098702", Book.normalize_isbn("978-4-15-209870-2")
    assert_equal "4101010013", Book.normalize_isbn("4-10-101001-3")
  end

  test "rejects invalid ISBN values" do
    assert_nil Book.normalize_isbn("9784152098703")
    assert_nil Book.normalize_isbn("not-an-isbn")
  end

  test "normalizes volume markers into a shared series key" do
    assert_equal Book.new(title: "三体").series_key, Book.new(title: "三体II 黒暗森林").series_key
    assert_equal Book.new(title: "約束の冬 (上)").series_key, Book.new(title: "約束の冬（下）").series_key
  end
end
