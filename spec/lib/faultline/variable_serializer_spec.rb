# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::VariableSerializer do
  describe ".serialize" do
    it "serializes simple values" do
      result = described_class.serialize({ name: "John", age: 30 })
      expect(result["name"]).to eq("John")
      expect(result["age"]).to eq(30)
    end

    it "serializes nested hashes" do
      result = described_class.serialize({ user: { name: "John", email: "john@example.com" } })
      expect(result["user"]).to be_a(Hash)
      expect(result["user"]["name"]).to eq("John")
    end

    it "serializes arrays" do
      result = described_class.serialize({ items: [1, 2, 3] })
      expect(result["items"]).to eq([1, 2, 3])
    end

    it "filters sensitive fields" do
      result = described_class.serialize({ password: "secret123", token: "abc" })
      expect(result["password"]).to eq("[FILTERED]")
      expect(result["token"]).to eq("[FILTERED]")
    end

    it "truncates long strings" do
      long_string = "a" * 1000
      result = described_class.serialize({ data: long_string })
      expect(result["data"].length).to be < 1000
      expect(result["data"]).to include("[truncated")
    end

    it "handles nil values" do
      result = described_class.serialize({ value: nil })
      expect(result["value"]).to be_nil
    end

    it "handles circular references gracefully" do
      hash = { name: "test" }
      hash[:self] = hash
      expect { described_class.serialize(hash) }.not_to raise_error
    end

    it "returns empty hash for nil input" do
      expect(described_class.serialize(nil)).to eq({})
    end

    it "returns empty hash for empty input" do
      expect(described_class.serialize({})).to eq({})
    end
  end
end
