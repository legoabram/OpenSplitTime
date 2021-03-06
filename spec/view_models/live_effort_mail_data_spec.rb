require 'rails_helper'

RSpec.describe LiveEffortMailData do
  let(:split_times_101) { build_stubbed_list(:split_times_in_out, 5, effort_id: 101) }
  let(:split_ids) { split_times_101.map(&:split_id).uniq }
  let(:split1) { build_stubbed(:start_split, id: split_ids[0], course_id: 10, distance_from_start: 0) }
  let(:split2) { build_stubbed(:split, id: split_ids[1], course_id: 10, distance_from_start: 1000) }
  let(:split3) { build_stubbed(:split, id: split_ids[2], course_id: 10, distance_from_start: 2000) }
  let(:split4) { build_stubbed(:split, id: split_ids[3], course_id: 10, distance_from_start: 3000) }
  let(:split5) { build_stubbed(:split, id: split_ids[4], course_id: 10, distance_from_start: 4000) }
  let(:split6) { build_stubbed(:finish_split, id: split_ids[5], course_id: 10, distance_from_start: 5000) }

  describe '#initialize' do
    it 'initializes with a person and split_times in an args hash' do
      person = build_stubbed(:person)
      split_times = split_times_101
      expect { LiveEffortMailData.new(person: person, split_times: split_times) }.not_to raise_error
    end

    it 'raises an ArgumentError if no person or person_id is given' do
      split_times = split_times_101
      expect { LiveEffortMailData.new(split_times: split_times) }.to raise_error(/must include one of person or person_id/)
    end

    it 'raises an ArgumentError if any parameter other than person, person_id, split_times, or split_times_ids are given' do
      person = build_stubbed(:person)
      split_times = split_times_101
      expect { LiveEffortMailData.new(person: person, split_times: split_times, random_param: 123) }
          .to raise_error(/may not include random_param/)
    end
  end

  describe '#effort_data' do
    let(:person) { build_stubbed(:person) }
    let(:event) { build_stubbed(:event_functional, laps_required: 2, splits_count: 3, efforts_count: 1) }
    let(:test_effort) { event.efforts.first }
    let(:split_times) { test_effort.split_times }

    before { FactoryBot.reload }

    it 'returns a hash containing effort and split_time data' do
      effort = test_effort
      allow(effort).to receive(:ordered_split_times).and_return(split_times)
      in_split_time = split_times[1]
      out_split_time = split_times[2]
      out_split_time.stopped_here = true
      multi_lap = false
      validate_effort_data(effort, in_split_time, out_split_time, multi_lap)
    end

    it 'returns a hash containing effort and split_time data' do
      effort = test_effort
      allow(effort).to receive(:ordered_split_times).and_return(split_times)
      in_split_time = split_times[1]
      out_split_time = split_times[2]
      out_split_time.stopped_here = true
      multi_lap = true
      validate_effort_data(effort, in_split_time, out_split_time, multi_lap)
    end

    def validate_effort_data(effort, in_split_time, out_split_time, multi_lap)
      split_times = [in_split_time, out_split_time]
      in_split_name = multi_lap ? in_split_time.split_name_with_lap : in_split_time.split_name
      out_split_name = multi_lap ? out_split_time.split_name_with_lap : out_split_time.split_name
      split_times_data = [{split_name: in_split_name,
                           split_distance: in_split_time.split.distance_from_start,
                           day_and_time: in_split_time.day_and_time.strftime('%A, %B %-d, %Y %l:%M%p'),
                           elapsed_time: TimeConversion.seconds_to_hms(in_split_time.time_from_start.to_i),
                           pacer: nil,
                           stopped_here: in_split_time.stopped_here},
                          {split_name: out_split_name,
                           split_distance: out_split_time.split.distance_from_start,
                           day_and_time: out_split_time.day_and_time.strftime('%A, %B %-d, %Y %l:%M%p'),
                           elapsed_time: TimeConversion.seconds_to_hms(out_split_time.time_from_start.to_i),
                           pacer: nil,
                           stopped_here: out_split_time.stopped_here}]
      mail_data = LiveEffortMailData.new(person: person, split_times: split_times, multi_lap: multi_lap)
      expected = {full_name: effort.full_name,
                  event_name: event.name,
                  split_times_data: split_times_data,
                  effort_slug: effort.slug,
                  event_slug: event.slug}
      expect(mail_data.effort_data).to eq(expected)
    end
  end
end
