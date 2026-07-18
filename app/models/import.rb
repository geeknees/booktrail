# ABOUTME: Records one Booklog upload and its row-level outcome totals.
# ABOUTME: Exposes a durable audit trail without retaining the uploaded source file.
class Import < ApplicationRecord
  belongs_to :user

  validates :original_filename, :source, :status, presence: true
end
