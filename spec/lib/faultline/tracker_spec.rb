# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Tracker do
  before do
    Faultline.configure do |config|
      config.ignored_exceptions = ["IgnoredException"]
      config.notifiers = []
    end
  end

  describe ".track" do
    let(:exception) { StandardError.new("Test error") }

    it "creates an error group" do
      expect {
        described_class.track(exception)
      }.to change(Faultline::ErrorGroup, :count).by(1)
    end

    it "creates an error occurrence" do
      expect {
        described_class.track(exception)
      }.to change(Faultline::ErrorOccurrence, :count).by(1)
    end

    it "returns the occurrence" do
      result = described_class.track(exception)
      expect(result).to be_a(Faultline::ErrorOccurrence)
    end

    it "reuses existing error group for same fingerprint" do
      described_class.track(exception)

      expect {
        described_class.track(exception)
      }.not_to change(Faultline::ErrorGroup, :count)
    end

    it "ignores exceptions in ignored_exceptions list" do
      ignored = Class.new(StandardError)
      stub_const("IgnoredException", ignored)

      result = described_class.track(ignored.new("ignored"))
      expect(result).to be_nil
    end

    context "with request context" do
      let(:request) { double("request", method: "GET", original_url: "http://test.com", user_agent: "Test", remote_ip: "127.0.0.1", params: {}, session: nil, headers: {}) }

      it "captures request data" do
        occurrence = described_class.track(exception, request: request)
        expect(occurrence.request_method).to eq("GET")
        expect(occurrence.ip_address).to eq("127.0.0.1")
      end
    end

    context "with before_track callback" do
      it "skips tracking when callback returns false" do
        Faultline.configuration.before_track = ->(_e, _c) { false }

        result = described_class.track(exception)
        expect(result).to be_nil
      ensure
        Faultline.configuration.before_track = nil
      end
    end

    context "with after_track callback" do
      it "calls the callback after tracking" do
        called = false
        Faultline.configuration.after_track = ->(_g, _o) { called = true }

        described_class.track(exception)
        expect(called).to be true
      ensure
        Faultline.configuration.after_track = nil
      end
    end
  end
end
