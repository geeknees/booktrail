# ABOUTME: Enriches imported ISBN books outside the upload request lifecycle.
# ABOUTME: Leaves valid CSV metadata intact whenever external providers fail.
class BookMetadataJob < ApplicationJob
  queue_as :default

  def perform(book)
    return if book.isbn.blank? || book.metadata_source != "csv"
    metadata = BookMetadataProvider.new.fetch(book.isbn)
    book.update!(metadata.compact_blank) if metadata.present?
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::HTTPError, JSON::ParserError, ActiveRecord::ActiveRecordError => error
    Rails.logger.warn("Book metadata enrichment failed for book #{book.id}: #{error.class}: #{error.message}")
  end
end
