# ABOUTME: Verifies asynchronous recommendation generation and retry safety.
# ABOUTME: Keeps a queued session observable while Solid Queue does the expensive work.
require "test_helper"

class RecommendationGenerationJobTest < ActiveJob::TestCase
  setup do
    @previous_catalog_discovery = ENV["BOOKTRAIL_CATALOG_DISCOVERY"]
    ENV["BOOKTRAIL_CATALOG_DISCOVERY"] = "0"
    @user = User.create!(name: "読書家")
    read = Book.create!(title: "読了本", author: "読了著者", categories: [ "科学" ], page_count: 320)
    @user.reading_records.create!(book: read, rating: 5, reading_status: "読了")
    12.times do |index|
      Book.create!(title: "候補#{('A'.ord + index).chr}", author: "著者#{index}", categories: [ "科学" ], page_count: 300 + index, recommendable: true)
    end
    profile = ReadingProfileGenerator.new(user: @user).call
    @session = @user.recommendation_sessions.create!(
      reading_goal: "same_pace",
      profile_snapshot: profile.snapshot,
      status: "pending"
    )
  end

  teardown do
    ENV["BOOKTRAIL_CATALOG_DISCOVERY"] = @previous_catalog_discovery
  end

  test "generates every algorithm and category and marks the session completed" do
    RecommendationGenerationJob.perform_now(@session)

    assert_predicate @session.reload, :completed?
    assert_not_nil @session.generated_at
    assert_equal 9, @session.recommendations.count
  end

  test "repeating a completed job does not duplicate recommendations" do
    2.times { RecommendationGenerationJob.perform_now(@session) }

    assert_equal 9, @session.recommendations.count
  end

  test "generates persisted recommendation explanations in the reader locale" do
    @user.update!(locale: "en")

    RecommendationGenerationJob.perform_now(@session)

    explanations = @session.recommendations.pluck(:explanation)
    assert explanations.all?(&:present?)
    assert explanations.any? { |explanation| explanation.match?(/selected|interest|pages|theme|field|description/i) }
    refute explanations.any? { |explanation| explanation.match?(/[ぁ-んァ-ヶ]/) }
  end
end
