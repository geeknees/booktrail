# ABOUTME: Builds bounded search queries from concrete reading-history evidence.
# ABOUTME: Keeps current goal and each recommendation intent explicit for QMD.
class RecommendationQueryBuilder
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
  EXAMPLE_LIMIT = 8
  QUERY_LIMIT = 3_800

  def initialize(user:, profile:, goal:, intent:)
    @user = user
    @profile = profile
    @goal = goal
    @intent = intent
  end

  def call
    sections = [
      "読者プロフィール: #{@profile.summary}",
      "今回の読書目的: #{GOAL_CONTEXTS.fetch(@goal, @goal)}",
      "推薦意図: #{INTENT_CONTEXTS.fetch(@intent, @intent)}",
      examples_section,
      recent_section,
      feedback_section
    ].compact
    sections.join("\n\n").truncate(QUERY_LIMIT, omission: "")
  end

  def lexical_query
    terms = @profile.favorite_topics + @profile.preferred_categories + @profile.favorite_authors
    terms += positive_records.first(5).flat_map { |record| [ record.book.title, record.book.author ] }
    terms.compact_blank.uniq.first(16).join(" ")
  end

  private

  def examples_section
    records = positive_records.first(EXAMPLE_LIMIT)
    return if records.empty?

    "高く評価して読み終えた本:\n" + records.map { |record| "- #{book_evidence(record.book)}" }.join("\n")
  end

  def positive_records
    @positive_records ||= @user.reading_records.includes(:book).select do |record|
      record.rating.to_i >= 4 && %w[読了 読み終わった].include?(record.reading_status)
    end.sort_by { |record| [ -record.rating.to_i, -(record.finished_at || record.updated_at).to_i ] }
  end

  def recent_section
    records = @user.reading_records.includes(:book).where.not(finished_at: nil).order(finished_at: :desc).limit(4)
    return if records.empty?

    "最近読み終えた本:\n" + records.map { |record| "- #{record.book.title} / #{record.book.author}" }.join("\n")
  end

  def feedback_section
    wanted = feedback_books("want_to_read").first(4)
    rejected = feedback_books("not_for_me").first(4)
    return if wanted.empty? && rejected.empty?

    lines = []
    lines << "読みたいと反応した本: #{wanted.map(&:title).join('、')}" if wanted.any?
    lines << "合わないと反応した本（類似候補を避ける）: #{rejected.map(&:title).join('、')}" if rejected.any?
    lines.join("\n")
  end

  def feedback_books(type)
    Book.joins(recommendations: [ :feedbacks, :recommendation_session ])
      .where(recommendation_feedbacks: { feedback_type: type }, recommendation_sessions: { user_id: @user.id }).distinct
  end

  def book_evidence(book)
    details = [ book.title, book.author, book.categories.join("・"), book.description.to_s.squish.truncate(180) ].compact_blank
    details.join(" / ")
  end
end
