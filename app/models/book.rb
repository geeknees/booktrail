# ABOUTME: Stores reusable catalog metadata independently from a reader's activity.
# ABOUTME: Normalizes and validates ISBN identifiers at import boundaries.
class Book < ApplicationRecord
  has_many :reading_records, dependent: :restrict_with_error
  has_many :recommendations, dependent: :restrict_with_error

  validates :title, presence: true
  validates :isbn, uniqueness: true, allow_nil: true

  scope :recommendable, -> { where(recommendable: true) }

  def series_key
    normalized = title.to_s.unicode_normalize(:nfkc).downcase.squish
    normalized = normalized.sub(/\s*\([上下中前後]\)\s*\z/, "")
    normalized = normalized.sub(/\s*(?:第?\d+巻|[上下中前後])\s*\z/, "")
    normalized = normalized.sub(/\A(.{2,}?)(?:[ivxlcdm]+|\d+)(?:\s.*)?\z/, '\\1')
    normalized
  end

  def self.normalize_isbn(value)
    digits = value.to_s.upcase.gsub(/[^0-9X]/, "")
    return digits if digits.length == 10 && valid_isbn10?(digits)
    digits if digits.length == 13 && valid_isbn13?(digits)
  end

  def self.valid_isbn10?(isbn)
    isbn.chars.each_with_index.sum { |char, index| (char == "X" ? 10 : char.to_i) * (10 - index) } % 11 == 0
  end
  private_class_method :valid_isbn10?

  def self.valid_isbn13?(isbn)
    isbn.chars.each_with_index.sum { |char, index| char.to_i * (index.even? ? 1 : 3) } % 10 == 0
  end
  private_class_method :valid_isbn13?
end
