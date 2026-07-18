# ABOUTME: Expands the public recommendation catalog from consented author signals.
# ABOUTME: Stores only query digests and public book metadata, never raw reading history.
require "digest"

class GoogleBooksCatalogDiscovery
  Result = Data.define(:updated_books, :external_queries)
  Page = Data.define(:volumes, :result_count)
  TARGET_SIZE = 1_000
  AUTHOR_LIMIT = 5
  SUBJECT_LIMIT = 10
  RESULTS_PER_PAGE = 20
  MAX_PAGES_PER_QUERY = 10
  DEFAULT_SEED_QUERIES = %w[日本文学 海外文学 SF 科学 技術 教育 歴史 社会 哲学 心理学 芸術 経済].freeze
  SUCCESS_CACHE_TTL = 30.days
  FAILURE_CACHE_TTL = 1.hour

  def initialize(profile:, client: GoogleBooksSearchClient.new, target_size: ENV.fetch("BOOKTRAIL_CATALOG_TARGET", TARGET_SIZE).to_i,
    seed_queries: DEFAULT_SEED_QUERIES)
    @profile = profile
    @client = client
    @target_size = target_size.clamp(1, TARGET_SIZE)
    @seed_queries = seed_queries
  end

  def call
    return Result.new(updated_books: 0, external_queries: 0) if catalog_full?

    discovered_categories = public_catalog_categories
    @profile.favorite_authors.first(AUTHOR_LIMIT).each do |author|
      discovered_categories.concat(discover("inauthor:#{sanitize(author)}"))
      break if catalog_full?
    end
    subjects = discovered_categories
      .compact_blank.tally.sort_by { |name, count| [ -count, name ] }.first(SUBJECT_LIMIT).map(&:first)
    subjects.each do |subject|
      discover("subject:#{sanitize(subject)}")
      break if catalog_full?
    end
    @seed_queries.each do |query|
      discover(sanitize(query))
      break if catalog_full?
    end

    Result.new(updated_books: @updated_books.to_i, external_queries: @external_queries.to_i)
  end

  private

  def discover(query)
    categories = []
    start_index = 0
    MAX_PAGES_PER_QUERY.times do
      break if catalog_full?

      limit = [ RESULTS_PER_PAGE, @target_size - Book.recommendable.count ].min
      page = fetch(query, start_index:, limit:)
      page.volumes.each do |volume|
        categories.concat(Array(volume.dig("volumeInfo", "categories")))
        @updated_books = @updated_books.to_i + 1 if persist(volume)
      end
      break if page.result_count < limit

      start_index += page.result_count
    end
    categories
  end

  def fetch(query, start_index:, limit:)
    digest = Digest::SHA256.hexdigest("v3\0key=#{ENV['GOOGLE_BOOKS_API_KEY'].present?}\0ja\0#{start_index}\0#{limit}\0#{query}")
    cached = CatalogDiscoveryQuery.find_by(query_digest: digest)
    return Page.new(volumes: [], result_count: [ cached.result_count, 0 ].max) if fresh?(cached)

    @external_queries = @external_queries.to_i + 1
    volumes = @client.search(query:, limit:, language: "ja", start_index:)
    record_query(digest, volumes.length)
    Page.new(volumes:, result_count: volumes.length)
  rescue Net::ProtocolError, Timeout::Error, SocketError, JSON::ParserError => error
    Rails.logger.warn("Google Books catalog query unavailable: #{error.class}")
    record_query(digest, -1) if digest
    Page.new(volumes: [], result_count: 0)
  end

  def catalog_full?
    Book.recommendable.count >= @target_size
  end

  def public_catalog_categories
    Book.where(metadata_source: "google_books_discovery").pluck(:categories).flatten
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
