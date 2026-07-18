# ABOUTME: Creates and displays recommendation sessions for an explicit reading goal.
# ABOUTME: Delegates candidate selection and scoring to the recommendation engine.
class RecommendationSessionsController < ApplicationController
  def new; end

  def create
    goal = params.require(:recommendation_session).fetch(:reading_goal)
    return render(:new, status: :unprocessable_content) unless RecommendationSession::GOALS.include?(goal)

    profile = ReadingProfileGenerator.new(user: current_user).call
    session = RecommendationEngine.new(user: current_user, profile:, goal:).call
    redirect_to session
  end

  def show
    @session = current_user.recommendation_sessions.find(params[:id])
    recommendations = @session.recommendations.where(algorithm: "qmd_hybrid").includes(:book, :feedbacks)
    @recommendations = recommendations.sort_by { |recommendation| [ Recommendation::CATEGORIES.index(recommendation.category), recommendation.rank ] }
  end
end
