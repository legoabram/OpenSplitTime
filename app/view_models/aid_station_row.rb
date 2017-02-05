class AidStationRow
  include ActionView::Helpers::TextHelper
  attr_reader :aid_station
  delegate :course, :race, to: :event
  delegate :event, :split, :split_id, to: :aid_station
  delegate :expected_day_and_time, :prior_valid_display_data, :next_valid_display_data, to: :live_event

  AID_EFFORT_CATEGORIES = [:recorded_in, :recorded_out, :dropped_here, :in_aid, :missed, :expected]
  IN_BITKEY = SubSplit::IN_BITKEY
  OUT_BITKEY = SubSplit::OUT_BITKEY

  def initialize(args)
    ArgsValidator.validate(params: args,
                           required: :aid_station,
                           exclusive: [:aid_station, :event_data, :split_times],
                           class: self.class)
    @aid_station = args[:aid_station]
    @event_data = args[:event_data]
    @split_times = args[:split_times]
  end

  def category_effort_lap_keys
    @category_effort_lap_keys ||=
        AID_EFFORT_CATEGORIES.map { |category| [category, method("row_#{category}_lap_keys").call] }.to_h
  end

  def category_sizes
    @category_sizes ||= category_effort_lap_keys.transform_values(&:size)
  end

  def category_table_titles
    @category_table_titles ||=
        category_sizes.map { |category, count| [category, table_title(category, count)] }.to_h
  end

  def split_name
    split.base_name
  end

  private

  START_LAP = 1

  attr_reader :event_data, :split_times
  delegate :ordered_split_ids, :efforts_dropped, :efforts_started,
           :efforts_dropped_ids, :efforts_started_ids, to: :event_data

  def row_recorded_in_lap_keys
    @efforts_recorded_in_lap_keys ||=
        split_times.select { |st| st.sub_split_bitkey == IN_BITKEY }.map(&:effort_lap_key)
  end

  def row_recorded_out_lap_keys
    @efforts_recorded_out_lap_keys ||=
        split_times.select { |st| st.sub_split_bitkey == OUT_BITKEY }.map(&:effort_lap_key)
  end

  def row_dropped_here_lap_keys
    @efforts_dropped_here_lap_keys ||=
        efforts_dropped.select { |effort| effort.dropped_split_id == split_id}.map(&:id)
  end

  def row_recorded_later_lap_keys
    @row_recorded_later_lap_keys ||= efforts_started.select { |effort| recorded_later?(effort) }.map(&:id)
  end

  def row_in_aid_lap_keys
    split_records_in_time_only? ? [] : row_recorded_in_lap_keys - row_recorded_out_lap_keys - row_dropped_here_lap_keys
  end

  def row_missed_lap_keys
    row_not_recorded_lap_keys & row_recorded_later_lap_keys
  end

  def row_expected_lap_keys
    row_not_recorded_lap_keys - row_missed_lap_keys - efforts_dropped_lap_keys
  end

  def row_not_recorded_lap_keys
    efforts_started_lap_keys - row_recorded_in_lap_keys - row_recorded_out_lap_keys
  end

  def efforts_started_lap_keys
    efforts_started_ids.map { |id| EffortLapKey.new(id, START_LAP) }
  end

  def split_records_in_time_only?
    split.sub_split_bitmap == IN_BITKEY
  end

  def recorded_later?(effort)
    ordered_split_ids.index(effort.final_split_id) > ordered_split_ids.index(split_id)
  end

  def table_title(category, count)
    "#{pluralize(count, 'person')} #{category_phrase(category, count)} at #{split_name}"
  end

  def category_phrase(category, count)
    case category
    when :in_aid
      "#{'is'.pluralize(count)} in aid"
    when :missed
      'passed through without being recorded'
    when :dropped_here
      'dropped'
    when :expected
      "#{'is'.pluralize(count)} still expected"
    else
      "#{'was'.pluralize(count)} #{category.to_s.humanize(capitalize: false)}"
    end
  end
end