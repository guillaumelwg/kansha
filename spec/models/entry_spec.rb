require "rails_helper"

# US-03 delete risk zone (CLAUDE.md, spec.md §1 shares rationale). Locked
# behavior: an unclaimed share has no snapshot to fall back on, so it's
# destroyed with the entry and its link stops working entirely. A claimed
# share already has entry_body_snapshot/sender_name_snapshot, so it survives
# the entry's destruction (detached, entry_id -> nil) and the recipient's
# Received copy is unaffected.
RSpec.describe Entry, type: :model do
  def create_user(prefix)
    User.create!(email: "entry-spec-#{prefix}-#{SecureRandom.hex(4)}@example.com",
                 first_name: prefix.capitalize, timezone: "Europe/Paris")
  end

  it "destroys any unclaimed share along with the entry" do
    sender = create_user("sender")
    entry = sender.entries.create!(body: "Grateful for you.")
    share = entry.shares.create!(sender: sender)

    entry.destroy

    expect(Share.exists?(share.id)).to eq(false)
  end

  it "detaches a claimed share instead of destroying it, keeping the snapshot intact" do
    sender = create_user("sender")
    recipient = create_user("recipient")
    entry = sender.entries.create!(body: "Grateful for you.")
    share = entry.shares.create!(sender: sender)
    ClaimShare.call(share: share, recipient: recipient)

    entry.destroy

    share.reload
    expect(share.entry_id).to be_nil
    expect(share.entry_body_snapshot).to eq("Grateful for you.")
    expect(share.sender_name_snapshot).to eq("Sender")
    expect(recipient.shares_received).to include(share)
  end
end
