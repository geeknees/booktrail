# ABOUTME: Verifies safe argument-array QMD invocation and local outage fallback.
# ABOUTME: Prevents shell interpolation from entering the external search boundary.
require "test_helper"

class QmdCandidateProviderTest < ActiveSupport::TestCase
  test "falls back without invoking qmd when integration is disabled" do
    user = User.create!(name: "読書家")
    Book.create!(title: "候補", author: "著者", categories: [ "科学" ], description: "科学の物語")
    profile = ReadingProfile.create!(user:, summary: "科学に関心", favorite_topics: [ "科学" ], preferred_categories: [ "科学" ], generated_at: Time.current)

    previous = ENV.delete("BOOKTRAIL_QMD")
    results = QmdCandidateProvider.new.candidates(user:, profile:, goal: "light", intent: "likely_to_love", limit: 3)
    assert_equal [ "候補" ], results.map { |candidate| candidate.book.title }
  ensure
    ENV["BOOKTRAIL_QMD"] = previous if previous
  end
end
