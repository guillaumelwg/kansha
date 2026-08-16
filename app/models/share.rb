class Share < ApplicationRecord
  belongs_to :entry
  belongs_to :sender, class_name: "User"
  belongs_to :recipient, class_name: "User", optional: true

  has_secure_token :token

  encrypts :entry_body_snapshot

  # recipient_id/claimed_at are only ever set together, by ClaimShare — see
  # app/services/claim_share.rb for why this can't just be a boolean column.
  def claimed?
    recipient_id.present?
  end
end
