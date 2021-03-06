require 'rails_helper'

RSpec.describe Api::V1::SplitsController do
  login_admin

  let(:split) { create(:split, course: course) }
  let(:course) { create(:course) }

  describe '#show' do
    it 'returns a successful 200 response' do
      get :show, params: {id: split}
      expect(response.status).to eq(200)
    end

    it 'returns data of a single split' do
      get :show, params: {id: split}
      expect(response.body).to be_jsonapi_response_for('splits')
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['data']['id'].to_i).to eq(split.id)
    end

    it 'returns an error if the split does not exist' do
      get :show, params: {id: 0}
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['errors']).to include(/not found/)
      expect(response.status).to eq(404)
    end
  end

  describe '#create' do
    it 'returns a successful json response' do
      post :create, params: {data: {type: 'splits', attributes: {base_name: 'Test Split', course_id: course.id,
                                                       distance_from_start: 100,
                                                       kind: 'intermediate', sub_split_bitkey: 1} }}
      expect(response.body).to be_jsonapi_response_for('splits')
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['data']['id']).not_to be_nil
      expect(response.status).to eq(201)
    end

    it 'creates a split record' do
      expect(Split.all.count).to eq(0)
      post :create, params: {data: {type: 'splits', attributes: {base_name: 'Test Split', course_id: course.id,
                                                       distance_from_start: 100,
                                                       kind: 'intermediate', sub_split_bitkey: 1} }}
      expect(Split.all.count).to eq(1)
    end
  end

  describe '#update' do
    let(:attributes) { {base_name: 'Updated Split Name', latitude: 40, longitude: -105, elevation: 2000 } }

    it 'returns a successful json response' do
      put :update, params: {id: split, data: {type: 'splits', attributes: attributes }}
      expect(response.body).to be_jsonapi_response_for('splits')
      expect(response.status).to eq(200)
    end

    it 'updates the specified fields' do
      put :update, params: {id: split, data: {type: 'splits', attributes: attributes }}
      split.reload
      expect(split.base_name).to eq(attributes[:base_name])
    end

    it 'returns an error if the split does not exist' do
      put :update, params: {id: 0, data: {type: 'splits', attributes: attributes }}
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['errors']).to include(/not found/)
      expect(response.status).to eq(404)
    end
  end

  describe '#destroy' do
    it 'returns a successful json response' do
      delete :destroy, params: {id: split}
      expect(response.status).to eq(200)
    end

    it 'destroys the split record' do
      test_split = split
      expect(Split.all.count).to eq(1)
      delete :destroy, params: {id: test_split}
      expect(Split.all.count).to eq(0)
    end

    it 'returns an error message if any split_times are associated with the split' do
      event = create(:event, course: course)
      effort = create(:effort, event: event)
      create(:split_time, split: split, effort: effort)
      delete :destroy, params: {id: split}
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['errors'].first['detail']['messages']).to include(/Split has 1 associated split times/)
      expect(response.status).to eq(422)
    end

    it 'returns an error if the split does not exist' do
      delete :destroy, params: {id: 0}
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['errors']).to include(/not found/)
      expect(response.status).to eq(404)
    end
  end
end
