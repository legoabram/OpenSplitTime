require 'rails_helper'

RSpec.describe Api::V1::SplitTimesController do
  login_admin

  let(:split_time) { create(:split_time, effort: effort, split: split) }
  let(:effort) { create(:effort, event: event) }
  let(:event) { create(:event, course: course) }
  let(:split) { create(:split, course: course) }
  let(:course) { create(:course) }

  describe '#show' do
    it 'returns a successful 200 response' do
      get :show, params: {id: split_time}
      expect(response.status).to eq(200)
    end

    it 'returns data of a single split_time' do
      get :show, params: {id: split_time}
      expect(response.body).to be_jsonapi_response_for('split_times')
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['data']['id'].to_i).to eq(split_time.id)
    end

    it 'returns an error if the split_time does not exist' do
      get :show, params: {id: 0}
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['errors']).to include(/not found/)
      expect(response.status).to eq(404)
    end
  end

  describe '#create' do
    it 'returns a successful json response' do
      post :create, params: {data: {type: 'split_times', attributes: {effort_id: effort.id, lap: 1, split_id: split.id,
                                                                      sub_split_bitkey: 1, time_from_start: 100}}}
      expect(response.body).to be_jsonapi_response_for('split_times')
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['data']['id']).not_to be_nil
      expect(response.status).to eq(201)
    end

    it 'creates a split_time record' do
      expect(SplitTime.all.count).to eq(0)
      post :create, params: {data: {type: 'split_times', attributes: {effort_id: effort.id, lap: 1, split_id: split.id,
                                                                      sub_split_bitkey: 1, time_from_start: 100}}}
      expect(SplitTime.all.count).to eq(1)
    end
  end

  describe '#update' do
    let(:attributes) { {time_from_start: 12345} }

    it 'returns a successful json response' do
      put :update, params: {id: split_time, data: {type: 'split_times', attributes: attributes}}
      expect(response.body).to be_jsonapi_response_for('split_times')
      expect(response.status).to eq(200)
    end

    it 'updates the specified fields' do
      put :update, params: {id: split_time, data: {type: 'split_times', attributes: attributes}}
      split_time.reload
      expect(split_time.time_from_start).to eq(attributes[:time_from_start])
    end

    it 'returns an error if the split_time does not exist' do
      put :update, params: {id: 0, data: {type: 'split_times', attributes: attributes}}
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['errors']).to include(/not found/)
      expect(response.status).to eq(404)
    end
  end

  describe '#destroy' do
    it 'returns a successful json response' do
      delete :destroy, params: {id: split_time}
      expect(response.status).to eq(200)
    end

    it 'destroys the split_time record' do
      test_split_time = split_time
      expect(SplitTime.all.count).to eq(1)
      delete :destroy, params: {id: test_split_time}
      expect(SplitTime.all.count).to eq(0)
    end

    it 'returns an error if the split_time does not exist' do
      delete :destroy, params: {id: 0}
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['errors']).to include(/not found/)
      expect(response.status).to eq(404)
    end
  end
end
