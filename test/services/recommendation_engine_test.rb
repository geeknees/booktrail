# ABOUTME: Covers recommendation exclusions, diversity, algorithms, and fallback behavior.
# ABOUTME: Ensures the three reader-facing recommendation intents stay distinct.
require "test_helper"

class RecommendationEngineTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "読書家")
    read = Book.create!(isbn: "9784152098702", title: "三体", author: "劉慈欣", categories: [ "SF", "宇宙" ], page_count: 448, description: "宇宙文明との接触を描くSF")
    @user.reading_records.create!(book: read, rating: 5, reading_status: "読了")
    12.times do |index|
      Book.create!(isbn: "978400000#{format('%03d', index)}#{index % 10}", title: "候補#{index}", author: "著者#{index / 2}", categories: [ index.even? ? "SF" : "科学" ], page_count: 280 + index * 10, description: "科学と社会を物語で考える本")
    end
    @profile = ReadingProfileGenerator.new(user: @user).call
  end

  test "creates distinct categories for all algorithms and excludes read books" do
    session = RecommendationEngine.new(user: @user, profile: @profile, goal: "same_pace").call

    assert_equal Recommendation::ALGORITHMS.sort, session.recommendations.distinct.pluck(:algorithm).sort
    Recommendation::ALGORITHMS.each do |algorithm|
      results = session.recommendations.where(algorithm:)
      assert_equal Recommendation::CATEGORIES.sort, results.pluck(:category).sort
      assert_equal results.pluck(:book_id).uniq, results.pluck(:book_id)
      refute_includes results.pluck(:book_id), @user.books.first.id
    end
  end

  test "already-read feedback excludes a book from the next session" do
    session = RecommendationEngine.new(user: @user, profile: @profile, goal: "same_pace").call
    recommendation = session.recommendations.first
    recommendation.feedbacks.create!(feedback_type: "already_read")

    next_session = RecommendationEngine.new(user: @user, profile: @profile, goal: "same_pace").call

    refute_includes next_session.recommendations.pluck(:book_id), recommendation.book_id
  end
end
