# ABOUTME: Captures one reader's status and rating for one book.
# ABOUTME: Enforces idempotency for repeated Booklog imports.
class ReadingRecord < ApplicationRecord
  belongs_to :user
  belongs_to :book

  validates :book_id, uniqueness: { scope: :user_id }
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true
end
