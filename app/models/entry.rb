class Entry < ApplicationRecord
  belongs_to :user
  has_many :shares

  encrypts :body

  validates :body, presence: true, length: { maximum: 5000 }

  before_destroy :destroy_unclaimed_shares_and_detach_claimed_shares

  private

  # US-03 delete risk zone (CLAUDE.md, spec.md §1 shares rationale): an
  # unclaimed share has no snapshot yet, so it can't survive the entry —
  # destroy it, which also makes its link stop working (SharesController#show
  # treats a missing share the same as an already-claimed denial). A claimed
  # share already has its own entry_body_snapshot/sender_name_snapshot, so it
  # just gets detached (entry_id -> nil) instead of destroyed, keeping the
  # recipient's Received copy intact. update_all is safe here since entry_id
  # isn't an encrypted column.
  def destroy_unclaimed_shares_and_detach_claimed_shares
    shares.where(claimed_at: nil).destroy_all
    shares.where.not(claimed_at: nil).update_all(entry_id: nil)
  end
end
