# ABOUTME: Makes recommendation generation observable while Solid Queue works.
# ABOUTME: Preserves completed legacy sessions and allows generation timestamps to be deferred.
class AddGenerationStatusToRecommendationSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :recommendation_sessions, :status, :string, null: false, default: "pending"
    add_column :recommendation_sessions, :started_at, :datetime
    add_column :recommendation_sessions, :error_message, :text
    add_index :recommendation_sessions, :status
    change_column_null :recommendation_sessions, :generated_at, true

    execute <<~SQL.squish
      UPDATE recommendation_sessions
      SET status = 'completed'
      WHERE generated_at IS NOT NULL
    SQL
  end

  def down
    execute "DELETE FROM recommendation_sessions WHERE generated_at IS NULL"
    change_column_null :recommendation_sessions, :generated_at, false
    remove_index :recommendation_sessions, :status
    remove_column :recommendation_sessions, :error_message
    remove_column :recommendation_sessions, :started_at
    remove_column :recommendation_sessions, :status
  end
end
