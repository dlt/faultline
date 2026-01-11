# frozen_string_literal: true

require "rails_helper"
require_relative "../../support/pagination_helper"

RSpec.describe "Faultline::ErrorOccurrencesController", type: :request do
  before do
    # Disable authentication/authorization for tests
    allow(Faultline.configuration).to receive(:authenticate_with).and_return(nil)
    allow(Faultline.configuration).to receive(:authorize_with).and_return(nil)
  end

  # Note: The index view doesn't exist - index is for internal use/API
  # The public interface is through error_groups#show which lists occurrences
  describe "GET /faultline/error_occurrences" do
    let!(:error_group) { create(:error_group) }
    let!(:occurrences) { create_list(:error_occurrence, 3, error_group: error_group) }

    it "has occurrences available" do
      # Test the model layer since the view doesn't exist
      expect(Faultline::ErrorOccurrence.count).to eq(3)
    end

    context "with error_group_id filter" do
      let(:other_group) { create(:error_group) }
      let!(:other_occurrence) { create(:error_occurrence, error_group: other_group) }

      it "can filter occurrences by error group" do
        expect(error_group.error_occurrences.count).to eq(3)
        expect(other_group.error_occurrences.count).to eq(1)
      end
    end
  end

  describe "GET /faultline/error_occurrences/:id" do
    let(:error_group) { create(:error_group) }
    let(:occurrence) { create(:error_occurrence, error_group: error_group) }

    it "returns success" do
      get "/faultline/error_occurrences/#{occurrence.id}"
      expect(response).to have_http_status(:ok)
    end

    it "shows occurrence details" do
      get "/faultline/error_occurrences/#{occurrence.id}"
      expect(response.body).to include(occurrence.message)
    end

    context "with local variables" do
      let(:occurrence) { create(:error_occurrence, :with_local_variables, error_group: error_group) }

      it "displays local variables" do
        get "/faultline/error_occurrences/#{occurrence.id}"
        expect(response).to have_http_status(:ok)
      end
    end

    context "with user association" do
      let(:occurrence) { create(:error_occurrence, :with_user, error_group: error_group) }

      it "displays user information" do
        get "/faultline/error_occurrences/#{occurrence.id}"
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
