# ABOUTME: Verifies multilingual local scoring when QMD is unavailable.
# ABOUTME: Keeps English narrative descriptions equivalent to Japanese story signals.
require "test_helper"

class FallbackCandidateProviderTest < ActiveSupport::TestCase
  test "recognizes English narrative terms as semantic signals" do
    user = User.create!(name: "Reader", locale: "en")
    profile = ReadingProfile.create!(user:, summary: "Science", favorite_topics: [ "Science" ], preferred_categories: [], generated_at: Time.current)
    story = Book.create!(title: "Narrative Candidate", description: "A science story told through one family.", recommendable: true)
    plain = Book.create!(title: "Reference Candidate", description: "A science reference index.", recommendable: true)

    candidates = FallbackCandidateProvider.new(algorithm: "vector_only").candidates(user:, profile:, goal: "same_pace", intent: "likely_to_love", limit: 2)
    scores = candidates.to_h { |candidate| [ candidate.book, candidate.score ] }

    assert_operator scores.fetch(story), :>, scores.fetch(plain)
  end
end
