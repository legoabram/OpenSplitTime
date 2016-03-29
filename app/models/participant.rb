class Participant < ActiveRecord::Base #TODO: create class Person with subclasses Participant and Effort
  enum gender: [:male, :female]
  has_many :interests, dependent: :destroy
  has_many :users, :through => :interests
  has_many :efforts
  belongs_to :claimant, class_name: 'User', foreign_key: 'user_id'

  validates_presence_of :first_name, :last_name, :gender

  def full_name
    first_name + " " + last_name
  end

  def bio
    approximate_age.nil? ? gender.titlecase : "#{gender.titlecase}, #{approximate_age}"
  end

  def approximate_age
    now = Time.now.utc.to_date
    return years_between_dates(birthdate, now).round(0) unless birthdate.nil?
    return nil unless efforts.count > 0
    approximate_age_array = []
    efforts.each do |effort|
      approximate_age_array << (years_between_dates(effort.event.first_start_time.to_date, now) + effort.age) unless effort.age.nil?
    end
    (approximate_age_array.inject(0.0) { |sum, el| sum + el } / approximate_age_array.size).round(0)
  end

  def years_between_dates(date1, date2)
    (date2 - date1) / 365.25
  end

  def unclaimed?
    claimant.nil?
  end

  def claimed?
    !unclaimed?
  end

  def self.where_email_matches(email)
    email.blank? ? nil : where(email: email.downcase)
  end

  def self.where_last_name_matches(last_name)
    where("lower(last_name) = ?", last_name.downcase) # TODO change to ILIKE for PGSQL production environment
  end

  def self.where_first_name_matches(first_name)
    where("lower(first_name) = ?", first_name.downcase) #TODO implement fuzzy matching and change to ILIKE for production
  end

  def self.where_name_matches(first_name, last_name)
    where_last_name_matches(last_name).where_first_name_matches(first_name)
  end

  # def self.where_age_approximates(age)
  #   map { |participant| participant.approximate_age == age ? participant : nil }.compact
  # end

  def self.columns_for_build_from_effort
    id = ["id"]
    birthdate = ["birthdate"]  # TODO add birthdate column to efforts and allow this field for creation
    foreign_keys = Participant.column_names.find_all { |x| x.include?("_id") }
    stamps = Participant.column_names.find_all { |x| x.include?("_at") | x.include?("_by") }
    (column_names - (id + birthdate + foreign_keys + stamps)).map &:to_sym
  end

  def build_from_effort(effort_id)
    @effort = Effort.find(effort_id)
    participant_attributes = Participant.columns_for_build_from_effort
    participant_attributes.each do |attribute|
      assign_attributes({attribute => @effort[attribute]})
    end
    if save
      @effort.participant = self
      @effort.save
    end
  end

end
