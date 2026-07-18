# ABOUTME: Shows side-by-side algorithm outcomes for one controlled recommendation session.
# ABOUTME: Keeps diagnostics separate from the reader-facing result page.
class RecommendationSessions::ComparisonsController < ApplicationController
  def show
    @session = current_user.recommendation_sessions.find(params[:recommendation_session_id])
    @recommendations = @session.recommendations.includes(:book).order(:algorithm, :category, :rank).group_by(&:algorithm)
  end
end
