# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::GetTrace do
  describe ".call" do
    it "returns the full trace including spans" do
      trace = create(:request_trace, spans: [{ "type" => "sql", "duration_ms" => 12.5 }])
      result = described_class.call(id: trace.id)

      expect(result[:trace][:id]).to eq(trace.id)
      expect(result[:trace][:spans]).to eq([{ "type" => "sql", "duration_ms" => 12.5 }])
    end

    it "returns an error when the trace does not exist" do
      result = described_class.call(id: -1)
      expect(result[:error]).to match(/Couldn't find Faultline::RequestTrace/)
    end
  end
end
