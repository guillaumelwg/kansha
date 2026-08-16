class AddRememberTokenToUsers < ActiveRecord::Migration[7.1]
  def change
    # Required by Devise's :rememberable strategy when there's no password/salt
    # to derive a cookie value from (magic-link-only auth) — see devise-passwordless
    # README, "Compatibility with other Devise strategies".
    add_column :users, :remember_token, :string, limit: 20
  end
end
