class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  protected

  # Where to go after the magic link is clicked. A share link wins, but only
  # if that share still exists and is unclaimed; otherwise the default
  # landing page (New Entry). Two sources can name a share:
  #   1. user.pending_share_token - saved at form submit, works even when the
  #      magic link is opened in a different browser/device (no session).
  #   2. Devise's stored location - same-browser flow.
  # Both are always consumed here, and both go through the same "still
  # claimable" check, so neither can send the user to a share that was
  # claimed or deleted in the meantime. A stored location that is not a
  # share link keeps Devise's normal behavior.
  def after_sign_in_path_for(resource)
    pending_token = resource.pending_share_token
    resource.update!(pending_share_token: nil) if pending_token.present?

    stored_location = stored_location_for(resource)
    stored_token = ShareLocation.token_from(stored_location)

    return share_path(pending_token) if claimable_share?(pending_token)
    return share_path(stored_token) if claimable_share?(stored_token)

    # A stale share link (claimed/deleted since) is dropped, not followed.
    return stored_location if stored_location.present? && stored_token.nil?

    super
  end

  private

  def claimable_share?(token)
    token.present? && Share.exists?(token: token, recipient_id: nil)
  end
end
