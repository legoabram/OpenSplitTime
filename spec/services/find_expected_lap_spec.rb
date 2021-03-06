require 'rails_helper'

RSpec.describe FindExpectedLap do
  subject { FindExpectedLap.new(effort: effort, military_time: military_time, split_id: split_id, bitkey: bitkey) }
  let(:effort) { build_stubbed(:effort, split_times: split_times, event: event) }
  let(:split_id) { split.id }
  let(:bitkey) { in_bitkey }

  let(:event) { build_stubbed(:event, laps_required: 0, splits: splits, start_time_in_home_zone: '06:00:00') }
  let(:splits) { [split_1, split_2, split_3, split_4] }
  let(:split_1) { build_stubbed(:start_split, base_name: 'Start') }
  let(:split_2) { build_stubbed(:split, base_name: 'Aid 1') }
  let(:split_3) { build_stubbed(:split, base_name: 'Aid 2') }
  let(:split_4) { build_stubbed(:finish_split, base_name: 'Finish') }

  let(:in_bitkey) { SubSplit::IN_BITKEY }
  let(:out_bitkey) { SubSplit::OUT_BITKEY }

  let(:split_time_1) { build_stubbed(:split_time, lap: 1, split: split_1, bitkey: 1, time_from_start: 0) }
  let(:split_time_2) { build_stubbed(:split_time, lap: 1, split: split_2, bitkey: 1, time_from_start: 1.hour) }
  let(:split_time_3) { build_stubbed(:split_time, lap: 1, split: split_2, bitkey: 64, time_from_start: 2.hours) }
  let(:split_time_4) { build_stubbed(:split_time, lap: 1, split: split_3, bitkey: 1, time_from_start: 3.hours) }
  let(:split_time_5) { build_stubbed(:split_time, lap: 1, split: split_3, bitkey: 64, time_from_start: 4.hours) }
  let(:split_time_6) { build_stubbed(:split_time, lap: 1, split: split_4, bitkey: 1, time_from_start: 5.hours) }
  let(:split_time_7) { build_stubbed(:split_time, lap: 2, split: split_1, bitkey: 1, time_from_start: 6.hours) }
  let(:split_time_8) { build_stubbed(:split_time, lap: 2, split: split_2, bitkey: 1, time_from_start: 7.hours) }
  let(:split_time_9) { build_stubbed(:split_time, lap: 2, split: split_2, bitkey: 64, time_from_start: 8.hours) }
  let(:split_time_10) { build_stubbed(:split_time, lap: 2, split: split_3, bitkey: 1, time_from_start: 9.hours) }
  let(:split_time_11) { build_stubbed(:split_time, lap: 2, split: split_3, bitkey: 64, time_from_start: 10.hours) }
  let(:split_time_12) { build_stubbed(:split_time, lap: 2, split: split_4, bitkey: 1, time_from_start: 11.hours) }
  let(:all_split_times) { [split_time_1, split_time_2, split_time_3, split_time_4, split_time_5, split_time_6,
                           split_time_7, split_time_8, split_time_9, split_time_10, split_time_11, split_time_12,] }

  describe '#initialize' do
    let(:split_times) { [] }
    let(:military_time) { '07:00:00' }
    let(:split) { split_1 }

    it 'initializes with effort, military_time, split_id, and bitkey in an args hash' do
      expect { subject }.not_to raise_error
    end

    context 'if no effort is given' do
      let(:effort) { nil }

      it 'raises an ArgumentError' do
        expect { subject }.to raise_error(/must include effort/)
      end
    end

    context 'if no military_time is given' do
      let(:military_time) { nil }

      it 'raises an ArgumentError' do
        expect { subject }.to raise_error(/must include military_time/)
      end
    end

    context 'if no split_id is given' do
      let(:split_id) { nil }

      it 'raises an ArgumentError' do
        expect { subject }.to raise_error(/must include split_id/)
      end
    end

    context 'if no bitkey is given' do
      let(:bitkey) { nil }

      it 'raises an ArgumentError' do
        expect { subject }.to raise_error(/must include bitkey/)
      end
    end
  end

  describe '#perform' do
    before do
      FactoryBot.reload
      all_split_times.each { |st| st.assign_attributes(effort_id: effort.id) }
    end

    context 'when effort has no split_times' do
      let(:split_times) { [] }
      let(:military_time) { '07:00:00' }
      let(:split) { split_1 }

      it 'returns 1' do
        expect(subject.perform).to eq(1)
      end
    end

    context 'when split_times are present but none exist for the specified split' do
      let(:split) { split_3 }
      let(:military_time) { '07:00:00' }
      let(:split_times) { all_split_times.first(3) } # Start and Aid 1 (in/out)

      it 'returns 1' do
        expect(subject.perform).to eq(1)
      end
    end

    context 'when split_times exist on lap 1 for the specified split' do
      let(:split) { split_3 }
      let(:military_time) { '07:00:00' }
      let(:split_times) { all_split_times.first(5) } # Start, Aid 1 (in/out), Aid 2 (in/out)

      it 'returns 2' do
        expect(subject.perform).to eq(2)
      end
    end

    context 'when split_times exist on lap 2 but not on lap 1 for the specified split and time fills the hole' do
      let(:split) { split_3 }
      let(:military_time) { '09:15:00' }
      let(:split_times) { all_split_times[0..2] + all_split_times[4..-1] } # Two complete laps except Aid 2 in

      it 'returns 1' do
        expect(subject.perform).to eq(1)
      end
    end

    context 'when split_times exist on lap 2 but not on lap 1 for the specified split and time does not fill the hole' do
      let(:split) { split_3 }
      let(:military_time) { '10:15:00' }
      let(:split_times) { all_split_times[0..2] + all_split_times[4..-1] } # Two complete laps except Aid 2 in

      it 'returns 1' do
        expect(subject.perform).to eq(3)
      end
    end
  end
end
