# ABOUTME: Defines the persisted reading history and recommendation data used by the MVP.
# ABOUTME: Keeps structured profile and score details as SQLite-friendly JSON columns.
class CreateBooktrailCore < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :locale, null: false, default: 'ja'
      t.timestamps
    end

    create_table :imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source, null: false, default: 'booklog'
      t.string :original_filename, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :imported_at
      t.text :error_message
      t.json :result, null: false, default: {}
      t.timestamps
    end

    create_table :books do |t|
      t.string :isbn
      t.string :title, null: false
      t.string :author
      t.string :publisher
      t.date :published_on
      t.integer :page_count
      t.text :description
      t.string :cover_image_url
      t.json :categories, null: false, default: []
      t.string :language, null: false, default: 'ja'
      t.string :metadata_source, null: false, default: 'csv'
      t.timestamps
    end
    add_index :books, :isbn, unique: true, where: 'isbn IS NOT NULL'

    create_table :reading_records do |t|
      t.references :user, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.integer :rating
      t.string :reading_status
      t.json :tags, null: false, default: []
      t.datetime :registered_at
      t.datetime :started_at
      t.datetime :finished_at
      t.string :source, null: false, default: 'booklog'
      t.timestamps
    end
    add_index :reading_records, %i[user_id book_id], unique: true

    create_table :reading_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :summary, null: false
      t.json :favorite_topics, null: false, default: []
      t.json :favorite_authors, null: false, default: []
      t.json :preferred_categories, null: false, default: []
      t.integer :typical_page_count
      t.json :completion_patterns, null: false, default: {}
      t.datetime :generated_at, null: false
      t.timestamps
    end

    create_table :recommendation_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :reading_goal, null: false
      t.json :profile_snapshot, null: false, default: {}
      t.datetime :generated_at, null: false
      t.timestamps
    end

    create_table :recommendations do |t|
      t.references :recommendation_session, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.string :algorithm, null: false
      t.string :category, null: false
      t.integer :rank, null: false
      t.float :score, null: false
      t.text :explanation, null: false
      t.json :score_details, null: false, default: {}
      t.timestamps
    end
    add_index :recommendations, %i[recommendation_session_id algorithm category rank], name: 'index_recommendations_for_comparison'

    create_table :recommendation_feedbacks do |t|
      t.references :recommendation, null: false, foreign_key: true
      t.string :feedback_type, null: false
      t.timestamps
    end
  end
end
