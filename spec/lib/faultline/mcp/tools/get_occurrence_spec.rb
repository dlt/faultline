# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::GetOccurrence do
  describe ".call" do
    let(:occurrence) { create(:error_occurrence, :with_local_variables) }

    it "returns the full occurrence including backtrace and locals" do
      result = described_class.call(id: occurrence.id)
      payload = result[:occurrence]

      expect(payload[:id]).to eq(occurrence.id)
      expect(payload[:backtrace]).to be_an(Array)
      expect(payload[:local_variables]).to be_a(Hash)
      expect(payload[:local_variables]).to include("user")
    end

    it "parses request_params and request_headers as parsed JSON" do
      occ = create(:error_occurrence,
        request_params: '{"name":"John"}',
        request_headers: '{"HTTP_ACCEPT":"application/json"}')

      payload = described_class.call(id: occ.id)[:occurrence]
      expect(payload[:request_params]).to eq("name" => "John")
      expect(payload[:request_headers]).to eq("HTTP_ACCEPT" => "application/json")
    end

    it "returns an error when the occurrence does not exist" do
      result = described_class.call(id: -1)
      expect(result[:error]).to match(/Couldn't find Faultline::ErrorOccurrence/)
    end
  end
end
