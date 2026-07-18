# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_18_000002) do
  create_table "books", force: :cascade do |t|
    t.string "author"
    t.json "categories", default: [], null: false
    t.string "cover_image_url"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "isbn"
    t.string "language", default: "ja", null: false
    t.string "metadata_source", default: "csv", null: false
    t.integer "page_count"
    t.date "published_on"
    t.string "publisher"
    t.boolean "recommendable", default: false, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["isbn"], name: "index_books_on_isbn", unique: true, where: "isbn IS NOT NULL"
    t.index ["recommendable"], name: "index_books_on_recommendable"
  end

  create_table "imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "imported_at"
    t.string "original_filename", null: false
    t.json "result", default: {}, null: false
    t.string "source", default: "booklog", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_imports_on_user_id"
  end

  create_table "reading_profiles", force: :cascade do |t|
    t.json "completion_patterns", default: {}, null: false
    t.datetime "created_at", null: false
    t.json "favorite_authors", default: [], null: false
    t.json "favorite_topics", default: [], null: false
    t.datetime "generated_at", null: false
    t.json "preferred_categories", default: [], null: false
    t.text "summary", null: false
    t.integer "typical_page_count"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_reading_profiles_on_user_id", unique: true
  end

  create_table "reading_records", force: :cascade do |t|
    t.integer "book_id", null: false
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "rating"
    t.string "reading_status"
    t.datetime "registered_at"
    t.string "source", default: "booklog", null: false
    t.datetime "started_at"
    t.json "tags", default: [], null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["book_id"], name: "index_reading_records_on_book_id"
    t.index ["user_id", "book_id"], name: "index_reading_records_on_user_id_and_book_id", unique: true
    t.index ["user_id"], name: "index_reading_records_on_user_id"
  end

  create_table "recommendation_feedbacks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feedback_type", null: false
    t.integer "recommendation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recommendation_id"], name: "index_recommendation_feedbacks_on_recommendation_id"
  end

  create_table "recommendation_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.json "profile_snapshot", default: {}, null: false
    t.string "reading_goal", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_recommendation_sessions_on_user_id"
  end

  create_table "recommendations", force: :cascade do |t|
    t.string "algorithm", null: false
    t.integer "book_id", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "explanation", null: false
    t.integer "rank", null: false
    t.integer "recommendation_session_id", null: false
    t.float "score", null: false
    t.json "score_details", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_recommendations_on_book_id"
    t.index ["recommendation_session_id", "algorithm", "category", "rank"], name: "index_recommendations_for_comparison"
    t.index ["recommendation_session_id"], name: "index_recommendations_on_recommendation_session_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", default: "ja", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "imports", "users"
  add_foreign_key "reading_profiles", "users"
  add_foreign_key "reading_records", "books"
  add_foreign_key "reading_records", "users"
  add_foreign_key "recommendation_feedbacks", "recommendations"
  add_foreign_key "recommendation_sessions", "users"
  add_foreign_key "recommendations", "books"
  add_foreign_key "recommendations", "recommendation_sessions"
end
