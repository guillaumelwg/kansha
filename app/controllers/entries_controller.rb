class EntriesController < ApplicationController
  def new
    @entry = current_user.entries.new
  end

  def create
    @entry = current_user.entries.new(entry_params)

    if @entry.save
      redirect_to entry_path(@entry)
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @entry = current_user.entries.find(params[:id])
    # US-10 confirmation screen: reflect existing share state instead of
    # always showing a fresh CTA (Slice 3 fix — one active recipient per
    # entry for MVP). Unclaimed share → show its link again. Claimed share
    # and no unclaimed one → hide the CTA entirely, don't re-prompt.
    @unclaimed_share = @entry.shares.find_by(claimed_at: nil)
    @share_claimed = @unclaimed_share.nil? && @entry.shares.where.not(claimed_at: nil).exists?
  end

  def index
    # "My Gratitudes" (US-02) — entries this user authored, own query, never
    # merged with "entries shared with me" (spec.md §5 risk zone).
    @entries = current_user.entries.order(created_at: :desc)
  end

  private

  def entry_params
    params.require(:entry).permit(:body)
  end
end
