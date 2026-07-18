# ABOUTME: Generates comparable recommendations while enforcing exclusions and diversity.
# ABOUTME: Converts internal evidence into concise, fact-based reader explanations.
class RecommendationEngine
  WEIGHTS = { relevance: 0.45, reading_pattern_fit: 0.20, reading_goal_fit: 0.15, novelty: 0.10, diversity: 0.10 }.freeze

  def initialize(user:, profile:, goal:)
    @user = user
    @profile = profile
    @goal = goal
  end

  def call(session: nil)
    session ||= @user.recommendation_sessions.create!(reading_goal: @goal, profile_snapshot: @profile.snapshot)
    session.recommendations.destroy_all
    Recommendation::ALGORITHMS.each { |algorithm| generate_algorithm(session, algorithm) }
    session.update!(status: "completed", generated_at: Time.current, error_message: nil)
    session
  end

  private

  def generate_algorithm(session, algorithm)
    provider = QmdCandidateProvider.new(algorithm:)
    used_books = []
    used_authors = Hash.new(0)
    used_series = []
    Recommendation::CATEGORIES.each do |category|
      candidates = rerank(provider.candidates(user: @user, profile: @profile, goal: @goal, intent: category, limit: 12), category, used_authors)
      selected = candidates.find do |candidate|
        !used_books.include?(candidate.book.id) && used_authors[candidate.book.author] < 2 && !used_series.include?(candidate.book.series_key)
      end
      next unless selected

      used_books << selected.book.id
      used_authors[selected.book.author] += 1
      used_series << selected.book.series_key
      details = selected.details.merge("final_rank" => candidates.index(selected) + 1, "final_score" => selected.score.round(3))
      session.recommendations.create!(book: selected.book, algorithm:, category:, rank: 1, score: selected.score, score_details: details, explanation: explanation(selected.book, category))
    end
  end

  def rerank(candidates, category, used_authors)
    candidates.each_with_index.map do |candidate, index|
      pattern_fit = page_fit(candidate.book)
      goal_fit = goal_fit(candidate.book)
      novelty = novelty(candidate.book, category)
      diversity = used_authors[candidate.book.author].zero? ? 1.0 : 0.25
      quality = candidate.book.title.present? && (candidate.book.author.present? || candidate.book.description.present?) ? 1.0 : 0.4
      feedback_fit = feedback_fit(candidate.book)
      final = (candidate.score * WEIGHTS[:relevance] + pattern_fit * WEIGHTS[:reading_pattern_fit] + goal_fit * WEIGHTS[:reading_goal_fit] + novelty * WEIGHTS[:novelty] + diversity * WEIGHTS[:diversity]) * quality * feedback_fit
      RecommendationCandidateProvider::Candidate.new(book: candidate.book, score: final, details: candidate.details.merge(
        "original_rank" => index + 1, "reading_pattern_fit" => pattern_fit.round(3), "reading_goal_fit" => goal_fit.round(3), "novelty" => novelty.round(3), "diversity" => diversity.round(3), "feedback_fit" => feedback_fit.round(3)
      ))
    end.sort_by { |candidate| -candidate.score }
  end

  def feedback_fit(book)
    fit = 1.0
    fit *= 0.7 if feedback_books("maybe_later").include?(book)
    rejected = feedback_books("not_for_me")
    fit *= 0.75 if rejected.any? { |item| item.author.present? && item.author == book.author }
    fit *= 0.85 if rejected.any? { |item| (item.categories & book.categories).any? }
    wanted = feedback_books("want_to_read")
    fit *= 1.08 if wanted.any? { |item| (item.categories & book.categories).any? }
    fit.clamp(0.5, 1.1)
  end

  def feedback_books(type)
    @feedback_books ||= {}
    @feedback_books[type] ||= Book.joins(recommendations: [ :feedbacks, :recommendation_session ])
      .where(recommendation_feedbacks: { feedback_type: type }, recommendation_sessions: { user_id: @user.id }).distinct.to_a
  end

  def page_fit(book)
    return 0.5 unless book.page_count && @profile.typical_page_count&.positive?
    (1.0 - (book.page_count - @profile.typical_page_count).abs.to_f / @profile.typical_page_count).clamp(0, 1)
  end

  def goal_fit(book)
    case @goal
    when "light" then book.page_count ? (1.0 - book.page_count.to_f / 600).clamp(0, 1) : 0.5
    when "challenge" then book.page_count && @profile.typical_page_count ? (book.page_count.to_f / @profile.typical_page_count).clamp(0, 1) : 0.6
    when "explore" then (book.categories & @profile.preferred_categories).empty? ? 1.0 : 0.4
    else page_fit(book)
    end
  end

  def novelty(book, category)
    different = (book.categories & @profile.preferred_categories).empty?
    category == "broaden_your_world" ? (different ? 1.0 : 0.45) : (different ? 0.3 : 0.7)
  end

  def explanation(book, category)
    shared = book.categories & @profile.preferred_categories
    case category
    when "easy_to_continue"
      if book.page_count && @profile.typical_page_count
        "よく読み切っている本の長さ（約#{@profile.typical_page_count}ページ）に近い#{book.page_count}ページの本です。"
      else
        "これまで読了した本と共通するテーマがあり、読み進めやすい候補です。"
      end
    when "broaden_your_world"
      shared.any? ? "関心のある#{shared.first}を入口に、これまでと異なる視点へ広げられる本です。" : "普段の関心から一歩外へ広がる、新しい分野の候補です。"
    else
      shared.any? ? "高く評価した本と#{shared.first}というテーマが共通しています。" : "推定される好みと内容紹介に接点がある本です。"
    end
  end
end
