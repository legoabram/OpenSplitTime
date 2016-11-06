class Participant < ActiveRecord::Base
  include Auditable
  include Concealable
  include PersonalInfo
  include Searchable
  include SetOperations
  include Matchable
  strip_attributes collapse_spaces: true
  enum gender: [:male, :female]
  has_many :connections, dependent: :destroy
  has_many :followers, through: :connections, source: :user
  has_many :efforts
  belongs_to :claimant, class_name: 'User', foreign_key: 'user_id'

  attr_accessor :suggested_match

  scope :with_age_and_effort_count, -> { select('participants.*, COUNT(efforts.id) as effort_count, ROUND(AVG((extract(epoch from(current_date - events.start_time))/60/60/24/365.25) + efforts.age)) as participant_age')
                                             .joins('LEFT OUTER JOIN efforts ON (efforts.participant_id = participants.id)')
                                             .joins('LEFT OUTER JOIN events ON (events.id = efforts.event_id)')
                                             .group('participants.id') }
  scope :ordered_by_name, -> { order(:last_name, :first_name) }


  validates_presence_of :first_name, :last_name, :gender
  validates :email, allow_blank: true, length: {maximum: 105},
            uniqueness: {case_sensitive: false},
            format: {with: VALID_EMAIL_REGEX}


  def self.search(param)
    return none if param.blank? || (param.length < 3)
    flexible_search(param)
  end

  def self.age_matches(age_param)
    return none unless age_param.is_a?(Numeric)
    threshold = 2 # Allow for some inaccuracy in reporting, rounding errors, etc.
    age_hash = approximate_ages_today.merge(exact_ages_today)
                   .reject { |_, age| (age - age_param).abs > threshold }
    self.where(id: age_hash.keys)
  end

  def self.columns_to_pull_from_model
    id = ['id']
    foreign_keys = Participant.column_names.find_all { |x| x.include?('_id') }
    stamps = Participant.column_names.find_all { |x| x.include?('_at') | x.include?('_by') }
    geographic = %w(country_code state_code city)
    (column_names - (id + foreign_keys + stamps + geographic)).map &:to_sym
  end

  SQL = {ages_from_events: '((extract(epoch from(current_date - events.start_time))/60/60/24/365.25) + efforts.age)'}

  def self.approximate_ages_today # Returns a hash of {participant_id => approximate age}
    joins(:efforts => :event).group('participants.id').average(SQL[:ages_from_events]).transform_values(&:to_f)
  end

  private_class_method :approximate_ages_today

  def approximate_age_today
    average = efforts.joins(:event).average(SQL[:ages_from_events]).to_f
    average == 0 ? nil : average
  end

  def unclaimed?
    claimant.nil?
  end

  def claimed?
    claimant.present?
  end

  def add_follower(user)
    followers << user
  end

  def remove_follower(user)
    followers.delete(user)
  end

  # Methods related to matching and merging efforts with participants

  def most_likely_duplicate
    possible_matching_participants.first
  end

  def pull_data_from_effort(effort)
    pull_attributes(effort)
    if save
      effort.participant ||= self
      effort.save
    end
  end

  def merge_with(target)
    target_participant = Participant.find(target.id)
    pull_attributes(target_participant)
    if save
      efforts << target_participant.efforts
      target_participant.efforts.destroy_all
      target_participant.destroy
    end
  end

  private

  def pull_attributes(target)
    resolve_country(target)
    resolve_state_and_city(target)
    Participant.columns_to_pull_from_model.each do |attribute|
      assign_attributes({attribute => target[attribute]}) if self[attribute].blank?
    end
  end

  def resolve_country(target)
    return if target.country_code.blank?
    if country_code.blank? &&
        (state_code.blank? |
            (state_code == target.state_code) |
            (Carmen::Country.coded(target.country_code).subregions.coded(state_code)))
      assign_attributes(country_code: target.country_code)
    end
  end

  def resolve_state_and_city(target)
    return if target.state_code.blank?
    if state_code.blank? &&
        (country_code.blank? |
            (country_code == target.country_code) |
            (Carmen::Country.coded(country_code) &&
                Carmen::Country.coded(country_code).subregions.coded(target.state_code)))
      assign_attributes(state_code: target.state_code, city: target.city)
    elsif (state_code == target.state_code) && city.blank?
      assign_attributes(city: target.city)
    end
  end

end