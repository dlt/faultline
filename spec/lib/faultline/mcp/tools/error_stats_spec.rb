# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::ErrorStats do
  describe ".call" do
    let(:group) { create(:error_group) }

    it "returns time-bucketed counts for the default 1d period" do
      create(:error_occurrence, error_group: group, created_at: 30.minutes.ago)
      create(:error_occurrence, error_group: group, created_at: 2.hours.ago)

      result = described_class.call({})

      expect(result[:period]).to eq("1d")
      expect(result[:granularity]).to eq("hour")
      expect(result[:total]).to eq(2)
      expect(result[:buckets]).to all(include(:bucket, :count))
    end

    it "falls back to the default period when given an unknown period" do
      result = described_class.call(period: "garbage")
      expect(result[:period]).to eq("1d")
    end

    it "honors a valid period" do
      result = described_class.call(period: "1w")
      expect(result[:period]).to eq("1w")
      expect(result[:granularity]).to eq("day")
    end
  end
end
