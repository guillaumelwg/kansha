class User < ApplicationRecord
  # Magic-link only — no password. :registerable is kept for Devise's standard
  # param permitting; the actual "new email creates an account" signup flow
  # (spec.md section 3) needs a custom sessions controller, built in Slice 1.
  devise :magic_link_authenticatable, :registerable, :rememberable

  validates :email, presence: true, uniqueness: true,
                     format: { with: Devise.email_regexp }

  # Entries this user authored — spec.md's "My Gratitudes" (US-02).
  has_many :entries, dependent: :destroy

  # Shares this user sent as the entry's author — not "entries shared with me".
  has_many :shares_sent, class_name: "Share", foreign_key: :sender_id, dependent: :destroy

  # Shares claimed by this user — spec.md's "Gratitudes Received" (US-14).
  # Kept separate from shares_sent per CLAUDE.md's risk-zone note: never merge
  # "my entries" and "entries shared with me" into one query.
  has_many :shares_received, class_name: "Share", foreign_key: :recipient_id, dependent: :destroy
end
