# ABOUTME: Verifies that recommendation queries carry concrete reader evidence.
# ABOUTME: Keeps the three search intents and current reading goal explicit.
require "test_helper"

class RecommendationQueryBuilderTest < ActiveSupport::TestCase
  test "includes highly rated examples, goal, and intent" do
    user = User.create!(name: "読書家")
    loved = Book.create!(title: "星を継ぐもの", author: "ジェイムズ・P・ホーガン", categories: [ "SF", "宇宙" ], description: "月面の遺体から宇宙文明の謎を追う物語")
    user.reading_records.create!(book: loved, rating: 5, reading_status: "読み終わった", finished_at: 1.day.ago)
    profile = ReadingProfileGenerator.new(user:).call

    query = RecommendationQueryBuilder.new(user:, profile:, goal: "challenge", intent: "likely_to_love").call

    assert_includes query, "星を継ぐもの"
    assert_includes query, "少し難しい本に挑戦したい"
    assert_includes query, "テーマ、雰囲気、著者性、物語構造"
    assert_operator query.length, :<, 4_000
  end
end
