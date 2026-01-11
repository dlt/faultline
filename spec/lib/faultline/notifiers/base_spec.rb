# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Notifiers::Base do
  let(:error_group) { create(:error_group, occurrences_count: 5) }
  let(:occurrence) { build(:error_occurrence, error_group: error_group) }
  let(:notifier) { described_class.new }

  before do
    # Prevent counter_cache from incrementing occurrences_count
    occurrence.save(validate: false)
    error_group.update_column(:occurrences_count, 5)
  end

  describe "#initialize" do
    it "accepts options" do
      notifier = described_class.new(key: "value")
      expect(notifier.options).to eq({ key: "value" })
    end
  end

  describe "#call" do
    it "raises NotImplementedError" do
      expect { notifier.call(error_group, occurrence) }.to raise_error(NotImplementedError)
    end
  end

  describe "#should_notify?" do
    it "returns true by default" do
      expect(notifier.should_notify?(error_group, occurrence)).to be true
    end
  end

  describe "#format_message" do
    let(:message) { notifier.send(:format_message, error_group, occurrence) }

    it "includes title with app name" do
      expect(message[:title]).to include("Error in")
    end

    it "includes exception class" do
      expect(message[:exception_class]).to eq(error_group.exception_class)
    end

    it "includes truncated message" do
      expect(message[:message]).to be_a(String)
    end

    it "includes occurrences count" do
      expect(message[:occurrences]).to eq(5)
    end

    it "includes status" do
      expect(message[:status]).to eq(error_group.status)
    end

    it "includes location" do
      expect(message[:location]).to include(error_group.file_path)
    end

    it "includes request url" do
      expect(message[:url]).to eq(occurrence.request_url)
    end

    it "includes request method" do
      expect(message[:method]).to eq(occurrence.request_method)
    end

    it "includes timestamp" do
      expect(message[:timestamp]).to be_a(ActiveSupport::TimeWithZone)
    end

    it "includes reopened status" do
      expect(message[:reopened]).to be false
    end
  end

  describe "#format_location" do
    it "returns file:line format" do
      location = notifier.send(:format_location, error_group)
      expect(location).to eq("#{error_group.file_path}:#{error_group.line_number}")
    end

    it "returns unknown when no path" do
      error_group.file_path = nil
      error_group.line_number = nil
      location = notifier.send(:format_location, error_group)
      expect(location).to eq("unknown")
    end
  end

  describe "#status_emoji" do
    context "when recently reopened" do
      before { allow(error_group).to receive(:recently_reopened?).and_return(true) }

      it "returns recycle emoji" do
        expect(notifier.send(:status_emoji, error_group)).to eq("\u{1F504}")
      end
    end

    context "when first occurrence" do
      before do
        allow(error_group).to receive(:recently_reopened?).and_return(false)
        error_group.occurrences_count = 1
      end

      it "returns alert emoji" do
        expect(notifier.send(:status_emoji, error_group)).to eq("\u{1F6A8}")
      end
    end

    context "when multiple occurrences" do
      before do
        allow(error_group).to receive(:recently_reopened?).and_return(false)
        error_group.occurrences_count = 10
      end

      it "returns warning emoji" do
        expect(notifier.send(:status_emoji, error_group)).to eq("\u{26A0}\u{FE0F}")
      end
    end
  end
end
