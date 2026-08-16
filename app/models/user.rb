class User < ApplicationRecord
  # Magic-link only — no password, no separate registration flow. New-vs-
  # existing-email is decided in Users::SessionsController#create (spec.md §3).
  devise :magic_link_authenticatable, :rememberable

  validates :email, presence: true, uniqueness: true,
                     format: { with: Devise.email_regexp }
  validates :first_name, presence: true

  # Entries this user authored — spec.md's "My Gratitudes" (US-02).
  has_many :entries, dependent: :destroy

  # Shares this user sent as the entry's author — not "entries shared with me".
  has_many :shares_sent, class_name: "Share", foreign_key: :sender_id, dependent: :destroy

  # Shares claimed by this user — spec.md's "Gratitudes Received" (US-14).
  # Kept separate from shares_sent per CLAUDE.md's risk-zone note: never merge
  # "my entries" and "entries shared with me" into one query.
  has_many :shares_received, class_name: "Share", foreign_key: :recipient_id, dependent: :destroy
end
