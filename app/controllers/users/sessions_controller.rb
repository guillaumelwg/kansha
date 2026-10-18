# Single email + first-name "Continue" screen (spec.md §3) — no separate
# sign-up/sign-in choice. An unrecognized email auto-creates the User here
# before the magic link is sent; a recognized email is sent a link without
# touching its stored first_name, even if the submitted name differs.
class Users::SessionsController < Devise::Passwordless::SessionsController
  def create
    email = create_params[:email].to_s.downcase.strip
    self.resource = resource_class.find_by(email: email)

    if resource.nil?
      self.resource = resource_class.new(
        email: email,
        first_name: create_params[:first_name],
        timezone: create_params[:timezone]
      )

      unless resource.save
        render :new, status: devise_error_status
        return
      end
    end

    remember_pending_share(resource)
    send_magic_link(resource)
    render :magic_link_sent
  end

  private

  # The share link and the magic link can be opened in two different
  # browsers/devices, and only the first one has the stored location in its
  # session. So while we still have that session (this POST), copy the share
  # token onto the user; ApplicationController#after_sign_in_path_for reads it
  # back when the magic link is clicked, wherever that happens.
  #
  # Read with session[...] (not stored_location_for) so the key stays in the
  # session: the same-browser flow still needs it after sign-in.
  def remember_pending_share(user)
    token = ShareLocation.token_from(session["user_return_to"])
    user.update!(pending_share_token: token) if token
  end

  # Every sign-in is a long-lived session (US-08) — there's no "remember me"
  # checkbox on the single-field screen, so always request it.
  def send_magic_link(resource)
    resource.send_magic_link(remember_me: true)
  end

  def create_params
    params.require(:user).permit(:email, :first_name, :timezone)
  end
end
