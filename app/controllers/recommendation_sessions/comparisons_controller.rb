# ABOUTME: Shows side-by-side algorithm outcomes for one controlled recommendation session.
# ABOUTME: Keeps diagnostics separate from the reader-facing result page.
class RecommendationSessions::ComparisonsController < ApplicationController
  def show
    @session = current_user.recommendation_sessions.find(params[:recommendation_session_id])
    return redirect_to(@session, alert: "推薦の生成が完了するまでお待ちください。") unless @session.completed?

    @recommendations = @session.recommendations.includes(:book).order(:algorithm, :category, :rank).group_by(&:algorithm)
  end
end
