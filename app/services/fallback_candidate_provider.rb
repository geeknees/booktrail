# ABOUTME: Provides deterministic local candidates when QMD or models are unavailable.
# ABOUTME: Approximates keyword and semantic signals for reliable demos and tests.
class FallbackCandidateProvider < RecommendationCandidateProvider
  EXCLUDED_FEEDBACK_TYPES = %w[already_read not_for_me want_to_read].freeze
  NARRATIVE_PATTERN = /物語|story|narrative/i
  def initialize(algorithm:)
    @algorithm = algorithm
  end

  def candidates(user:, profile:, goal:, intent:, limit:)
    terms = (profile.favorite_topics + profile.preferred_categories + profile.favorite_authors).map(&:downcase)
    Book.recommendable.where.not(id: excluded_ids(user)).filter_map do |book|
      text = [ book.title, book.author, book.description, *book.categories ].compact.join(" ").downcase
      keyword = terms.count { |term| text.include?(term) }.to_f / [ terms.size, 1 ].max
      page_fit = page_fit(book.page_count, profile.typical_page_count)
      novelty = (book.categories & profile.preferred_categories).empty? ? 1.0 : 0.35
      category_overlap = (book.categories & profile.preferred_categories).size.to_f / [ profile.preferred_categories.size, 1 ].max
      semantic = [ category_overlap * 0.75 + (text.match?(NARRATIVE_PATTERN) ? 0.2 : 0.05), 1.0 ].min
      score = score_for(keyword:, semantic:, page_fit:, novelty:, intent:)
      Candidate.new(book:, score:, details: { "backend" => "fallback", "bm25_score" => keyword.round(3), "vector_score" => semantic.round(3), "reranker_score" => nil, "query_expansion" => intent })
    end.sort_by { |candidate| [ -candidate.score, candidate.book.id ] }.first(limit)
  end

  private

  def excluded_ids(user)
    feedback_ids = RecommendationFeedback.where(feedback_type: EXCLUDED_FEEDBACK_TYPES).joins(recommendation: :recommendation_session).where(recommendation_sessions: { user_id: user.id }).pluck("recommendations.book_id")
    user.reading_records.pluck(:book_id) | feedback_ids
  end

  def page_fit(pages, typical)
    return 0.5 unless pages && typical&.positive?
    (1.0 - ((pages - typical).abs.to_f / [ typical, 1 ].max)).clamp(0, 1)
  end

  def score_for(keyword:, semantic:, page_fit:, novelty:, intent:)
    base = case @algorithm
    when "vector_only" then semantic
    when "bm25_vector" then keyword * 0.45 + semantic * 0.55
    else keyword * 0.3 + semantic * 0.45 + 0.15
    end
    adjustment = case intent
    when "easy_to_continue" then page_fit * 0.25
    when "broaden_your_world" then novelty * 0.25
    else keyword * 0.15
    end
    (base + adjustment).clamp(0, 1)
  end
end
