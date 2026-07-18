# ABOUTME: Defines the replaceable boundary for present and future candidate sources.
# ABOUTME: Allows collaborative filtering to be added only after consented data exists.
class RecommendationCandidateProvider
  Candidate = Data.define(:book, :score, :details)

  def candidates(user:, profile:, goal:, intent:, limit:)
    raise NotImplementedError
  end
end
