class Entry < ApplicationRecord
  belongs_to :user

  encrypts :body
end
