require "rails_helper"

# The share link and the magic link can be opened in different browsers or
# devices. Only the browser that opened the share link has Devise's
# session["user_return_to"]; the token is therefore saved on the user at form
# submit (Users::SessionsController#remember_pending_share) and read back in
# ApplicationController#after_sign_in_path_for.
#
# Everything runs in-process: the real sign-in form POST, the real email from
# the test mailer, and a second integration session (open_session) standing in
# for a second browser with its own empty cookie jar.
RSpec.describe "Share token across browsers", type: :request do
  let(:sender) do
    User.create!(email: "sender-#{SecureRandom.hex(4)}@example.com", first_name: "Sender", timezone: "Europe/Paris")
  end
  let(:entry) { sender.entries.create!(body: "Grateful for you.") }
  let!(:share) { entry.shares.create!(sender: sender) }
  let(:recipient_email) { "recipient-#{SecureRandom.hex(4)}@example.com" }

  before { ActionMailer::Base.deliveries.clear }

  # Browser A: opens the share link logged out, lands on the sign-in form.
  def open_share_link(browser)
    browser.get share_path(share.token)
    expect(browser.response).to redirect_to(new_user_session_path)
    browser.get new_user_session_path
  end

  def submit_form(browser, email: recipient_email)
    browser.post user_session_path,
                 params: { user: { email: email, first_name: "Recipient", timezone: "Europe/Paris" } }
    expect(browser.response).to have_http_status(:ok)
  end

  def magic_link_path
    html = ActionMailer::Base.deliveries.last.html_part&.body&.decoded || ActionMailer::Base.deliveries.last.body.decoded
    href = html[/href="([^"]+)"/, 1]
    URI.parse(CGI.unescapeHTML(href)).request_uri
  end

  def recipient
    User.find_by!(email: recipient_email)
  end

  # `redirect_to` reads the example's own response, not a second session's,
  # so compare the second browser's Location header directly.
  def redirected_path(browser)
    expect(browser.response).to have_http_status(:found)
    URI.parse(browser.response.location).request_uri
  end

  def expect_landed_on_share(browser)
    expect(redirected_path(browser)).to eq(share_path(share.token))
    browser.follow_redirect!
    expect(browser.response).to have_http_status(:ok)
    expect(browser.response.body).to include("Sender sent you a gratitude")
    expect(share.reload).to be_claimed
    expect(share.recipient).to eq(recipient)
    browser.get received_path
    expect(browser.response.body).to include("From Sender")
  end

  def expect_landed_on_new_entry(browser)
    expect(redirected_path(browser)).to eq(root_path)
    browser.follow_redirect!
    expect(browser.response.body).to include("New Entry")
  end

  describe "cross-browser: new user" do
    it "claims the share when the magic link is opened with a fresh session" do
      open_share_link(self)
      submit_form(self)
      expect(recipient.pending_share_token).to eq(share.token)

      browser_b = open_session
      browser_b.get magic_link_path

      expect_landed_on_share(browser_b)
      expect(recipient.reload.pending_share_token).to be_nil
    end
  end

  describe "cross-browser: existing logged-out user" do
    it "claims the share and keeps the stored first name" do
      existing = User.create!(email: recipient_email, first_name: "Existing", timezone: "Europe/Paris")

      open_share_link(self)
      submit_form(self)
      expect(existing.reload.pending_share_token).to eq(share.token)
      expect(existing.first_name).to eq("Existing")

      browser_b = open_session
      browser_b.get magic_link_path

      expect_landed_on_share(browser_b)
      expect(existing.reload.pending_share_token).to be_nil
    end
  end

  describe "same browser" do
    it "still lands on the share" do
      open_share_link(self)
      submit_form(self)

      get magic_link_path

      expect_landed_on_share(self)
      expect(recipient.reload.pending_share_token).to be_nil
    end

    it "keeps Devise's behavior for a stored location that is not a share link" do
      get entries_path
      expect(response).to redirect_to(new_user_session_path)
      submit_form(self)

      get magic_link_path

      expect(response).to redirect_to(entries_path)
    end
  end

  describe "stale token" do
    def claim_elsewhere
      other = User.create!(email: "other-#{SecureRandom.hex(4)}@example.com", first_name: "Other", timezone: "Europe/Paris")
      ClaimShare.call(share: share, recipient: other)
    end

    it "does not redirect to a share claimed between signup and the magic-link click" do
      open_share_link(self)
      submit_form(self)
      claim_elsewhere

      browser_b = open_session
      browser_b.get magic_link_path

      expect_landed_on_new_entry(browser_b)
      expect(recipient.reload.pending_share_token).to be_nil
      expect(share.reload.recipient.email).to start_with("other-")
    end

    it "does not redirect to a share whose entry was deleted in the meantime" do
      open_share_link(self)
      submit_form(self)
      entry.destroy!

      browser_b = open_session
      browser_b.get magic_link_path

      expect_landed_on_new_entry(browser_b)
      expect(recipient.reload.pending_share_token).to be_nil
    end

    it "does not follow Devise's stored location to a share claimed in the meantime (same browser)" do
      open_share_link(self)
      submit_form(self)
      claim_elsewhere

      get magic_link_path

      expect_landed_on_new_entry(self)
      expect(recipient.reload.pending_share_token).to be_nil
    end

    it "does not follow Devise's stored location to a share deleted in the meantime (same browser)" do
      open_share_link(self)
      submit_form(self)
      entry.destroy!

      get magic_link_path

      expect_landed_on_new_entry(self)
    end
  end

  describe "normal login without a share link" do
    it "lands on New Entry and leaves pending_share_token empty" do
      get new_user_session_path
      submit_form(self)
      expect(recipient.pending_share_token).to be_nil

      get magic_link_path

      expect_landed_on_new_entry(self)
    end
  end
end
