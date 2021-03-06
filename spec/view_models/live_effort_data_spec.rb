require 'rails_helper'

RSpec.describe LiveEffortData do
  before { FactoryBot.reload }

  let(:event) { build_stubbed(:event_functional, laps_required: 3, splits_count: 5, efforts_count: 1, start_time_in_home_zone: '2017-08-01 06:00:00') }
  let(:effort) { event.efforts.first }
  let(:times_container) { SegmentTimesContainer.new(calc_model: :terrain) }

  describe '#initialize' do
    let(:event) { build_stubbed(:event) }
    let(:params) { ActionController::Parameters.new(params_hash) }
    let(:params_hash) { {'split_id' => '2', 'lap' => '1', 'bib_number' => '124', 'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'} }

    it 'initializes with an event and params in an args hash' do
      expect { LiveEffortData.new(event: event, params: params) }.not_to raise_error
    end

    it 'raises an ArgumentError if no event is given' do
      expect { LiveEffortData.new(params: params) }.to raise_error(/must include event/)
    end

    it 'raises an ArgumentError if any parameter other than event, params, lap_splits, or times_container is given' do
      effort = Effort.new
      expect { LiveEffortData.new(event: event, params: params, ordered_splits: [], effort: effort,
                                  times_container: times_container, random_param: 123) }
          .to raise_error(/may not include random_param/)
    end
  end

  describe '#new_split_times' do
    context 'for an unstarted effort' do
      let(:split_times) { [] }
      it 'returns a hash of {in: SplitTime, out: SplitTime.null_record} when the lap_split contains only an in sub_split' do
        provided_split = event.splits[0]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {class: SplitTime, :null_record? => false},
                      out: {class: SplitTime, :null_record? => true}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'returns a hash of sub_split kinds and SplitTimes when the split contains multiple sub_splits' do
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {class: SplitTime, :null_record? => false},
                      out: {class: SplitTime, :null_record? => false}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates split_times with correct times from start' do
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {time_from_start: 150.minutes},
                      out: {time_from_start: 170.minutes}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end
    end

    context 'when effort is a null_record, as when a bib number is not provided or not located' do
      it 'returns split_times with nil times from start and nil data statuses' do
        effort = Effort.null_record
        split_times = []
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '', 'bib_number' => '',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {time_from_start: nil, data_status: nil},
                      out: {time_from_start: nil, data_status: nil}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end
    end

    context 'when split_times for the given effort and split do not yet exist in the database' do
      it 'returns a hash of {in: SplitTime, out: SplitTime.null_record} when the split contains only an in sub_split' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[0]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '', 'bib_number' => '',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {class: SplitTime, :null_record? => false},
                      out: {class: SplitTime, :null_record? => true}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'returns a hash of sub_split kinds and SplitTimes when the split contains multiple sub_splits' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '', 'bib_number' => '',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {class: SplitTime, :null_record? => false},
                      out: {class: SplitTime, :null_record? => false}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates split_times with correct times from start when both times are provided' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {time_from_start: 150.minutes},
                      out: {time_from_start: 170.minutes}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates split_times with correct times from start when only first time is provided' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '', 'id' => '4'}
        attributes = {in: {time_from_start: 150.minutes},
                      out: {time_from_start: nil}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates split_times with correct times from start when only second time is provided' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {time_from_start: nil},
                      out: {time_from_start: 170.minutes}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates split_times with nil times_from_start when neither time is provided' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '', 'time_out' => '', 'id' => '4'}
        attributes = {in: {time_from_start: nil},
                      out: {time_from_start: nil}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates data_status with correct data statuses when times are both good' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {data_status: 'good'},
                      out: {data_status: 'good'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates data_status with correct data statuses when times are both questionable' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '06:35:00', 'time_out' => '06:40:00', 'id' => '4'}
        attributes = {in: {data_status: 'questionable'},
                      out: {data_status: 'questionable'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates data_status with correct data statuses when times are both bad' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '06:25:00', 'time_out' => '06:30:00', 'id' => '4'}
        attributes = {in: {data_status: 'bad'},
                      out: {data_status: 'bad'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates data_status with correct data statuses when first time is good and second time is prior to first' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '08:20:00', 'id' => '4'}
        attributes = {in: {data_status: 'good'},
                      out: {data_status: 'bad'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'looks past "in" time to determine data status of "out" time when "in" time is bad' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '18:00:00', 'time_out' => '08:20:00', 'id' => '4'}
        attributes = {in: {data_status: 'bad'},
                      out: {data_status: 'good'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'works properly when first time is missing and second time is good' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '', 'time_out' => '08:20:00', 'id' => '4'}
        attributes = {in: {data_status: nil},
                      out: {data_status: 'good'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'works properly when first time is missing and second time is bad' do
        split_times = effort.split_times.first(1)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '', 'time_out' => '06:20:00', 'id' => '4'}
        attributes = {in: {data_status: nil},
                      out: {data_status: 'bad'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end
    end

    context 'when split_times for the given effort and split already exist in the database' do
      it 'populates split_times with correct times from start when both times are provided' do
        split_times = effort.split_times.first(3)
        provided_split = event.splits[1] # Relates to the second and third elements of split_times
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {time_from_start: 150.minutes},
                      out: {time_from_start: 170.minutes}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates data_status with correct data statuses when times are both good' do
        split_times = effort.split_times.first(3)
        provided_split = event.splits[1] # Relates to the second and third elements of split_times
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
        attributes = {in: {data_status: 'good'},
                      out: {data_status: 'good'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates data_status with correct data statuses when times are both bad' do
        split_times = effort.split_times.first(3)
        provided_split = event.splits[1] # Relates to the second and third elements of split_times
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '06:20:00', 'time_out' => '06:25:00', 'id' => '4'}
        attributes = {in: {data_status: 'bad'},
                      out: {data_status: 'bad'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'populates data_status with correct data statuses when first time is good and second time is prior to first' do
        split_times = effort.split_times.first(3)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '08:30:00', 'time_out' => '08:20:00', 'id' => '4'}
        attributes = {in: {data_status: 'good'},
                      out: {data_status: 'bad'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'looks past "in" time to determine data status of "out" time when "in" time is bad' do
        split_times = effort.split_times.first(3)
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '18:00:00', 'time_out' => '08:20:00', 'id' => '4'}
        attributes = {in: {data_status: 'bad'},
                      out: {data_status: 'good'}}
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'measures the "out" time against the existing "in" time in the database when "in" time is missing' do
        split_times = effort.split_times.first(3) # Existing in and out times are 07:40 and 07:50
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '', 'time_out' => '07:35:00', 'id' => '4'}
        attributes = {in: {data_status: nil},
                      out: {data_status: 'bad'}} # Because 07:35 < 07:40 although 1h35m is a reasonable time
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'again measures the "out" time against the existing "in" time in the database when "in" time is missing' do
        split_times = effort.split_times.first(3) # Existing in and out times are 07:40 and 07:50
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '', 'time_out' => '07:45:00', 'id' => '4'}
        attributes = {in: {data_status: nil},
                      out: {data_status: 'good'}} # Because 07:45 > 07:40 and 1h45m is a reasonable time
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end

      it 'works properly when first time is missing and second time is bad on its own merits' do
        split_times = effort.split_times.first(3) # Existing in and out times are 07:40 and 07:50
        provided_split = event.splits[1]
        params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                       'time_in' => '', 'time_out' => '06:20:00', 'id' => '4'}
        attributes = {in: {data_status: nil},
                      out: {data_status: 'bad'}} # Because 20m is not a reasonable time
        validate_new_split_times(event, effort, split_times, params_hash, attributes)
      end
    end

    it 'sets data_status to bad when the effort split_times have a stopped_here at an earlier point' do
      split_times = effort.split_times.first(5)
      provided_split = event.splits.fourth
      params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                     'time_in' => '11:30:00', 'time_out' => '11:50:00', 'id' => '4'}
      attributes = {in: {data_status: 'good'},
                    out: {data_status: 'good'}} # 5h30m and 5h50m are good times for the fourth split
      validate_new_split_times(event, effort, split_times, params_hash, attributes)

      split_times[2].stopped_here = true # But if effort has stopped at the third split
      attributes = {in: {data_status: 'bad'},
                    out: {data_status: 'bad'}} # They become bad times
      validate_new_split_times(event, effort, split_times, params_hash, attributes)
    end

    it 'sets time_exists depending on whether a split_time exists in the database for the provided split and effort' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                     'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
      attributes = {in: {time_exists: true}, out: {time_exists: true}}
      validate_new_split_times(event, effort, split_times, params_hash, attributes)
    end

    it 'sets time_exists properly when only the in split_time exists' do
      split_times = effort.split_times.first(2)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                     'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
      attributes = {in: {time_exists: true}, out: {time_exists: false}}
      validate_new_split_times(event, effort, split_times, params_hash, attributes)
    end

    it 'sets time_exists properly when only the out time exists' do
      split_times = effort.split_times[2..3]
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                     'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
      attributes = {in: {time_exists: false}, out: {time_exists: true}}
      validate_new_split_times(event, effort, split_times, params_hash, attributes)
    end

    it 'sets time_exists to nil for a sub_split kind that is not associated with the provided split' do
      split_times = effort.split_times.first(5)
      provided_split = event.splits[0]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                     'time_in' => '08:30:00', 'time_out' => '08:50:00', 'id' => '4'}
      attributes = {in: {time_exists: true}, out: {time_exists: nil}}
      validate_new_split_times(event, effort, split_times, params_hash, attributes)
    end

    it 'functions the same when times are not provided' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                     'time_in' => '', 'time_out' => '', 'id' => '4'}
      attributes = {in: {time_exists: true}, out: {time_exists: true}}
      validate_new_split_times(event, effort, split_times, params_hash, attributes)
    end

    it 'returns pacer_in and pacer_out values that reflect params provided as true or false boolean values' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                     'time_in' => '', 'time_out' => '', 'id' => '4', 'pacer_in' => true, 'pacer_out' => false}
      attributes = {in: {pacer: true}, out: {pacer: false}}
      validate_new_split_times(event, effort, split_times, params_hash, attributes)
    end

    it 'returns pacer_in and pacer_out values that reflect params provided as true or false string values' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                     'time_in' => '', 'time_out' => '', 'id' => '4', 'pacer_in' => 'true', 'pacer_out' => 'false'}
      attributes = {in: {pacer: true}, out: {pacer: false}}
      validate_new_split_times(event, effort, split_times, params_hash, attributes)
    end

    def validate_new_split_times(event, effort, split_times, params_hash, attributes)
      params = ActionController::Parameters.new(params_hash)
      ordered_splits = event.splits
      allow_any_instance_of(Event).to receive(:ordered_splits).and_return(ordered_splits)
      allow(effort).to receive(:ordered_split_times).and_return(split_times)
      effort_data = LiveEffortData.new(event: event,
                                       params: params,
                                       ordered_splits: ordered_splits,
                                       effort: effort,
                                       times_container: times_container)
      attributes.each do |in_out, pairs|
        pairs.each do |attribute, expected|
          expect(effort_data.new_split_times[in_out].send(attribute)).to eq(expected)
        end
      end
    end
  end

  describe '#lap' do
    it 'returns the expected lap if no lap is provided' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '', 'bib_number' => '205',
                     'time_in' => '', 'time_out' => '', 'id' => '4'}
      expected = 2
      validate_lap(event, effort, split_times, params_hash, expected)
    end

    it 'returns 1 if the provided lap is 0' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '0', 'bib_number' => '205',
                     'time_in' => '', 'time_out' => '', 'id' => '4'}
      expected = 1
      validate_lap(event, effort, split_times, params_hash, expected)
    end

    it 'returns 1 if the provided lap is negative' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '-1', 'bib_number' => '205',
                     'time_in' => '', 'time_out' => '', 'id' => '4'}
      expected = 1
      validate_lap(event, effort, split_times, params_hash, expected)
    end

    it 'returns 1 if the provided lap is 1' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '1', 'bib_number' => '205',
                     'time_in' => '', 'time_out' => '', 'id' => '4'}
      expected = 1
      validate_lap(event, effort, split_times, params_hash, expected)
    end

    it 'returns the provided lap if it is between 1 and event.laps_required' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '3', 'bib_number' => '205',
                     'time_in' => '', 'time_out' => '', 'id' => '4'}
      expected = 3
      validate_lap(event, effort, split_times, params_hash, expected)
    end

    it 'returns event.laps_required if the provided lap is greater than event.laps_required' do
      split_times = effort.split_times.first(3)
      provided_split = event.splits[1]
      params_hash = {'split_id' => provided_split.id.to_s, lap: '4', 'bib_number' => '205',
                     'time_in' => '', 'time_out' => '', 'id' => '4'}
      expected = 3
      validate_lap(event, effort, split_times, params_hash, expected)
    end

    def validate_lap(event, effort, split_times, params_hash, expected)
      params = ActionController::Parameters.new(params_hash)
      ordered_splits = event.splits
      allow_any_instance_of(Event).to receive(:ordered_splits).and_return(ordered_splits)
      allow_any_instance_of(Course).to receive(:ordered_splits).and_return(ordered_splits)
      allow(effort).to receive(:ordered_split_times).and_return(split_times)
      effort_data = LiveEffortData.new(event: event,
                                       params: params,
                                       ordered_splits: ordered_splits,
                                       effort: effort,
                                       times_container: times_container)
      expect(effort_data.lap).to eq(expected)
    end
  end
end
