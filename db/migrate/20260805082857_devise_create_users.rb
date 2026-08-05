# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      ## Database authenticatable — no password, magic-link only (devise-passwordless)
      t.string :email, null: false, default: ""

      ## App fields (spec.md section 1)
      t.string :first_name
      t.string :timezone

      ## Rememberable — long-lived session across visits (US-08)
      t.datetime :remember_created_at

      t.timestamps null: false
    end

    add_index :users, :email, unique: true
  end
end
