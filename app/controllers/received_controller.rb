# "Gratitudes Received" (US-14). Reads from shares_received (claimed shares
# where recipient_id == current_user.id) — a separate query from "my
# entries" (EntriesController#index), never merged (spec.md §5 risk zone).
class ReceivedController < ApplicationController
  def index
    @shares = current_user.shares_received.order(claimed_at: :desc)
  end

  def show
    @share = current_user.shares_received.find(params[:id])
  end
end
