class AllowNullEntryIdOnShares < ActiveRecord::Migration[7.1]
  def change
    # Claimed shares must survive the entry's destruction (spec.md §1 shares
    # rationale, CLAUDE.md delete risk-zone note) — entry_id gets nulled out
    # on claimed rows instead of being destroyed with the entry. See
    # Entry#destroy_unclaimed_shares_and_detach_claimed_shares.
    change_column_null :shares, :entry_id, true
  end
end
