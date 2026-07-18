# ABOUTME: Groups comparable algorithm outputs for a single reading goal.
# ABOUTME: Preserves the profile snapshot used to make the recommendations.
class RecommendationSession < ApplicationRecord
  GOALS = %w[light same_pace challenge explore].freeze
  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :user
  has_many :recommendations, dependent: :destroy

  validates :reading_goal, inclusion: { in: GOALS }
  validates :status, inclusion: { in: STATUSES }

  STATUSES.each do |value|
    define_method("#{value}?") { status == value }
  end
end
