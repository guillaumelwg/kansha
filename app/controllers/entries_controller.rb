class EntriesController < ApplicationController
  def new
    @entry = current_user.entries.new
  end

  def create
    @entry = current_user.entries.new(entry_params)

    if @entry.save
      flash[:just_created] = true
      redirect_to entry_path(@entry)
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @entry = current_user.entries.find(params[:id])
    # US-10 confirmation screen (Slice 3 fix): whether the entry has been
    # claimed is the only thing that should persist across page loads. The
    # expanded "share text" block is purely an in-page reveal after clicking
    # Share (see shares/create.turbo_stream.erb) — every fresh load shows the
    # CTA again, even though an unclaimed Share row already exists behind it.
    @share_claimed = @entry.shares.where.not(claimed_at: nil).exists?
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
