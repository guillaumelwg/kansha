# Additive only (nullable, no default, no backfill) — dev and prod share one
# database, so this must be safe to run against either. Holds the share token
# between the sign-in form submit and the magic-link click, which can happen
# in two different browsers/devices. See Users::SessionsController#create and
# ApplicationController#after_sign_in_path_for.
class AddPendingShareTokenToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :pending_share_token, :string
  end
end
