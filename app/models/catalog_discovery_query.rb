# ABOUTME: Records a non-reversible digest for one external catalog lookup.
# ABOUTME: Keeps discovery cache metadata free of author names and reading history.
class CatalogDiscoveryQuery < ApplicationRecord
  validates :query_digest, presence: true, uniqueness: true
  validates :fetched_at, presence: true
end
