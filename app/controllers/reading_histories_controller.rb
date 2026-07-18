# ABOUTME: Provides the privacy control for deleting the current reader's history.
# ABOUTME: Removes derived profiles and sessions before deleting source records.
class ReadingHistoriesController < ApplicationController
  def destroy
    current_user.transaction do
      current_user.recommendation_sessions.destroy_all
      current_user.reading_profile&.destroy!
      current_user.reading_records.destroy_all
      current_user.imports.destroy_all
    end
    redirect_to root_path, notice: "読書履歴と推薦データを削除しました。"
  end
end
