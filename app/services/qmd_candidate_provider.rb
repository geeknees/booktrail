# ABOUTME: Implements real vector, BM25-plus-vector, and QMD hybrid candidate retrieval.
# ABOUTME: Uses local deterministic scoring only when QMD is disabled or unavailable.
class QmdCandidateProvider < RecommendationCandidateProvider
  RRF_K = 60.0
  EXCLUDED_FEEDBACK_TYPES = %w[already_read not_for_me want_to_read].freeze

  def initialize(algorithm: "qmd_hybrid", runner: QmdCommandRunner.new, fallback: nil)
    @algorithm = algorithm
    @runner = runner
    @fallback = fallback || FallbackCandidateProvider.new(algorithm:)
  end

  def candidates(user:, profile:, goal:, intent:, limit:)
    return fallback(user:, profile:, goal:, intent:, limit:) unless ENV["BOOKTRAIL_QMD"] == "1" || custom_runner?

    query_builder = RecommendationQueryBuilder.new(user:, profile:, goal:, intent:)
    query = query_builder.call
    collection = validated_collection
    fetch_limit = [ limit * 2, 30 ].min
    results = case @algorithm
    when "vector_only"
      single_backend(@runner.call(command: "vsearch", query:, limit: fetch_limit, collection:), user:, backend: "vector")
    when "bm25_vector"
      keyword = @runner.call(command: "search", query: query_builder.lexical_query, limit: fetch_limit, collection:)
      vector = @runner.call(command: "vsearch", query:, limit: fetch_limit, collection:)
      reciprocal_rank_fusion(keyword:, vector:, user:)
    when "qmd_hybrid"
      hybrid(@runner.call(command: "query", query:, limit: fetch_limit, collection:), user:)
    else
      raise ArgumentError, "Unknown recommendation algorithm: #{@algorithm}"
    end
    results.first(limit).presence || fallback(user:, profile:, goal:, intent:, limit:)
  rescue Errno::ENOENT, JSON::ParserError, Timeout::Error, RuntimeError, ArgumentError => error
    Rails.logger.warn("QMD #{@algorithm} search failed; using fallback: #{error.class}: #{error.message}")
    fallback(user:, profile:, goal:, intent:, limit:)
  end

  private

  def custom_runner?
    !@runner.is_a?(QmdCommandRunner)
  end

  def validated_collection
    collection = ENV.fetch("QMD_COLLECTION", "booktrail")
    collection.match?(/\A[a-z0-9_-]+\z/i) ? collection : "booktrail"
  end

  def single_backend(results, user:, backend:)
    results.filter_map do |item|
      book = result_book(item)
      next if unavailable?(book, user)

      score = item.fetch("score", 0).to_f
      Candidate.new(book:, score:, details: {
        "backend" => "qmd", "bm25_score" => (score if backend == "keyword"),
        "vector_score" => (score if backend == "vector"), "reranker_score" => nil,
        "query_expansion" => []
      })
    end.sort_by { |candidate| -candidate.score }
  end

  def reciprocal_rank_fusion(keyword:, vector:, user:)
    entries = {}
    add_ranked_results(entries, keyword, "keyword", user)
    add_ranked_results(entries, vector, "vector", user)
    maximum = 2.0 / (RRF_K + 1)
    entries.values.map do |entry|
      rrf = entry[:ranks].values.sum { |rank| 1.0 / (RRF_K + rank) }
      Candidate.new(book: entry[:book], score: rrf / maximum, details: {
        "backend" => "qmd", "bm25_score" => entry.dig(:scores, "keyword"),
        "vector_score" => entry.dig(:scores, "vector"), "reranker_score" => nil,
        "rrf_score" => rrf.round(6), "query_expansion" => []
      })
    end.sort_by { |candidate| -candidate.score }
  end

  def add_ranked_results(entries, results, backend, user)
    results.each_with_index do |item, index|
      book = result_book(item)
      next if unavailable?(book, user)

      entry = entries[book.id] ||= { book:, ranks: {}, scores: {} }
      entry[:ranks][backend] = index + 1
      entry[:scores][backend] = item.fetch("score", 0).to_f
    end
  end

  def hybrid(results, user:)
    results.filter_map do |item|
      book = result_book(item)
      next if unavailable?(book, user)

      explain = item.fetch("explain", {})
      Candidate.new(book:, score: item.fetch("score", 0).to_f, details: {
        "backend" => "qmd", "bm25_score" => Array(explain["ftsScores"]).max,
        "vector_score" => Array(explain["vectorScores"]).max,
        "reranker_score" => explain["rerankScore"],
        "query_expansion" => Array(explain.dig("rrf", "contributions")).filter_map { |entry| entry["query"] }.uniq
      })
    end
  end

  def result_book(item)
    identifier = File.basename(item["file"].to_s, ".md")
    scope = Book.recommendable
    identifier.start_with?("book-") ? scope.find_by(id: identifier.delete_prefix("book-")) : scope.find_by(isbn: identifier)
  end

  def unavailable?(book, user)
    book.nil? || excluded_ids(user).include?(book.id)
  end

  def excluded_ids(user)
    @excluded_ids ||= {}
    @excluded_ids[user.id] ||= begin
      feedback_ids = RecommendationFeedback.where(feedback_type: EXCLUDED_FEEDBACK_TYPES)
        .joins(recommendation: :recommendation_session).where(recommendation_sessions: { user_id: user.id }).pluck("recommendations.book_id")
      user.book_ids | feedback_ids
    end
  end

  def fallback(**arguments)
    @fallback.candidates(**arguments)
  end
end
