# Handles the GET the user lands on after clicking the emailed magic link.
# Same as Devise::MagicLinksController#show, minus the "Signed in successfully."
# flash — it reads fine in isolation but is just noise above the New Entry
# title on first load after a magic-link sign-in.
class Users::MagicLinksController < Devise::MagicLinksController
  def show
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)
    yield resource if block_given?
    redirect_to after_sign_in_path_for(resource)
  end
end
