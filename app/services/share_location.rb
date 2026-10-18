# Pulls the share token out of a stored location such as "/shares/abc123"
# (Devise's session["user_return_to"], or the same path read back later).
# Returns nil for any other path, so callers can treat "not a share link"
# and "no location at all" the same way.
class ShareLocation
  PATTERN = %r{\A/shares/([^/?#]+)(?:[?#].*)?\z}

  def self.token_from(location)
    match = PATTERN.match(location.to_s)
    match && match[1]
  end
end
