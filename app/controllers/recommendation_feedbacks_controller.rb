# ABOUTME: Saves one explicit reaction to a recommendation owned by the demo reader.
# ABOUTME: Guards feedback types and ownership before updating future exclusions.
class RecommendationFeedbacksController < ApplicationController
  def create
    recommendation = Recommendation.joins(:recommendation_session).where(recommendation_sessions: { user_id: current_user.id }).find(feedback_params[:recommendation_id])
    recommendation.feedbacks.create!(feedback_type: feedback_params[:feedback_type])
    redirect_back fallback_location: recommendation_session_path(recommendation.recommendation_session), notice: t("notices.feedback_saved")
  end

  private

  def feedback_params
    params.require(:recommendation_feedback).permit(:recommendation_id, :feedback_type)
  end
end
