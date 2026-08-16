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

    send_magic_link(resource)
    render :magic_link_sent
  end

  private

  # Every sign-in is a long-lived session (US-08) — there's no "remember me"
  # checkbox on the single-field screen, so always request it.
  def send_magic_link(resource)
    resource.send_magic_link(remember_me: true)
  end

  def create_params
    params.require(:user).permit(:email, :first_name, :timezone)
  end
end
