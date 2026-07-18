# ABOUTME: Generates one recommendation session outside the web request.
# ABOUTME: Records observable progress and leaves retries safe and idempotent.
class RecommendationGenerationJob < ApplicationJob
  queue_as :recommendations
  limits_concurrency to: 1, key: ->(_session) { "recommendation-generation" }, duration: 10.minutes

  def perform(session)
    I18n.with_locale(locale_for(session.user)) { generate(session) }
  rescue StandardError
    session.update!(status: "failed", error_message: I18n.t("jobs.recommendation_failed", locale: locale_for(session.user))) if session&.persisted?
    raise
  end

  private

  def generate(session)
    return if session.completed?

    session.update!(status: "processing", started_at: Time.current, error_message: nil)
    profile = ReadingProfileGenerator.new(user: session.user).call
    refresh_catalog(profile)
    RecommendationEngine.new(user: session.user, profile:, goal: session.reading_goal).call(session:)
  end

  def locale_for(user)
    locale = user.locale.to_s
    I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.default_locale
  end

  def refresh_catalog(profile)
    return if ENV.fetch("BOOKTRAIL_CATALOG_DISCOVERY", "1") == "0"

    result = GoogleBooksCatalogDiscovery.new(profile:).call
    QmdCatalogIndexer.new.call if result.updated_books.positive? && ENV["BOOKTRAIL_QMD"] == "1"
  rescue StandardError => error
    Rails.logger.warn("Recommendation catalog discovery unavailable: #{error.class}")
  end
end
