require "rails_helper"

# spec.md §5 risk zone: "first-claim race" — only the first authenticated
# visitor to a share link should ever claim it. The last example below is
# the one that actually matters for that: it forces two real threads/DB
# connections to contend for the same row lock, so it can't run inside
# RSpec's normal wrapping transaction (a single connection can't contend
# with itself).
RSpec.describe ClaimShare, type: :model do
  self.use_transactional_tests = false

  def create_user(prefix)
    User.create!(email: "claim-share-#{prefix}-#{SecureRandom.hex(4)}@example.com",
                 first_name: prefix.capitalize, timezone: "Europe/Paris")
  end

  def create_unclaimed_share
    sender = create_user("sender")
    entry = sender.entries.create!(body: "Grateful for you.")
    entry.shares.create!(sender: sender)
  end

  after do
    Share.where(sender: User.where("email LIKE 'claim-share-%'")).destroy_all
    User.where("email LIKE 'claim-share-%'").destroy_all
  end

  it "claims an unclaimed share and snapshots the entry body and sender name" do
    share = create_unclaimed_share
    recipient = create_user("recipient")

    result = ClaimShare.call(share: share, recipient: recipient)

    expect(result.claimed?).to eq(true)
    expect(share.reload.recipient_id).to eq(recipient.id)
    expect(share.claimed_at).to be_present
    expect(share.entry_body_snapshot).to eq(share.entry.body)
    expect(share.sender_name_snapshot).to eq(share.sender.first_name)
  end

  it "denies a second claim attempt once a share is already claimed" do
    share = create_unclaimed_share
    first_recipient = create_user("first")
    second_recipient = create_user("second")

    ClaimShare.call(share: share, recipient: first_recipient)
    result = ClaimShare.call(share: Share.find(share.id), recipient: second_recipient)

    expect(result.claimed?).to eq(false)
    expect(share.reload.recipient_id).to eq(first_recipient.id)
  end

  it "blocks a concurrent claimant on the row lock, then denies it once the holder commits" do
    share = create_unclaimed_share
    holder_recipient = create_user("holder")
    contender_recipient = create_user("contender")

    holder_has_lock = Queue.new
    release_holder = Queue.new
    contender_result = nil

    holder = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Share.transaction do
          locked = Share.lock.find(share.id)
          holder_has_lock << true
          release_holder.pop
          locked.update!(
            recipient_id: holder_recipient.id,
            claimed_at: Time.current,
            entry_body_snapshot: locked.entry.body,
            sender_name_snapshot: locked.sender.first_name
          )
        end
      end
    end

    holder_has_lock.pop

    contender = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        contender_result = ClaimShare.call(share: Share.find(share.id), recipient: contender_recipient)
      end
    end

    sleep 0.2
    expect(contender).to be_alive # still blocked waiting on the row lock

    release_holder << true
    holder.join(2)
    contender.join(2)

    expect(contender_result.claimed?).to eq(false)
    expect(share.reload.recipient_id).to eq(holder_recipient.id)
  end
end
