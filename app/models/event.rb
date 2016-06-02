class Event < ActiveRecord::Base
  include Auditable
  include SplitMethods
  strip_attributes collapse_spaces: true
  belongs_to :course, touch: true
  belongs_to :race
  has_many :efforts, dependent: :destroy
  has_many :event_splits, dependent: :destroy
  has_many :splits, through: :event_splits

  validates_presence_of :course_id, :name, :start_time
  validates_uniqueness_of :name, case_sensitive: false

  scope :recent, -> (max) { order(start_time: :desc).limit(max) }
  scope :most_recent, -> { order(start_time: :desc).first }
  scope :earliest, -> { order(:start_time).first }

  def all_splits_on_course?
    splits.joins(:course).group(:course_id).count.size == 1
  end

  def reconciled_efforts
    efforts.where.not(participant_id: nil)
  end

  def unreconciled_efforts
    efforts.where(participant_id: nil)
  end

  def unreconciled_efforts?
    unreconciled_efforts.count > 0
  end

  def set_all_course_splits
    splits << course.splits
  end

  def time_hashes_all_similar_events
    result_hash = {}
    event_split_ids = ordered_split_ids
    complete_hash = SplitTime.where(split_id: event_split_ids).group_by(&:bitkey_hash)
    complete_hash.keys.each do |bitkey_hash|
      result_hash[bitkey_hash] = Hash[complete_hash[bitkey_hash].map { |split_time| [split_time.effort_id, split_time.time_from_start] }]
    end
    result_hash
  end

  def split_times
    SplitTime.includes(:effort).where(efforts: {event_id: id})
  end

  def split_time_hash
    split_times.group_by(&:bitkey_hash)
  end

  def data_status_hash(split_time_hash = nil)
    # Keys are effort_ids; Value is an array with column 0 effort status, columns 1..-1 time status
    return [] if efforts.count == 0
    split_time_hash ||= self.split_time_hash
    event_effort_ids = efforts.pluck(:id)
    result = event_effort_ids.map { |x| [x, nil] } # The nil is a placeholder for the row's collective data status
    ordered_split_ids.each do |split_id|
      hash = Hash[split_time_hash[split_id].map { |row| [row[:effort_id], row[:data_status]] }]
      result.collect! { |row| row << hash[row[0]] }
    end
    result = result.each { |row| row[1] = row[2..-1].compact.min } # Set row[1] to the minimum data status of the other rows
    Hash[result.map { |row| [row[0], row[1..-1]] }]
  end

  def efforts_sorted
    efforts.sorted_with_finish_status
  end

  def ids_sorted
    efforts.sorted_with_finish_status.map(&:id)
  end

  def combined_places(effort)
    raw_sort = efforts_sorted
    overall_place = raw_sort.map(&:id).index(effort.id) + 1
    gender_place = raw_sort[0...overall_place].map(&:gender).count(effort.gender)
    return overall_place, gender_place
  end

  def overall_place(effort)
    ids_sorted.index(effort.id) + 1
  end

  def gender_place(effort)
    combined_places(effort)[1]
  end

  # Methods for monitoring efforts while event is live

  def efforts_dropped
    efforts.where.not(dropped_split_id: nil).pluck(:id)
  end

  def efforts_finished
    efforts.sorted_by_finish_time.pluck(:id)
  end

  def efforts_in_progress
    unfinished_effort_ids = efforts.pluck(:id) - efforts_finished
    efforts.where(id: unfinished_effort_ids, dropped_split_id: nil)
  end

  def efforts_overdue # Returns an array of efforts with overdue_amount attribute
    result = []
    current_tfs = Time.now - start_time
    cache = SegmentCalculationsCache.new(self)
    efforts_in_progress.each do |effort|
      effort.overdue_amount = effort.due_next_time_from_start(cache) - (current_tfs + effort.start_offset)
      result << effort if effort.overdue_amount > 0
    end
    result
  end

  def sub_split_bitkey_hashes
    ordered_splits.map(&:sub_split_bitkey_hashes).flatten
  end

end
