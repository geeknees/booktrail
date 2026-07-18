# ABOUTME: Verifies safe argument-array QMD invocation and local outage fallback.
# ABOUTME: Prevents shell interpolation from entering the external search boundary.
require "test_helper"

class QmdCandidateProviderTest < ActiveSupport::TestCase
  FakeRunner = Struct.new(:responses, :calls) do
    def call(command:, query:, limit:, collection:)
      calls << { command:, query:, limit:, collection: }
      responses.fetch(command)
    end
  end

  test "falls back without invoking qmd when integration is disabled" do
    user = User.create!(name: "読書家")
    Book.create!(title: "候補", author: "著者", categories: [ "科学" ], description: "科学の物語", recommendable: true)
    profile = ReadingProfile.create!(user:, summary: "科学に関心", favorite_topics: [ "科学" ], preferred_categories: [ "科学" ], generated_at: Time.current)

    previous = ENV.delete("BOOKTRAIL_QMD")
    results = QmdCandidateProvider.new.candidates(user:, profile:, goal: "light", intent: "likely_to_love", limit: 3)
    assert_equal [ "候補" ], results.map { |candidate| candidate.book.title }
  ensure
    ENV["BOOKTRAIL_QMD"] = previous if previous
  end

  test "uses vector search for vector only" do
    user, profile, books = reader_and_candidates
    runner = FakeRunner.new({ "vsearch" => [ result(books[1], 0.9), result(books[0], 0.7) ] }, [])

    candidates = QmdCandidateProvider.new(algorithm: "vector_only", runner:).candidates(user:, profile:, goal: "light", intent: "likely_to_love", limit: 2)

    assert_equal [ "vsearch" ], runner.calls.pluck(:command)
    assert_equal books[1], candidates.first.book
    assert_equal 0.9, candidates.first.details["vector_score"]
  end

  test "fuses keyword and vector rankings with reciprocal rank fusion" do
    user, profile, books = reader_and_candidates
    runner = FakeRunner.new({
      "search" => [ result(books[0], 8.2), result(books[1], 5.1) ],
      "vsearch" => [ result(books[1], 0.92), result(books[2], 0.81) ]
    }, [])

    candidates = QmdCandidateProvider.new(algorithm: "bm25_vector", runner:).candidates(user:, profile:, goal: "same_pace", intent: "easy_to_continue", limit: 3)

    assert_equal %w[search vsearch], runner.calls.pluck(:command)
    assert_equal books[1], candidates.first.book
    assert_equal 5.1, candidates.first.details["bm25_score"]
    assert_equal 0.92, candidates.first.details["vector_score"]
  end

  test "uses full query pipeline for qmd hybrid" do
    user, profile, books = reader_and_candidates
    runner = FakeRunner.new({ "query" => [ result(books[0], 0.88, "rerankScore" => 0.93) ] }, [])

    candidates = QmdCandidateProvider.new(algorithm: "qmd_hybrid", runner:).candidates(user:, profile:, goal: "explore", intent: "broaden_your_world", limit: 1)

    assert_equal [ "query" ], runner.calls.pluck(:command)
    assert_equal 0.93, candidates.first.details["reranker_score"]
  end

  private

  def reader_and_candidates
    user = User.create!(name: "読書家")
    profile = ReadingProfile.create!(user:, summary: "科学に関心", favorite_topics: [ "科学" ], preferred_categories: [ "科学" ], generated_at: Time.current)
    books = 3.times.map { |index| Book.create!(title: "候補#{('A'.ord + index).chr}", author: "著者#{index}", categories: [ "科学" ], description: "科学の物語", recommendable: true) }
    [ user, profile, books ]
  end

  def result(book, score, explain = {})
    { "file" => "qmd://booktrail/book-#{book.id}.md", "score" => score, "explain" => explain }
  end
end
