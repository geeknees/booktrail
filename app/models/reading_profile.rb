# ABOUTME: Stores an explainable snapshot of inferred reading preferences.
# ABOUTME: Uses reader-safe language and structured facets for recommendation queries.
class ReadingProfile < ApplicationRecord
  belongs_to :user

  validates :summary, :generated_at, presence: true

  def snapshot
    attributes.slice("summary", "favorite_topics", "favorite_authors", "preferred_categories", "typical_page_count", "completion_patterns")
  end
end
