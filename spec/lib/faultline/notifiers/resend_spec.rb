# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Notifiers::Resend do
  let(:api_key) { "re_xxx" }
  let(:to) { "admin@example.com" }
  let(:from) { "errors@example.com" }
  let(:notifier) { described_class.new(api_key: api_key, to: to, from: from) }
  let(:error_group) { create(:error_group) }
  let(:occurrence) { create(:error_occurrence, error_group: error_group) }

  describe "#initialize" do
    it "sets api_key" do
      expect(notifier.instance_variable_get(:@api_key)).to eq(api_key)
    end

    it "sets from" do
      expect(notifier.instance_variable_get(:@from)).to eq(from)
    end

    it "converts to to array" do
      expect(notifier.instance_variable_get(:@to)).to eq([to])
    end

    it "accepts array of recipients" do
      notifier = described_class.new(api_key: api_key, to: ["a@example.com", "b@example.com"], from: from)
      expect(notifier.instance_variable_get(:@to)).to eq(["a@example.com", "b@example.com"])
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

    it "sends request to Resend API" do
      expect(http_double).to receive(:request) do |request|
        expect(request["Authorization"]).to eq("Bearer #{api_key}")
        expect(request["Content-Type"]).to eq("application/json")
        response_double
      end
      notifier.call(error_group, occurrence)
    end

    it "returns response" do
      result = notifier.call(error_group, occurrence)
      expect(result).to eq(response_double)
    end

    context "when request fails" do
      let(:response_double) { instance_double(Net::HTTPBadRequest, is_a?: false, code: "400", body: "error") }

      it "logs error" do
        expect(Rails.logger).to receive(:error).with(/Resend API error/)
        notifier.call(error_group, occurrence)
      end
    end
  end

  describe "payload formatting" do
    let(:payload) { notifier.send(:build_payload, error_group, occurrence) }

    it "includes from" do
      expect(payload[:from]).to eq(from)
    end

    it "includes to as array" do
      expect(payload[:to]).to eq([to])
    end

    it "includes subject" do
      expect(payload[:subject]).to be_present
    end

    it "includes html body" do
      expect(payload[:html]).to be_present
    end
  end

  describe "#build_subject" do
    context "for new errors" do
      it "includes [ERROR] prefix" do
        subject = notifier.send(:build_subject, error_group)
        expect(subject).to start_with("[ERROR]")
      end

      it "includes exception class" do
        subject = notifier.send(:build_subject, error_group)
        expect(subject).to include(error_group.exception_class)
      end
    end

    context "for reopened errors" do
      before { allow(error_group).to receive(:recently_reopened?).and_return(true) }

      it "includes [REOPENED] prefix" do
        subject = notifier.send(:build_subject, error_group)
        expect(subject).to start_with("[REOPENED]")
      end
    end
  end

  describe "#build_html" do
    let(:html) { notifier.send(:build_html, error_group, occurrence) }

    it "includes DOCTYPE" do
      expect(html).to include("<!DOCTYPE html>")
    end

    it "includes exception class" do
      expect(html).to include(error_group.exception_class)
    end

    it "includes error message" do
      expect(html).to include(error_group.sanitized_message)
    end

    it "includes occurrences count" do
      expect(html).to include(error_group.occurrences_count.to_s)
    end

    it "includes location" do
      expect(html).to include(error_group.file_path)
      expect(html).to include(error_group.line_number.to_s)
    end

    context "when reopened" do
      before { allow(error_group).to receive(:recently_reopened?).and_return(true) }

      it "includes REOPENED badge" do
        expect(html).to include("REOPENED")
      end

      it "uses orange header color" do
        expect(html).to include("#d97706")
      end
    end

    context "with user identifier" do
      before { allow(occurrence).to receive(:user_identifier).and_return("john@example.com") }

      it "includes user row" do
        expect(html).to include("john@example.com")
      end
    end

    context "with request URL" do
      it "includes request row" do
        expect(html).to include(occurrence.request_method)
        expect(html).to include(occurrence.request_url.truncate(60))
      end
    end
  end

  describe "#escape_html" do
    it "escapes ampersand" do
      expect(notifier.send(:escape_html, "foo & bar")).to eq("foo &amp; bar")
    end

    it "escapes less than" do
      expect(notifier.send(:escape_html, "foo < bar")).to eq("foo &lt; bar")
    end

    it "escapes greater than" do
      expect(notifier.send(:escape_html, "foo > bar")).to eq("foo &gt; bar")
    end

    it "escapes quotes" do
      expect(notifier.send(:escape_html, 'foo "bar"')).to eq("foo &quot;bar&quot;")
    end

    it "handles nil" do
      expect(notifier.send(:escape_html, nil)).to eq("")
    end
  end
end
