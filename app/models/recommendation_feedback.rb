# ABOUTME: Captures explicit reader reactions that refine future sessions.
# ABOUTME: Restricts feedback to the four choices shown on recommendation cards.
class RecommendationFeedback < ApplicationRecord
  TYPES = %w[want_to_read maybe_later not_for_me already_read].freeze

  belongs_to :recommendation
  validates :feedback_type, inclusion: { in: TYPES }
end
