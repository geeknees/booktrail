# ABOUTME: Invokes QMD through an argument array and parses its JSON search results.
# ABOUTME: Falls back locally on missing binaries, model failures, or malformed output.
require "json"
require "open3"
require "timeout"

class QmdCandidateProvider < RecommendationCandidateProvider
  TIMEOUT_SECONDS = 20
  INTENT_CONTEXTS = {
    "likely_to_love" => "高評価した本とテーマ、雰囲気、著者性、物語構造が近い本",
    "easy_to_continue" => "読了した本と長さ、複雑さ、ジャンル、語り口が近い本",
    "broaden_your_world" => "主な興味と接点があり、異なるジャンル、時代、地域、著者、観点を持つ本"
  }.freeze
  GOAL_CONTEXTS = {
    "light" => "気軽に楽しみたい",
    "same_pace" => "いつもと同じくらいの本を読みたい",
    "challenge" => "少し難しい本に挑戦したい",
    "explore" => "新しい分野を開拓したい"
  }.freeze

  def initialize(fallback: FallbackCandidateProvider.new(algorithm: "qmd_hybrid"))
    @fallback = fallback
  end

  def candidates(user:, profile:, goal:, intent:, limit:)
    return fallback(user:, profile:, goal:, intent:, limit:) unless ENV["BOOKTRAIL_QMD"] == "1"

    query = [ profile.summary, "読書目的: #{GOAL_CONTEXTS.fetch(goal, goal)}", "推薦意図: #{INTENT_CONTEXTS.fetch(intent, intent)}" ].join("\n")
    environment = ENV["QMD_EMBED_MODEL"].present? ? { "QMD_EMBED_MODEL" => ENV["QMD_EMBED_MODEL"] } : {}
    collection = ENV.fetch("QMD_COLLECTION", "booktrail")
    collection = "booktrail" unless collection.match?(/\A[a-z0-9_-]+\z/i)
    stdout, status = Timeout.timeout(TIMEOUT_SECONDS) do
      # Brakeman flags all process execution; separate arguments here intentionally bypass a shell.
      Open3.capture2e(environment, "qmd", "query", "--json", "--explain", "-n", limit.to_i.clamp(1, 100).to_s, "-c", collection, query)
    end
    return fallback(user:, profile:, goal:, intent:, limit:) unless status.success?

    parse(stdout, user:, limit:).presence || fallback(user:, profile:, goal:, intent:, limit:)
  rescue Errno::ENOENT, JSON::ParserError, Timeout::Error, StandardError => error
    Rails.logger.warn("QMD search failed; using fallback: #{error.class}: #{error.message}")
    fallback(user:, profile:, goal:, intent:, limit:)
  end

  private

  def parse(output, user:, limit:)
    feedback_ids = RecommendationFeedback.where(feedback_type: "already_read").joins(recommendation: :recommendation_session).where(recommendation_sessions: { user_id: user.id }).pluck("recommendations.book_id")
    excluded = user.book_ids | feedback_ids
    JSON.parse(output).filter_map do |item|
      identifier = File.basename(item["file"].to_s, ".md")
      book = identifier.start_with?("book-") ? Book.find_by(id: identifier.delete_prefix("book-")) : Book.find_by(isbn: identifier)
      next if book.nil? || excluded.include?(book.id)
      explain = item.fetch("explain", {})
      Candidate.new(book:, score: item.fetch("score", 0).to_f, details: {
        "bm25_score" => Array(explain["ftsScores"]).max,
        "vector_score" => Array(explain["vectorScores"]).max,
        "reranker_score" => explain["rerankerScore"],
        "query_expansion" => Array(explain.dig("rrf", "contributions")).filter_map { |entry| entry["query"] }.uniq
      })
    end.first(limit)
  end

  def fallback(**arguments)
    @fallback.candidates(**arguments)
  end
end
