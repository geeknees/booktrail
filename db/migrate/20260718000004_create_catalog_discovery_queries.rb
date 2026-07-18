# ABOUTME: Persists only digests of consented catalog discovery queries.
# ABOUTME: Prevents repeated external searches without storing reader preference text.
class CreateCatalogDiscoveryQueries < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_discovery_queries do |t|
      t.string :query_digest, null: false
      t.datetime :fetched_at, null: false
      t.integer :result_count, null: false, default: 0
      t.timestamps
    end

    add_index :catalog_discovery_queries, :query_digest, unique: true
  end
end
