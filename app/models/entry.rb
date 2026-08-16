class Entry < ApplicationRecord
  belongs_to :user
  has_many :shares, dependent: :destroy

  encrypts :body

  validates :body, presence: true, length: { maximum: 5000 }
end
