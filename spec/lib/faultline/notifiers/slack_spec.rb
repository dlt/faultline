# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Notifiers::Slack do
  let(:webhook_url) { "https://hooks.slack.com/services/XXX/YYY/ZZZ" }
  let(:notifier) { described_class.new(webhook_url: webhook_url) }
  let(:error_group) { create(:error_group) }
  let(:occurrence) { create(:error_occurrence, error_group: error_group) }

  describe "#initialize" do
    it "sets webhook_url" do
      expect(notifier.instance_variable_get(:@webhook_url)).to eq(webhook_url)
    end

    it "sets default username" do
      expect(notifier.instance_variable_get(:@username)).to eq("Faultline")
    end

    it "sets default icon_emoji" do
      expect(notifier.instance_variable_get(:@icon_emoji)).to eq(":rotating_light:")
    end

    it "allows custom channel" do
      notifier = described_class.new(webhook_url: webhook_url, channel: "#errors")
      expect(notifier.instance_variable_get(:@channel)).to eq("#errors")
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

    it "sends webhook request" do
      expect(http_double).to receive(:request).and_return(response_double)
      notifier.call(error_group, occurrence)
    end

    context "when request fails" do
      let(:response_double) { instance_double(Net::HTTPBadRequest, is_a?: false, code: "400", body: "error") }

      it "logs error" do
        expect(Rails.logger).to receive(:error).with(/Webhook error/)
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
  end

  describe "payload formatting" do
    let(:payload) { notifier.send(:format_slack_payload, error_group, occurrence) }

    it "includes username" do
      expect(payload[:username]).to eq("Faultline")
    end

    it "includes icon_emoji" do
      expect(payload[:icon_emoji]).to eq(":rotating_light:")
    end

    it "includes attachments" do
      expect(payload[:attachments]).to be_an(Array)
      expect(payload[:attachments].length).to eq(1)
    end

    describe "attachment" do
      let(:attachment) { payload[:attachments].first }

      it "has danger color by default" do
        expect(attachment[:color]).to eq("danger")
      end

      it "has warning color when reopened" do
        allow(error_group).to receive(:recently_reopened?).and_return(true)
        expect(attachment[:color]).to eq("warning")
      end

      it "includes title with message" do
        expect(attachment[:title]).to be_present
      end

      it "includes exception field" do
        exception_field = attachment[:fields].find { |f| f[:title] == "Exception" }
        expect(exception_field[:value]).to eq(error_group.exception_class)
      end

      it "includes occurrences field" do
        occurrences_field = attachment[:fields].find { |f| f[:title] == "Occurrences" }
        expect(occurrences_field[:value]).to eq(error_group.occurrences_count.to_s)
      end

      it "includes location field" do
        location_field = attachment[:fields].find { |f| f[:title] == "Location" }
        expect(location_field[:value]).to include(error_group.file_path)
      end

      it "includes pretext when reopened" do
        allow(error_group).to receive(:recently_reopened?).and_return(true)
        expect(attachment[:pretext]).to include("previously resolved")
      end
    end

    context "with channel specified" do
      let(:notifier) { described_class.new(webhook_url: webhook_url, channel: "#errors") }

      it "includes channel in payload" do
        expect(payload[:channel]).to eq("#errors")
      end
    end

    context "with user identifier" do
      before do
        allow(occurrence).to receive(:user_identifier).and_return("john@example.com")
      end

      it "includes user field" do
        user_field = payload[:attachments].first[:fields].find { |f| f[:title] == "User" }
        expect(user_field[:value]).to eq("john@example.com")
      end
    end
  end
end
