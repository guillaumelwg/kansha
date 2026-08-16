class AddUnclaimedShareUniquenessToShares < ActiveRecord::Migration[7.1]
  def change
    # At most one unclaimed share per entry — enforced at the DB level
    # (not just via find_or_create_by in SharesController#create) so
    # concurrent clicks on the share CTA can't both create a fresh row.
    add_index :shares, :entry_id, unique: true, where: "claimed_at IS NULL",
              name: "index_shares_on_entry_id_unclaimed"
  end
end
