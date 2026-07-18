# ABOUTME: Builds bounded search queries from concrete reading-history evidence.
# ABOUTME: Keeps current goal and each recommendation intent explicit for QMD.
class RecommendationQueryBuilder
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
      I18n.t("recommendation_query.profile", summary: @profile.summary),
      preference_section,
      I18n.t("recommendation_query.goal", goal: I18n.t("goals.#{@goal}.title", default: @goal)),
      I18n.t("recommendation_query.intent", intent: I18n.t("recommendation_query.intents.#{@intent}", default: @intent)),
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

  def preference_section
    lines = []
    separator = I18n.t("support.list_separator")
    lines << I18n.t("recommendation_query.preferences", items: @profile.favorite_topics.first(6).join(separator)) if @profile.favorite_topics.any?
    lines << I18n.t("recommendation_query.authors", items: @profile.favorite_authors.first(5).join(separator)) if @profile.favorite_authors.any?
    lines << I18n.t("recommendation_query.categories", items: @profile.preferred_categories.first(6).join(separator)) if @profile.preferred_categories.any?
    lines.join("\n").presence
  end

  def examples_section
    records = positive_records.first(EXAMPLE_LIMIT)
    return if records.empty?

    I18n.t("recommendation_query.highly_rated") + "\n" + records.map { |record| "- #{book_evidence(record.book)}" }.join("\n")
  end

  def positive_records
    @positive_records ||= @user.reading_records.includes(:book).select do |record|
      record.rating.to_i >= 4 && %w[読了 読み終わった].include?(record.reading_status)
    end.sort_by { |record| [ -record.rating.to_i, -(record.finished_at || record.updated_at).to_i ] }
  end

  def recent_section
    records = @user.reading_records.includes(:book).where.not(finished_at: nil).order(finished_at: :desc).limit(4)
    return if records.empty?

    I18n.t("recommendation_query.recent") + "\n" + records.map { |record| "- #{record.book.title} / #{record.book.author}" }.join("\n")
  end

  def feedback_section
    wanted = feedback_books("want_to_read").first(4)
    rejected = feedback_books("not_for_me").first(4)
    return if wanted.empty? && rejected.empty?

    lines = []
    separator = I18n.t("support.list_separator")
    lines << I18n.t("recommendation_query.wanted", items: wanted.map(&:title).join(separator)) if wanted.any?
    lines << I18n.t("recommendation_query.rejected", items: rejected.map(&:title).join(separator)) if rejected.any?
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
