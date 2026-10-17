require "rails_helper"

# US-03 (edit/delete) and the "seen by your recipient" indicator, Slice 4.
# Delete semantics live in Entry#destroy_unclaimed_shares_and_detach_claimed_shares
# (see spec/models/entry_spec.rb for the model-level cases); these specs
# cover the HTTP behavior around them.
RSpec.describe "Entries edit/update/destroy", type: :request do
  def create_user(prefix)
    User.create!(email: "entries-spec-#{prefix}-#{SecureRandom.hex(4)}@example.com",
                 first_name: prefix.capitalize, timezone: "Europe/Paris")
  end

  describe "PATCH /entries/:id" do
    it "updates the body and redirects to the entry" do
      user = create_user("author")
      entry = user.entries.create!(body: "Old text.")
      sign_in user

      patch entry_path(entry), params: { entry: { body: "New text." } }

      expect(response).to redirect_to(entry_path(entry))
      expect(entry.reload.body).to eq("New text.")
    end

    it "re-renders the edit form and keeps the old body when the body is blank" do
      user = create_user("author")
      entry = user.entries.create!(body: "Old text.")
      sign_in user

      patch entry_path(entry), params: { entry: { body: "" } }

      expect(response).to have_http_status(422)
      expect(response.body).to include("Edit entry")
      expect(entry.reload.body).to eq("Old text.")
    end

    it "does not let another user edit the entry" do
      author = create_user("author")
      entry = author.entries.create!(body: "Old text.")
      sign_in create_user("outsider")

      patch entry_path(entry), params: { entry: { body: "Hijacked." } }

      expect(response).to have_http_status(:not_found)
      expect(entry.reload.body).to eq("Old text.")
    end
  end

  describe "DELETE /entries/:id" do
    it "deletes the entry and destroys its unclaimed share" do
      user = create_user("author")
      entry = user.entries.create!(body: "Grateful for you.")
      share = entry.shares.create!(sender: user)
      sign_in user

      delete entry_path(entry)

      expect(response).to redirect_to(entries_path)
      expect(Entry.exists?(entry.id)).to eq(false)
      expect(Share.exists?(share.id)).to eq(false)
    end

    it "detaches a claimed share, and the recipient still sees the snapshot in Received" do
      sender = create_user("sender")
      recipient = create_user("recipient")
      entry = sender.entries.create!(body: "Grateful for you.")
      share = entry.shares.create!(sender: sender)
      ClaimShare.call(share: share, recipient: recipient)
      sign_in sender

      delete entry_path(entry)

      expect(Entry.exists?(entry.id)).to eq(false)
      expect(share.reload.entry_id).to be_nil

      sign_out sender
      sign_in recipient

      get received_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Grateful for you.")
      expect(response.body).to include("From Sender")

      get received_entry_path(share)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Grateful for you.")
      expect(response.body).to include("Sender sent you a gratitude")
    end

    it "still renders the detached claimed link for the recipient, and for the sender" do
      sender = create_user("sender")
      recipient = create_user("recipient")
      entry = sender.entries.create!(body: "Grateful for you.")
      share = entry.shares.create!(sender: sender)
      ClaimShare.call(share: share, recipient: recipient)
      entry.destroy

      sign_in recipient
      get share_path(token: share.token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Grateful for you.")

      sign_out recipient
      sign_in sender
      get share_path(token: share.token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("You shared this gratitude")
      expect(response.body).to include("Grateful for you.")
    end

    it "does not let another user delete the entry" do
      author = create_user("author")
      entry = author.entries.create!(body: "Keep me.")
      sign_in create_user("outsider")

      delete entry_path(entry)

      expect(response).to have_http_status(:not_found)
      expect(Entry.exists?(entry.id)).to eq(true)
    end
  end
end

RSpec.describe "Seen by recipient indicator", type: :request do
  def create_user(prefix)
    User.create!(email: "seen-spec-#{prefix}-#{SecureRandom.hex(4)}@example.com",
                 first_name: prefix.capitalize, timezone: "Europe/Paris")
  end

  let(:sender) { create_user("sender") }
  let(:entry) { sender.entries.create!(body: "Grateful for you.") }

  describe "GET /entries/:id" do
    it "shows nothing when the entry has never been shared" do
      sign_in sender

      get entry_path(entry)

      expect(response.body).not_to include("recipient.")
    end

    it "says 'Not yet seen by your recipient.' while the share is unclaimed" do
      entry.shares.create!(sender: sender)
      sign_in sender

      get entry_path(entry)

      expect(response.body).to include("Not yet seen by your recipient.")
    end

    it "says 'Seen by your recipient.' once the share is claimed" do
      share = entry.shares.create!(sender: sender)
      ClaimShare.call(share: share, recipient: create_user("recipient"))
      sign_in sender

      get entry_path(entry)

      expect(response.body).to include("Seen by your recipient.")
      expect(response.body).not_to include("Not yet seen")
    end
  end

  describe "GET /shares/:token as the sender" do
    it "says 'Not yet seen by your recipient.' on an unclaimed share" do
      share = entry.shares.create!(sender: sender)
      sign_in sender

      get share_path(token: share.token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Not yet seen by your recipient.")
    end

    it "says 'Seen by your recipient.' on a claimed share" do
      share = entry.shares.create!(sender: sender)
      ClaimShare.call(share: share, recipient: create_user("recipient"))
      sign_in sender

      get share_path(token: share.token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Seen by your recipient.")
      expect(response.body).not_to include("Not yet seen")
    end
  end
end
