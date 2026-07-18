# ABOUTME: Imports user-provided Booklog CSV data without retaining the original file.
# ABOUTME: Isolates malformed rows and safely updates repeated reader/book records.
require "csv"

class BooklogCsvImporter
  HEADERS = {
    isbn: [ "ISBN", "isbn", "ＩＳＢＮ", "ISBN-13", "ISBN13", "ISBN-10", "ISBN10" ],
    title: %w[タイトル 書名 本のタイトル title], author: %w[著者 著者名 author], publisher: %w[出版社 publisher],
    rating: %w[評価 rating], status: %w[読書状況 読書状態 状態 status], categories: %w[カテゴリ カテゴリー genre],
    tags: %w[タグ tag], registered_at: %w[登録日 登録日時 registered_at], finished_at: %w[読了日 読了日時 finished_at],
    published_on: %w[出版年 発売日 published_on], page_count: %w[ページ数 pages page_count]
  }.freeze
  HEADERLESS_COLUMNS = [
    "種別", "商品ID", "ISBN", "カテゴリ", "評価", "読書状況", "レビュー", "タグ", "コメント",
    "登録日", "読了日", "タイトル", "著者", "出版社", "出版年", "媒体", "ページ数"
  ].freeze

  def initialize(user:, file:, filename:)
    @user = user
    @file = file
    @filename = filename
  end

  def call
    import = @user.imports.create!(original_filename: File.basename(@filename), status: "processing")
    totals = { "success" => 0, "skipped" => 0, "errors" => 0, "row_errors" => [] }
    parsed_rows = rows
    line_offset = @headerless ? 1 : 2
    parsed_rows.each_with_index { |row, index| import_row(row, index + line_offset, totals) }
    import.update!(status: totals["errors"].positive? ? "completed_with_errors" : "completed", imported_at: Time.current, result: totals)
    import
  rescue CSV::MalformedCSVError, EncodingError => error
    import&.update!(status: "failed", error_message: error.message, result: totals || {})
    import
  end

  private

  def rows
    content = @file.read.to_s
    content = content.sub(/\A\xEF\xBB\xBF/n, "")
    content = content.force_encoding(Encoding::UTF_8)
    content = content.encode(Encoding::UTF_8, Encoding::Windows_31J, invalid: :replace, undef: :replace) unless content.valid_encoding?
    table = CSV.parse(content, headers: false, skip_blanks: true)
    @headerless = !header_row?(table.first)
    headers = @headerless ? HEADERLESS_COLUMNS : table.shift
    table.map { |row| headers.zip(row).to_h }
  end

  def import_row(row, line, totals)
    values = row.transform_values { |value| value.to_s.strip.presence }
    return if values.values.compact.empty?

    title = value(values, :title)
    raise ArgumentError, "タイトルがありません" if title.blank?

    raw_isbn = value(values, :isbn)
    isbn = Book.normalize_isbn(raw_isbn)
    isbn ||= Book.normalize_isbn(values["商品ID"]) if @headerless
    raise ArgumentError, "ISBNが不正です" if !@headerless && raw_isbn.present? && isbn.nil?

    book = find_or_create_book(
      isbn:, title:, author: value(values, :author), categories: split(value(values, :categories)),
      publisher: value(values, :publisher), published_on: parse_year(value(values, :published_on)),
      page_count: value(values, :page_count)&.to_i
    )
    record = @user.reading_records.find_or_initialize_by(book:)
    attributes = record_attributes(values)
    if record.persisted? && record.slice(*attributes.keys).stringify_keys == attributes.stringify_keys
      totals["skipped"] += 1
    else
      record.update!(attributes)
      totals["success"] += 1
    end
  rescue StandardError => error
    totals["errors"] += 1
    totals["row_errors"] << { "line" => line, "message" => error.message }
  end

  def find_or_create_book(isbn:, title:, author:, categories:, publisher:, published_on:, page_count:)
    book = isbn ? Book.find_or_initialize_by(isbn:) : Book.find_or_initialize_by(isbn: nil, title:, author:)
    metadata = { title:, author:, categories:, publisher:, published_on:, page_count:, metadata_source: "csv" }
    if book.new_record?
      book.assign_attributes(metadata)
    else
      metadata.except(:metadata_source).each { |attribute, value| book[attribute] = value if book[attribute].blank? && value.present? }
    end
    book.save!
    BookMetadataJob.perform_later(book) if book.isbn.present?
    book
  end

  def record_attributes(values)
    {
      rating: value(values, :rating)&.to_i&.then { |rating| (1..5).cover?(rating) ? rating : nil },
      reading_status: value(values, :status), tags: split(value(values, :tags)),
      registered_at: parse_time(value(values, :registered_at)), finished_at: parse_time(value(values, :finished_at)), source: "booklog"
    }
  end

  def value(values, key)
    HEADERS.fetch(key).each { |header| return values[header] if values[header].present? }
    nil
  end

  def header_row?(row)
    return false unless row

    known_headers = HEADERS.values.flatten
    row.compact.any? { |cell| known_headers.include?(cell.strip) }
  end

  def split(value)
    value.to_s.split(/[\s,、;]+/).reject(&:blank?)
  end

  def parse_time(value)
    Time.zone.parse(value) if value.present?
  rescue ArgumentError
    nil
  end

  def parse_year(value)
    Date.new(Integer(value), 1, 1) if value.present?
  rescue ArgumentError
    nil
  end
end
