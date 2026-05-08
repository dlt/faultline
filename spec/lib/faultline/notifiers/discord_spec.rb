# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Notifiers::Discord do
  let(:webhook_url) { "https://discord.com/api/webhooks/123/abc" }
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

    it "defaults avatar_url to nil" do
      expect(notifier.instance_variable_get(:@avatar_url)).to be_nil
    end

    it "defaults mention to nil" do
      expect(notifier.instance_variable_get(:@mention)).to be_nil
    end

    it "allows custom avatar_url" do
      n = described_class.new(webhook_url: webhook_url, avatar_url: "https://example.com/a.png")
      expect(n.instance_variable_get(:@avatar_url)).to eq("https://example.com/a.png")
    end

    it "allows custom mention" do
      n = described_class.new(webhook_url: webhook_url, mention: "<@&123>")
      expect(n.instance_variable_get(:@mention)).to eq("<@&123>")
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
        expect(Rails.logger).to receive(:error).with(/\[Faultline::Discord\] Webhook error/)
        notifier.call(error_group, occurrence)
      end
    end

    context "when exception raised" do
      before do
        allow(http_double).to receive(:request).and_raise(StandardError.new("Connection failed"))
      end

      it "logs error" do
        expect(Rails.logger).to receive(:error).with(/\[Faultline::Discord\] Failed to send/)
        notifier.call(error_group, occurrence)
      end
    end
  end

  describe "payload formatting" do
    let(:payload) { notifier.send(:format_discord_payload, error_group, occurrence) }

    it "includes username" do
      expect(payload[:username]).to eq("Faultline")
    end

    it "omits avatar_url when not configured" do
      expect(payload).not_to have_key(:avatar_url)
    end

    it "omits content when no mention configured" do
      expect(payload).not_to have_key(:content)
    end

    it "includes a single embed" do
      expect(payload[:embeds]).to be_an(Array)
      expect(payload[:embeds].length).to eq(1)
    end

    describe "embed" do
      let(:embed) { payload[:embeds].first }

      it "uses red color for first occurrence" do
        allow(error_group).to receive(:recently_reopened?).and_return(false)
        allow(error_group).to receive(:occurrences_count).and_return(1)
        expect(embed[:color]).to eq(0xE74C3C)
      end

      it "uses orange color for repeated occurrences" do
        allow(error_group).to receive(:recently_reopened?).and_return(false)
        allow(error_group).to receive(:occurrences_count).and_return(5)
        expect(embed[:color]).to eq(0xE67E22)
      end

      it "uses yellow color when reopened" do
        allow(error_group).to receive(:recently_reopened?).and_return(true)
        expect(embed[:color]).to eq(0xF1C40F)
      end

      it "includes title with message" do
        expect(embed[:title]).to be_present
      end

      it "includes exception field" do
        exception_field = embed[:fields].find { |f| f[:name] == "Exception" }
        expect(exception_field[:value]).to eq(error_group.exception_class)
        expect(exception_field[:inline]).to be(true)
      end

      it "includes occurrences field" do
        occurrences_field = embed[:fields].find { |f| f[:name] == "Occurrences" }
        expect(occurrences_field[:value]).to eq(error_group.occurrences_count.to_s)
      end

      it "includes location field" do
        location_field = embed[:fields].find { |f| f[:name] == "Location" }
        expect(location_field[:value]).to include(error_group.file_path)
      end

      it "includes footer with app name title" do
        expect(embed[:footer][:text]).to include("Error in")
      end

      it "includes ISO8601 timestamp" do
        expect(embed[:timestamp]).to eq(occurrence.created_at.iso8601)
      end

      it "includes description when reopened" do
        allow(error_group).to receive(:recently_reopened?).and_return(true)
        expect(embed[:description]).to include("previously resolved")
      end

      it "omits description when not reopened" do
        allow(error_group).to receive(:recently_reopened?).and_return(false)
        expect(embed).not_to have_key(:description)
      end
    end

    context "with avatar_url" do
      let(:notifier) { described_class.new(webhook_url: webhook_url, avatar_url: "https://example.com/a.png") }

      it "includes avatar_url in payload" do
        expect(payload[:avatar_url]).to eq("https://example.com/a.png")
      end
    end

    context "with mention" do
      let(:notifier) { described_class.new(webhook_url: webhook_url, mention: "<@&123>") }

      it "sets content to the mention string" do
        expect(payload[:content]).to eq("<@&123>")
      end
    end

    context "with user identifier" do
      before do
        allow(occurrence).to receive(:user_identifier).and_return("john@example.com")
      end

      it "includes user field" do
        user_field = payload[:embeds].first[:fields].find { |f| f[:name] == "User" }
        expect(user_field[:value]).to eq("john@example.com")
      end
    end

    context "with request URL" do
      before do
        allow(occurrence).to receive(:request_url).and_return("https://example.com/widgets/" + ("x" * 200))
        allow(occurrence).to receive(:request_method).and_return("GET")
      end

      it "includes URL field truncated to 80 chars with method prefix, non-inline" do
        url_field = payload[:embeds].first[:fields].find { |f| f[:name] == "URL" }
        expect(url_field[:value]).to start_with("GET ")
        expect(url_field[:value].length).to be <= ("GET ".length + 80)
        expect(url_field[:inline]).to be(false)
      end
    end
  end
end
