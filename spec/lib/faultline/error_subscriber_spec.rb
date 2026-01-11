# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::ErrorSubscriber do
  let(:subscriber) { described_class.new }

  describe "#report" do
    let(:error) { StandardError.new("Test error") }
    let(:context) { { custom: "data" } }

    before do
      allow(Faultline).to receive(:track)
      allow(Faultline.configuration).to receive(:ignored_exceptions).and_return([])
    end

    it "tracks the error" do
      expect(Faultline).to receive(:track).with(error, hash_including(:handled, :severity, :source, :custom_data))
      subscriber.report(error, handled: true, severity: :error, context: context)
    end

    it "passes handled parameter" do
      expect(Faultline).to receive(:track).with(error, hash_including(handled: true))
      subscriber.report(error, handled: true, severity: :error, context: context)
    end

    it "passes severity parameter" do
      expect(Faultline).to receive(:track).with(error, hash_including(severity: :error))
      subscriber.report(error, handled: true, severity: :error, context: context)
    end

    it "passes source parameter" do
      expect(Faultline).to receive(:track).with(error, hash_including(source: "application"))
      subscriber.report(error, handled: true, severity: :error, context: context, source: "application")
    end

    it "passes context as custom_data" do
      expect(Faultline).to receive(:track).with(error, hash_including(custom_data: context))
      subscriber.report(error, handled: true, severity: :error, context: context)
    end

    context "when error is ignored" do
      before do
        allow(Faultline.configuration).to receive(:ignored_exceptions).and_return(["StandardError"])
      end

      it "does not track the error" do
        expect(Faultline).not_to receive(:track)
        subscriber.report(error, handled: true, severity: :error, context: context)
      end
    end
  end

  describe "#should_ignore?" do
    context "with ignored exception" do
      before do
        allow(Faultline.configuration).to receive(:ignored_exceptions).and_return(["StandardError"])
      end

      it "returns true" do
        error = StandardError.new
        expect(subscriber.send(:should_ignore?, error)).to be true
      end
    end

    context "with non-ignored exception" do
      before do
        allow(Faultline.configuration).to receive(:ignored_exceptions).and_return(["RuntimeError"])
      end

      it "returns false" do
        error = StandardError.new
        expect(subscriber.send(:should_ignore?, error)).to be false
      end
    end
  end
end
