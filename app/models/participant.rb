class Participant < ActiveRecord::Base
  belongs_to :country
  has_many :interests
  has_many :users, :through => :interests

  validates_presence_of :first_name, :last_name, :gender
  validates :country, presence: true, unless: 'country_id.nil?'
  enum gender: [:male, :female]
end