# ABOUTME: Imports user-provided Booklog CSV data without retaining the original file.
# ABOUTME: Isolates malformed rows and safely updates repeated reader/book records.
require "csv"
require "digest"

class BooklogCsvImporter
  HEADERS = {
    isbn: %w[ISBN isbn ＩＳＢＮ], title: %w[タイトル 書名 本のタイトル title], author: %w[著者 著者名 author],
    rating: %w[評価 rating], status: %w[読書状況 読書状態 状態 status], categories: %w[カテゴリ カテゴリー genre],
    tags: %w[タグ tag], registered_at: %w[登録日 登録日時 registered_at], finished_at: %w[読了日 読了日時 finished_at]
  }.freeze

  def initialize(user:, file:, filename:)
    @user = user
    @file = file
    @filename = filename
  end

  def call
    import = @user.imports.create!(original_filename: File.basename(@filename), status: "processing")
    totals = { "success" => 0, "skipped" => 0, "errors" => 0, "row_errors" => [] }
    rows.each_with_index { |row, index| import_row(row, index + 2, totals) }
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
    CSV.parse(content, headers: true, skip_blanks: true)
  end

  def import_row(row, line, totals)
    values = row.to_h.transform_values { |value| value.to_s.strip.presence }
    return if values.values.compact.empty?

    title = value(values, :title)
    raise ArgumentError, "タイトルがありません" if title.blank?

    raw_isbn = value(values, :isbn)
    isbn = Book.normalize_isbn(raw_isbn)
    raise ArgumentError, "ISBNが不正です" if raw_isbn.present? && isbn.nil?

    book = find_or_create_book(isbn:, title:, author: value(values, :author), categories: split(value(values, :categories)))
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

  def find_or_create_book(isbn:, title:, author:, categories:)
    book = isbn ? Book.find_or_initialize_by(isbn:) : Book.find_or_initialize_by(isbn: nil, title:, author:)
    book.assign_attributes(title:, author:, categories:, metadata_source: "csv") if book.new_record?
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

  def split(value)
    value.to_s.split(/[\s,、;]+/).reject(&:blank?)
  end

  def parse_time(value)
    Time.zone.parse(value) if value.present?
  rescue ArgumentError
    nil
  end
end
