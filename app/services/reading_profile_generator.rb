# ABOUTME: Converts weighted reading signals into an explainable preference profile.
# ABOUTME: Centralizes tunable status and rating weights for later evaluation.
class ReadingProfileGenerator
  STATUS_WEIGHTS = { "読了" => 1.0, "読み終わった" => 1.0, "読んでいる" => 0.8, "いま読んでる" => 0.8, "読みたい" => 0.4, "積読" => 0.2 }.freeze
  RATING_WEIGHTS = { 5 => 5.0, 4 => 3.5, 3 => 2.0, 2 => -0.5, 1 => -1.0, nil => 1.0 }.freeze

  def self.weight_for(record)
    STATUS_WEIGHTS.fetch(record.reading_status, 0.5) * RATING_WEIGHTS.fetch(record.rating, 1.0)
  end

  def initialize(user:)
    @user = user
  end

  def call
    signals = @user.reading_records.includes(:book).map { |record| [ record, self.class.weight_for(record) ] }
    positive = signals.select { |_record, score| score.positive? }
    categories = ranked(positive.flat_map { |record, score| record.book.categories.map { |item| [ item, score ] } })
    authors = ranked(positive.filter_map { |record, score| [ record.book.author, score ] if record.book.author.present? })
    topics = ranked(positive.flat_map { |record, score| record.tags.map { |item| [ item, score ] } } + categories.map { |item| [ item, 1 ] })
    completed_pages = signals.filter_map { |record, _| record.book.page_count if completed?(record) && record.book.page_count.present? }
    typical_pages = completed_pages.any? ? (completed_pages.sum / completed_pages.length.to_f).round : nil
    summary = summary_for(topics, categories, authors, typical_pages)

    ReadingProfile.find_or_initialize_by(user: @user).tap do |profile|
      profile.update!(summary:, favorite_topics: topics.first(6), favorite_authors: authors.first(5), preferred_categories: categories.first(6),
        typical_page_count: typical_pages, completion_patterns: { "completed_count" => signals.count { |record, _| completed?(record) } }, generated_at: Time.current)
    end
  end

  private

  def ranked(entries)
    entries.group_by(&:first).transform_values { |pairs| pairs.sum(&:last) }.sort_by { |_name, score| -score }.map(&:first)
  end

  def completed?(record)
    %w[読了 読み終わった].include?(record.reading_status)
  end

  def summary_for(topics, categories, authors, pages)
    parts = []
    interests = categories.presence || topics
    parts << I18n.t("profile_summary.interests", items: interests.first(3).join(I18n.t("support.list_separator"))) if interests.any?
    parts << I18n.t("profile_summary.authors", items: authors.first(2).join(I18n.t("support.list_separator"))) if authors.any?
    parts << I18n.t("profile_summary.pages", count: pages) if pages
    parts.presence&.join(" ") || I18n.t("profile_summary.empty")
  end
end
