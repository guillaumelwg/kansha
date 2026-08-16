# Claims an unclaimed Share for a recipient, exclusively (spec.md §5 risk
# zone: "first-claim race"). Only the first authenticated visitor to a share
# link should ever claim it; every visitor after that must be denied, not
# shown a stale or partial view.
#
# Uses a DB row lock (SELECT ... FOR UPDATE via Share.lock) inside a
# transaction so two concurrent claim attempts on the same share can't both
# pass a "is it claimed?" check before either writes — the second request
# blocks until the first commits, then re-checks and backs off. update_all
# can't be used here instead because entry_body_snapshot is an encrypted
# column and update_all bypasses Active Record's encryption callbacks.
class ClaimShare
  Result = Struct.new(:claimed?, :share, keyword_init: true)

  def self.call(share:, recipient:)
    new(share: share, recipient: recipient).call
  end

  def initialize(share:, recipient:)
    @share = share
    @recipient = recipient
  end

  def call
    Share.transaction do
      locked_share = Share.lock.find(@share.id)

      if locked_share.recipient_id.present?
        next Result.new(claimed?: false, share: locked_share)
      end

      locked_share.update!(
        recipient_id: @recipient.id,
        claimed_at: Time.current,
        entry_body_snapshot: locked_share.entry.body,
        sender_name_snapshot: locked_share.sender.first_name
      )
      Result.new(claimed?: true, share: locked_share)
    end
  end
end
