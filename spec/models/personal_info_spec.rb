require 'rails_helper'

RSpec.describe PersonalInfo, type: :module do

  describe '#state_and_country' do
    it 'returns the state and country of the subject resource' do
      effort = build_stubbed(:effort, country_code: 'CA', state_code: 'BC')
      expect(effort.state_and_country).to eq('British Columbia, Canada')
    end

    it 'abbreviates "United States" to "US"' do
      effort = build_stubbed(:effort, country_code: 'US', state_code: 'CO')
      expect(effort.state_and_country).to eq('Colorado, US')
    end

    it 'works even if the state is not recognized in Carmen' do
      effort = build_stubbed(:effort, country_code: 'GB', state_code: 'London')
      expect(effort.state_and_country).to eq('London, United Kingdom')
    end

    it 'returns the state_code if the country is not present' do
      effort = build_stubbed(:effort, country_code: nil, state_code: 'Atlantis')
      expect(effort.state_and_country).to eq('Atlantis')
    end

    it 'works properly when the country has no subregions' do
      effort = build_stubbed(:effort, country_code: 'HK', state_code: 'Hong Kong')
      expect(effort.state_and_country).to eq('Hong Kong, Hong Kong')
    end
  end

  describe '#flexible_geolocation' do
    context 'when the object includes a city, state, and country code of "US" or "CA"' do
      let(:effort_1) { build_stubbed(:effort, city: 'Louisville', state_code: 'CO', country_code: 'US') }
      let(:effort_2) { build_stubbed(:effort, city: 'Calgary', state_code: 'AB', country_code: 'CA') }

      it 'returns the city with the state code' do
        expect(effort_1.flexible_geolocation).to eq('Louisville, CO')
        expect(effort_2.flexible_geolocation).to eq('Calgary, AB')
      end
    end

    context 'when the object includes a city, state, and country code outside of the US or Canada' do
      let(:effort) { build_stubbed(:effort, city: 'Manzanillo', state_code: 'Colima', country_code: 'MX') }

      it 'returns the city, state code, and country' do
        expect(effort.flexible_geolocation).to eq('Manzanillo, Colima, Mexico')
      end
    end

    context 'when the object includes a state and country code of "US" or "CA" but no city' do
      let(:effort_1) { build_stubbed(:effort, city: nil, state_code: 'CO', country_code: 'US') }
      let(:effort_2) { build_stubbed(:effort, city: nil, state_code: 'AB', country_code: 'CA') }

      it 'returns the full state name without country code' do
        expect(effort_1.flexible_geolocation).to eq('Colorado')
        expect(effort_2.flexible_geolocation).to eq('Alberta')
      end
    end

    context 'when the object includes a state and country code other than "US" or "CA" but no city' do
      let(:effort) { build_stubbed(:effort, city: nil, state_code: 'Colima', country_code: 'MX') }

      it 'returns the state code and full country name' do
        expect(effort.flexible_geolocation).to eq('Colima, Mexico')
      end
    end

    context 'when the object includes a city and a country code but no state' do
      let(:effort_1) { build_stubbed(:effort, city: 'New York', state_code: nil, country_code: 'US') }
      let(:effort_2) { build_stubbed(:effort, city: 'Manzanillo', state_code: nil, country_code: 'MX') }

      it 'returns the city and full country name' do
        expect(effort_1.flexible_geolocation).to eq('New York, United States')
        expect(effort_2.flexible_geolocation).to eq('Manzanillo, Mexico')
      end
    end

    context 'when the object includes a country code but no city or state' do
      let(:effort_1) { build_stubbed(:effort, city: nil, state_code: nil, country_code: 'US') }
      let(:effort_2) { build_stubbed(:effort, city: nil, state_code: nil, country_code: 'MX') }

      it 'returns the full country name' do
        expect(effort_1.flexible_geolocation).to eq('United States')
        expect(effort_2.flexible_geolocation).to eq('Mexico')
      end
    end

    context 'when the object includes a city and state, but no country' do
      let(:effort_1) { build_stubbed(:effort, city: 'Louisville', state_code: 'CO', country_code: nil) }
      let(:effort_2) { build_stubbed(:effort, city: 'Calgary', state_code: 'AB', country_code: nil) }

      it 'returns the city with the state code' do
        expect(effort_1.flexible_geolocation).to eq('Louisville, CO')
        expect(effort_2.flexible_geolocation).to eq('Calgary, AB')
      end
    end
  end
end
