# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Notifiers::Webhook do
  let(:url) { "https://example.com/webhook" }
  let(:notifier) { described_class.new(url: url) }
  let(:error_group) { create(:error_group) }
  let(:occurrence) { create(:error_occurrence, error_group: error_group) }

  describe "#initialize" do
    it "sets url" do
      expect(notifier.instance_variable_get(:@url)).to eq(url)
    end

    it "defaults to POST method" do
      expect(notifier.instance_variable_get(:@method)).to eq(:post)
    end

    it "allows PUT method" do
      notifier = described_class.new(url: url, method: :put)
      expect(notifier.instance_variable_get(:@method)).to eq(:put)
    end

    it "accepts custom headers" do
      headers = { "X-Custom-Header" => "value" }
      notifier = described_class.new(url: url, headers: headers)
      expect(notifier.instance_variable_get(:@headers)).to eq(headers)
    end
  end

  describe "#call" do
    let(:http_double) { instance_double(Net::HTTP) }
    let(:response_double) { instance_double(Net::HTTPSuccess, is_a?: true) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http_double)
      allow(http_double).to receive(:use_ssl=)
      allow(http_double).to receive(:open_timeout=)
      allow(http_double).to receive(:read_timeout=)
      allow(http_double).to receive(:request).and_return(response_double)
    end

    it "sends POST request by default" do
      expect(http_double).to receive(:request) do |request|
        expect(request).to be_a(Net::HTTP::Post)
        response_double
      end
      notifier.call(error_group, occurrence)
    end

    context "with PUT method" do
      let(:notifier) { described_class.new(url: url, method: :put) }

      it "sends PUT request" do
        expect(http_double).to receive(:request) do |request|
          expect(request).to be_a(Net::HTTP::Put)
          response_double
        end
        notifier.call(error_group, occurrence)
      end
    end

    context "with custom headers" do
      let(:notifier) { described_class.new(url: url, headers: { "X-API-Key" => "secret" }) }

      it "includes custom headers" do
        expect(http_double).to receive(:request) do |request|
          expect(request["X-API-Key"]).to eq("secret")
          response_double
        end
        notifier.call(error_group, occurrence)
      end
    end

    context "when request fails" do
      let(:response_double) { instance_double(Net::HTTPBadRequest, is_a?: false, code: "400", body: "error") }

      it "logs error" do
        expect(Rails.logger).to receive(:error).with(/Request failed/)
        notifier.call(error_group, occurrence)
      end
    end

    context "when exception raised" do
      before do
        allow(http_double).to receive(:request).and_raise(StandardError.new("Connection failed"))
      end

      it "logs error" do
        expect(Rails.logger).to receive(:error).with(/Failed to send/)
        notifier.call(error_group, occurrence)
      end
    end

    context "with unsupported method" do
      let(:notifier) { described_class.new(url: url, method: :delete) }

      it "logs error for unsupported method" do
        # The ArgumentError is caught by the rescue block in send_request
        expect(Rails.logger).to receive(:error).with(/Failed to send/)
        notifier.call(error_group, occurrence)
      end
    end
  end

  describe "payload formatting" do
    let(:payload) { notifier.send(:format_webhook_payload, error_group, occurrence) }

    it "includes event type" do
      expect(payload[:event]).to eq("error.occurred")
    end

    it "includes timestamp" do
      expect(payload[:timestamp]).to be_present
    end

    it "includes app name" do
      expect(payload[:app]).to be_present
    end

    it "includes environment" do
      expect(payload[:environment]).to eq(Rails.env)
    end

    describe "error_group data" do
      let(:group_data) { payload[:error_group] }

      it "includes id" do
        expect(group_data[:id]).to eq(error_group.id)
      end

      it "includes fingerprint" do
        expect(group_data[:fingerprint]).to eq(error_group.fingerprint)
      end

      it "includes exception_class" do
        expect(group_data[:exception_class]).to eq(error_group.exception_class)
      end

      it "includes message" do
        expect(group_data[:message]).to eq(error_group.sanitized_message)
      end

      it "includes status" do
        expect(group_data[:status]).to eq(error_group.status)
      end

      it "includes occurrences_count" do
        expect(group_data[:occurrences_count]).to eq(error_group.occurrences_count)
      end

      it "includes file_path" do
        expect(group_data[:file_path]).to eq(error_group.file_path)
      end

      it "includes line_number" do
        expect(group_data[:line_number]).to eq(error_group.line_number)
      end

      it "includes recently_reopened" do
        expect(group_data[:recently_reopened]).to be false
      end
    end

    describe "occurrence data" do
      let(:occurrence_data) { payload[:occurrence] }

      it "includes id" do
        expect(occurrence_data[:id]).to eq(occurrence.id)
      end

      it "includes message" do
        expect(occurrence_data[:message]).to eq(occurrence.message)
      end

      it "includes request_url" do
        expect(occurrence_data[:request_url]).to eq(occurrence.request_url)
      end

      it "includes request_method" do
        expect(occurrence_data[:request_method]).to eq(occurrence.request_method)
      end

      it "includes ip_address" do
        expect(occurrence_data[:ip_address]).to eq(occurrence.ip_address)
      end
    end
  end
end
