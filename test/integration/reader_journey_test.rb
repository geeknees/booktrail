# ABOUTME: Verifies the complete browser journey from upload through reader feedback.
# ABOUTME: Keeps the hackathon demo's vertical slice executable without QMD.
require "test_helper"

class ReaderJourneyTest < ActionDispatch::IntegrationTest
  test "uploads history, shows a profile, recommends books, compares algorithms, and saves feedback" do
    12.times do |index|
      Book.create!(title: "推薦候補#{('A'.ord + index).chr}", author: "著者#{index}", categories: [ "SF" ], page_count: 320 + index, description: "宇宙と科学を扱う物語", recommendable: true)
    end
    file = fixture_file_upload("booklog_sample.csv", "text/csv")

    post imports_path, params: { import: { file: } }
    assert_response :redirect
    follow_redirect!
    assert_select "h1", /インポート結果/
    assert_select ".stat", minimum: 3

    get reading_profile_path
    assert_response :success
    assert_select "h1", /読書プロフィール/

    assert_enqueued_with(job: RecommendationGenerationJob) do
      post recommendation_sessions_path, params: { recommendation_session: { reading_goal: "same_pace" } }
    end
    assert_response :redirect
    session = RecommendationSession.last
    assert_predicate session, :pending?

    get recommendation_session_path(session)
    assert_response :success
    assert_select "h1", /推薦を準備しています/

    get recommendation_session_comparison_path(session)
    assert_redirected_to recommendation_session_path(session)

    perform_enqueued_jobs(only: RecommendationGenerationJob)
    get recommendation_session_path(session)
    assert_response :success
    assert_select ".recommendation-card", count: 3

    get recommendation_session_comparison_path(session)
    assert_response :success
    assert_select "th", text: /Vector Only/

    recommendation = session.recommendations.first
    post recommendation_feedbacks_path, params: { recommendation_feedback: { recommendation_id: recommendation.id, feedback_type: "want_to_read" } }
    assert_response :redirect
    assert_equal "want_to_read", recommendation.feedbacks.last.feedback_type
  end

  test "rejects non-csv uploads" do
    file = fixture_file_upload("not_csv.txt", "text/plain")
    post imports_path, params: { import: { file: } }
    assert_response :unprocessable_content
  end

  test "rejects csv uploads over five megabytes" do
    file = Tempfile.new([ "large", ".csv" ])
    file.write("x" * (5.megabytes + 1))
    file.rewind
    upload = Rack::Test::UploadedFile.new(file.path, "text/csv", original_filename: "large.csv")

    post imports_path, params: { import: { file: upload } }

    assert_response :unprocessable_content
  ensure
    file&.close!
  end
end
