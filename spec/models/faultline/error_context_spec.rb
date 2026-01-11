# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::ErrorContext, type: :model do
  let(:error_group) { create(:error_group) }
  let(:occurrence) { create(:error_occurrence, error_group: error_group) }

  describe "associations" do
    it "belongs to error_occurrence" do
      context = described_class.new(error_occurrence: occurrence, key: "test", value: "data")
      expect(context.error_occurrence).to eq(occurrence)
    end
  end

  describe "validations" do
    it "requires key" do
      context = described_class.new(error_occurrence: occurrence, key: nil, value: "data")
      expect(context).not_to be_valid
      expect(context.errors[:key]).to include("can't be blank")
    end

    it "is valid with key and occurrence" do
      context = described_class.new(error_occurrence: occurrence, key: "test", value: "data")
      expect(context).to be_valid
    end
  end

  describe "#parsed_value" do
    let(:context) { described_class.new(error_occurrence: occurrence, key: "test") }

    context "with JSON value" do
      it "parses JSON" do
        context.value = '{"foo": "bar"}'
        expect(context.parsed_value).to eq({ "foo" => "bar" })
      end

      it "parses JSON arrays" do
        context.value = '["a", "b", "c"]'
        expect(context.parsed_value).to eq(["a", "b", "c"])
      end
    end

    context "with non-JSON value" do
      it "returns the raw value" do
        context.value = "plain string"
        expect(context.parsed_value).to eq("plain string")
      end
    end

    context "with invalid JSON" do
      it "returns the raw value" do
        context.value = "{invalid json"
        expect(context.parsed_value).to eq("{invalid json")
      end
    end

    context "with nil value" do
      it "returns nil" do
        context.value = nil
        expect(context.parsed_value).to be_nil
      end
    end
  end
end
