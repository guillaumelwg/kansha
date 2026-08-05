class CreateShares < ActiveRecord::Migration[7.1]
  def change
    create_table :shares do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.string :token, null: false
      t.references :recipient, foreign_key: { to_table: :users }
      t.datetime :claimed_at
      t.text :entry_body_snapshot
      t.string :sender_name_snapshot

      t.timestamps
    end

    add_index :shares, :token, unique: true
  end
end
