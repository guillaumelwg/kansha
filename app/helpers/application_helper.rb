module ApplicationHelper
  # Renders a UTC timestamp in current_user's saved timezone (spec.md §5 risk
  # zone: never display server/UTC time directly). Falls back to UTC if a
  # user has no timezone on record (e.g. signed up with JS disabled).
  def local_time(time, format: "%b %-d, %Y · %-l:%M %p")
    zone = ActiveSupport::TimeZone[current_user.timezone] || Time.zone
    time.in_time_zone(zone).strftime(format).squeeze(" ")
  end

  # Pre-written share text (US-10). Plain text only, no markup — this gets
  # copy-pasted as-is into WhatsApp/email/SMS, which don't render HTML.
  # Deliberately excludes the entry body itself: putting the gratitude in
  # the message would let the recipient read it without ever visiting the
  # link, which defeats the signup gate (US-12) and the claim mechanic.
  def share_message(share)
    "I wrote you something on Kansha — a small gratitude, just for you.\n\n#{share_url(token: share.token)}"
  end
end
