# ABOUTME: Generates one recommendation session outside the web request.
# ABOUTME: Records observable progress and leaves retries safe and idempotent.
class RecommendationGenerationJob < ApplicationJob
  queue_as :recommendations
  limits_concurrency to: 1, key: ->(session) { session.id }, duration: 10.minutes

  def perform(session)
    return if session.completed?

    session.update!(status: "processing", started_at: Time.current, error_message: nil)
    profile = ReadingProfileGenerator.new(user: session.user).call
    RecommendationEngine.new(user: session.user, profile:, goal: session.reading_goal).call(session:)
  rescue StandardError
    session.update!(status: "failed", error_message: "推薦を生成できませんでした。もう一度お試しください。") if session&.persisted?
    raise
  end
end
