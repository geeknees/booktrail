# ABOUTME: Represents the demo reader and owns their private reading history.
# ABOUTME: Provides the aggregate root for profiles, imports, and recommendation sessions.
class User < ApplicationRecord
  has_many :imports, dependent: :destroy
  has_many :reading_records, dependent: :destroy
  has_many :books, through: :reading_records
  has_one :reading_profile, dependent: :destroy
  has_many :recommendation_sessions, dependent: :destroy

  validates :name, presence: true
  validates :locale, inclusion: { in: ->(_user) { I18n.available_locales.map(&:to_s) } }, allow_nil: true
end
