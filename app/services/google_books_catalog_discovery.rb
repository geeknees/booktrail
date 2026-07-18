# ABOUTME: Expands the public recommendation catalog from consented author signals.
# ABOUTME: Stores only query digests and public book metadata, never raw reading history.
require "digest"

class GoogleBooksCatalogDiscovery
  Result = Data.define(:updated_books, :external_queries)
  AUTHOR_LIMIT = 3
  SUBJECT_LIMIT = 2
  RESULTS_PER_QUERY = 20
  SUCCESS_CACHE_TTL = 30.days
  FAILURE_CACHE_TTL = 1.hour

  def initialize(profile:, client: GoogleBooksSearchClient.new)
    @profile = profile
    @client = client
  end

  def call
    author_volumes = @profile.favorite_authors.first(AUTHOR_LIMIT).flat_map do |author|
      fetch("inauthor:#{sanitize(author)}")
    end
    subjects = author_volumes.flat_map { |volume| Array(volume.dig("volumeInfo", "categories")) }
      .compact_blank.tally.sort_by { |name, count| [ -count, name ] }.first(SUBJECT_LIMIT).map(&:first)
    subject_volumes = subjects.flat_map { |subject| fetch("subject:#{sanitize(subject)}") }
    updated = (author_volumes + subject_volumes).uniq { |volume| isbn_for(volume) }.count { |volume| persist(volume) }

    Result.new(updated_books: updated, external_queries: @external_queries.to_i)
  end

  private

  def fetch(query)
    digest = Digest::SHA256.hexdigest("v2\0key=#{ENV['GOOGLE_BOOKS_API_KEY'].present?}\0ja\0#{query}")
    cached = CatalogDiscoveryQuery.find_by(query_digest: digest)
    return [] if fresh?(cached)

    @external_queries = @external_queries.to_i + 1
    volumes = @client.search(query:, limit: RESULTS_PER_QUERY, language: "ja")
    record_query(digest, volumes.length)
    volumes
  rescue Net::ProtocolError, Timeout::Error, SocketError, JSON::ParserError => error
    Rails.logger.warn("Google Books catalog query unavailable: #{error.class}")
    record_query(digest, -1) if digest
    []
  end

  def fresh?(query)
    return false unless query

    ttl = query.result_count.negative? ? FAILURE_CACHE_TTL : SUCCESS_CACHE_TTL
    query.fetched_at >= ttl.ago
  end

  def record_query(digest, result_count)
    now = Time.current
    CatalogDiscoveryQuery.upsert({ query_digest: digest, fetched_at: now, result_count:, created_at: now, updated_at: now }, unique_by: :query_digest)
  end

  def persist(volume)
    info = volume.fetch("volumeInfo", {})
    isbn = isbn_for(volume)
    return false if isbn.blank? || info["title"].blank?

    book = Book.find_or_initialize_by(isbn:)
    book.title = info["title"] if book.new_record? || book.title.blank?
    book.author = Array(info["authors"]).join("、") if book.author.blank?
    book.publisher = info["publisher"] if book.publisher.blank?
    book.published_on = published_on(info["publishedDate"]) if book.published_on.blank?
    book.page_count = info["pageCount"] if book.page_count.blank?
    book.description = info["description"] if book.description.blank?
    book.cover_image_url = info.dig("imageLinks", "thumbnail") if book.cover_image_url.blank?
    book.language = info["language"] if info["language"].present?
    book.categories = (book.categories + Array(info["categories"])).compact_blank.uniq
    book.metadata_source = "google_books_discovery" if book.new_record?
    book.recommendable = true
    changed = book.changed?
    book.save!
    changed
  end

  def isbn_for(volume)
    identifiers = Array(volume.dig("volumeInfo", "industryIdentifiers"))
    preferred = identifiers.find { |item| item["type"] == "ISBN_13" } || identifiers.find { |item| item["type"] == "ISBN_10" }
    Book.normalize_isbn(preferred&.fetch("identifier", nil))
  end

  def published_on(value)
    return if value.blank?

    Date.strptime(value, value.length == 4 ? "%Y" : value.length == 7 ? "%Y-%m" : "%Y-%m-%d")
  rescue Date::Error
    nil
  end

  def sanitize(value)
    value.to_s.delete('"').squish.truncate(100, omission: "")
  end
end
