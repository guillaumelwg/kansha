# Profile screen (Slice 2.5) — first name edit, email display, sign out entry
# point, and a placeholder delete-account button. Sign out itself is handled
# by Devise's existing destroy_user_session_path, not this controller.
class ProfilesController < ApplicationController
  def show
  end

  def update
    if current_user.update(profile_params)
      redirect_to profile_path, notice: "Saved."
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def profile_params
    params.require(:user).permit(:first_name)
  end
end
