class Share < ApplicationRecord
  belongs_to :entry
  belongs_to :sender, class_name: "User"
  belongs_to :recipient, class_name: "User", optional: true

  has_secure_token :token

  encrypts :entry_body_snapshot
end
