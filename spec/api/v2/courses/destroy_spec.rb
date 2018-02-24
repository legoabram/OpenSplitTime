require 'rails_helper'

RSpec.describe "courses#destroy", type: :request do
  before { sign_in users(:alice), scope: :admin }

  subject(:make_request) do
    jsonapi_delete "/api/v2/courses/#{course.id}"
  end

  describe 'basic destroy' do
    let!(:course) { create(:course) }

    it 'updates the resource' do
      expect { make_request }.to change { Course.count }.by(-1)

      expect(response.status).to eq(200)
      expect(json).to eq('meta' => {})
    end
  end
end
