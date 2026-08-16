require "rails_helper"

RSpec.describe Share, type: :model do
  it "rejects a second unclaimed share for the same entry at the DB level" do
    sender = User.create!(email: "share-spec-sender-#{SecureRandom.hex(4)}@example.com",
                           first_name: "Sender", timezone: "Europe/Paris")
    entry = sender.entries.create!(body: "Grateful for you.")
    entry.shares.create!(sender: sender)

    # Bypasses SharesController's find_or_create_by on purpose — this proves
    # the constraint holds even if application code forgets to check first,
    # not just that the happy path avoids duplicates.
    expect do
      entry.shares.create!(sender: sender)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
