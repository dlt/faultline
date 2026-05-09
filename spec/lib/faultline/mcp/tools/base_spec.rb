# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::Base do
  describe ".call" do
    let(:dummy_class) do
      Class.new(described_class) do
        def execute
          { ok: true, args: args }
        end
      end
    end

    it "delegates to a new instance" do
      result = dummy_class.call(foo: "bar")
      expect(result).to eq(ok: true, args: { foo: "bar" })
    end

    it "symbolizes string keys" do
      result = dummy_class.call("foo" => "bar")
      expect(result[:args]).to eq(foo: "bar")
    end

    it "tolerates a nil args argument" do
      result = dummy_class.call(nil)
      expect(result[:args]).to eq({})
    end
  end

  describe "readonly enforcement" do
    let(:mutating_class) do
      Class.new(described_class) do
        class << self
          def mutates?
            true
          end
        end

        def execute
          { mutated: true }
        end
      end
    end

    context "when mcp_readonly is true" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(true) }

      it "blocks mutating tools with an error" do
        result = mutating_class.call({})
        expect(result[:error]).to match(/mcp_readonly is true/)
        expect(result[:mutated]).to be_nil
      end
    end

    context "when mcp_readonly is false" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(false) }

      it "allows mutating tools to execute" do
        result = mutating_class.call({})
        expect(result).to eq(mutated: true)
      end
    end
  end

  describe "error rescue" do
    it "wraps RecordNotFound as an error response" do
      klass = Class.new(described_class) do
        def execute
          Faultline::ErrorGroup.find(-1)
        end
      end
      result = klass.call({})
      expect(result[:error]).to match(/Couldn't find Faultline::ErrorGroup/)
    end
  end

  describe "#execute" do
    it "raises NotImplementedError if a subclass forgets it" do
      klass = Class.new(described_class)
      expect { klass.call({}) }.to raise_error(NotImplementedError, /must implement #execute/)
    end
  end
end
