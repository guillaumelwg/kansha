# US-10/12/13 (spec.md §2). #create is the share CTA on the post-save
# confirmation screen; #show is the recipient-facing /shares/:token link,
# and is also where the sender lands if they open their own link.
class SharesController < ApplicationController
  # #show must run for unauthenticated visitors too, so the claimed-check
  # below can deny them before they're routed through signup/login — see
  # the claimed-check comment in #show.
  skip_before_action :authenticate_user!, only: [:show]
  before_action :set_entry, only: [:create]

  def create
    # At most one unclaimed share per entry (Slice 3 fix) — reuse the
    # existing token if the CTA is clicked again before it's claimed,
    # rather than minting a new link every time. Once a share is claimed,
    # this creates a fresh one for the next recipient (partial unique index
    # on shares only constrains claimed_at IS NULL rows).
    @share = Share.find_or_create_by(entry: @entry, sender: current_user, claimed_at: nil)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @entry }
    end
  end

  def show
    @share = Share.find_by!(token: params[:token])

    # Claimed-check comes first, before any auth branching, so a stranger
    # opening an already-claimed link is denied immediately instead of
    # being sent through signup/login only to be denied afterward. An
    # unauthenticated visitor can never be the sender or claimant (we have
    # no identity to check yet), so they're always denied here. An
    # authenticated visitor still gets through if they're the sender
    # previewing their own link, or the recipient re-visiting their claim
    # (spec.md: "only the sender and the claimed recipient can ever access
    # the entry via this link").
    if @share.claimed?
      if user_signed_in? && [@share.sender_id, @share.recipient_id].include?(current_user.id)
        render :show
      else
        render :denied, status: :forbidden
      end
      return
    end

    authenticate_user!

    if current_user.id == @share.sender_id
      # Sender previewing their own unclaimed link — never claims it
      # themselves, so the real recipient isn't locked out.
      render :show and return
    end

    result = ClaimShare.call(share: @share, recipient: current_user)
    @share = result.share

    if result.claimed?
      render :show
    else
      render :denied, status: :forbidden
    end
  end

  private

  def set_entry
    @entry = current_user.entries.find(params[:entry_id])
  end
end
