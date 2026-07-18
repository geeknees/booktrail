# ABOUTME: Separates consented recommendation catalog books from private reading history.
# ABOUTME: Prevents imported user books from becoming candidates for other readers.
class AddRecommendableToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :recommendable, :boolean, null: false, default: false
    add_index :books, :recommendable

    reversible do |direction|
      direction.up do
        execute "UPDATE books SET recommendable = 1 WHERE metadata_source = 'fixture'"
      end
    end
  end
end
