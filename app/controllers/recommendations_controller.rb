# ABOUTME: Exposes score provenance for developers without leaking it into reader copy.
# ABOUTME: Restricts diagnostic records to sessions owned by the current demo reader.
class RecommendationsController < ApplicationController
  def show
    @recommendation = Recommendation.joins(:recommendation_session).where(recommendation_sessions: { user_id: current_user.id }).includes(:book).find(params[:id])
  end
end
