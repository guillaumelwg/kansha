require "rails_helper"

# US-10 fix: at most one active (unclaimed) share per entry for MVP —
# multi-recipient sharing is deferred to post-MVP. See
# app/controllers/shares_controller.rb#create and the partial unique index
# in db/migrate/20260816162704_add_unclaimed_share_uniqueness_to_shares.rb.
RSpec.describe "POST /entries/:id/shares", type: :request do
  def create_sender
    User.create!(email: "shares-spec-sender-#{SecureRandom.hex(4)}@example.com",
                 first_name: "Sender", timezone: "Europe/Paris")
  end

  it "reuses the existing unclaimed share instead of creating a second one" do
    sender = create_sender
    entry = sender.entries.create!(body: "Grateful for you.")
    sign_in sender

    post entry_shares_path(entry)
    first_token = Share.sole.token

    post entry_shares_path(entry)

    expect(Share.count).to eq(1)
    expect(Share.sole.token).to eq(first_token)
  end

  it "creates a new share for the next recipient once the existing one is claimed" do
    sender = create_sender
    entry = sender.entries.create!(body: "Grateful for you.")
    sign_in sender

    post entry_shares_path(entry)
    claimed_share = Share.sole
    recipient = User.create!(email: "shares-spec-recipient-#{SecureRandom.hex(4)}@example.com",
                              first_name: "Recipient", timezone: "Europe/Paris")
    ClaimShare.call(share: claimed_share, recipient: recipient)

    post entry_shares_path(entry)

    expect(Share.count).to eq(2)
    expect(Share.where(claimed_at: nil).count).to eq(1)
    expect(Share.where(claimed_at: nil).sole.token).not_to eq(claimed_share.token)
  end
end

# Claim-check ordering fix: a stranger opening an already-claimed link must
# be denied immediately, without being routed through signup/login first.
# See app/controllers/shares_controller.rb#show.
RSpec.describe "GET /shares/:token", type: :request do
  def create_user(prefix)
    User.create!(email: "shares-token-spec-#{prefix}-#{SecureRandom.hex(4)}@example.com",
                 first_name: prefix.capitalize, timezone: "Europe/Paris")
  end

  def create_claimed_share
    sender = create_user("sender")
    entry = sender.entries.create!(body: "Grateful for you.")
    share = entry.shares.create!(sender: sender)
    recipient = create_user("recipient")
    ClaimShare.call(share: share, recipient: recipient)
    [share, sender, recipient]
  end

  it "denies an unauthenticated visitor immediately, without redirecting to signup/login" do
    share, = create_claimed_share

    get share_path(token: share.token)

    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include("Already claimed")
    expect(response).not_to redirect_to(new_user_session_path)
  end

  it "denies an authenticated third party" do
    share, = create_claimed_share
    outsider = create_user("outsider")
    sign_in outsider

    get share_path(token: share.token)

    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include("Already claimed")
  end

  it "still lets the original sender view their own already-claimed share" do
    share, sender, = create_claimed_share
    sign_in sender

    get share_path(token: share.token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Your gratitude")
  end

  it "still lets the claiming recipient re-view their claim" do
    share, _sender, recipient = create_claimed_share
    sign_in recipient

    get share_path(token: share.token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("sent you a gratitude")
  end

  it "still routes an unauthenticated visitor to sign in when the share isn't claimed yet" do
    sender = create_user("sender")
    entry = sender.entries.create!(body: "Grateful for you.")
    share = entry.shares.create!(sender: sender)

    get share_path(token: share.token)

    expect(response).to redirect_to(new_user_session_path)
  end
end
