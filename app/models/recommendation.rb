# ABOUTME: Persists a ranked, explainable book suggestion from one algorithm.
# ABOUTME: Keeps developer score evidence separate from reader-facing prose.
class Recommendation < ApplicationRecord
  ALGORITHMS = %w[vector_only bm25_vector qmd_hybrid].freeze
  CATEGORIES = %w[likely_to_love easy_to_continue broaden_your_world].freeze

  belongs_to :recommendation_session
  belongs_to :book
  has_many :feedbacks, class_name: "RecommendationFeedback", dependent: :destroy

  validates :algorithm, inclusion: { in: ALGORITHMS }
  validates :category, inclusion: { in: CATEGORIES }
end
