# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::ListTraces do
  describe ".call" do
    context "when APM is disabled" do
      before { allow(Faultline.configuration).to receive(:enable_apm).and_return(false) }

      it "returns an error" do
        result = described_class.call({})
        expect(result[:error]).to match(/APM is disabled/)
      end
    end

    context "when APM is enabled" do
      before { allow(Faultline.configuration).to receive(:enable_apm).and_return(true) }

      it "returns recent traces in newest-first order" do
        old = create(:request_trace, created_at: 2.hours.ago)
        new = create(:request_trace, created_at: 1.minute.ago)

        result = described_class.call({})
        ids = result[:traces].map { |t| t[:id] }
        expect(ids).to eq([new.id, old.id])
      end

      it "filters by endpoint" do
        match = create(:request_trace, endpoint: "Api::OrdersController#index")
        create(:request_trace, endpoint: "Api::UsersController#show")

        result = described_class.call(endpoint: "Api::OrdersController#index")
        ids = result[:traces].map { |t| t[:id] }
        expect(ids).to eq([match.id])
      end

      it "applies the slow_only threshold of 1000ms" do
        slow = create(:request_trace, duration_ms: 1500.0)
        create(:request_trace, duration_ms: 50.0)

        result = described_class.call(slow_only: true)
        ids = result[:traces].map { |t| t[:id] }
        expect(ids).to eq([slow.id])
        expect(result[:slow_threshold_ms]).to eq(1000)
      end

      it "respects the since filter (default 24h)" do
        old = create(:request_trace, created_at: 2.days.ago)
        new = create(:request_trace, created_at: 1.hour.ago)

        result = described_class.call({})
        ids = result[:traces].map { |t| t[:id] }

        expect(ids).to include(new.id)
        expect(ids).not_to include(old.id)
      end
    end
  end
end
