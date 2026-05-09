# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::IgnoreErrorGroup do
  describe ".mutates?" do
    it "is true" do
      expect(described_class.mutates?).to be true
    end
  end

  describe ".call" do
    let!(:group) { create(:error_group, status: "unresolved") }

    context "when mcp_readonly is true (default)" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(true) }

      it "refuses to mutate" do
        result = described_class.call(id: group.id)
        expect(result[:error]).to match(/mcp_readonly is true/)
        expect(group.reload.status).to eq("unresolved")
      end
    end

    context "when mcp_readonly is false" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(false) }

      it "marks the group ignored" do
        result = described_class.call(id: group.id)
        expect(result[:ignored]).to be true
        expect(group.reload.status).to eq("ignored")
      end

      it "returns an error when the group does not exist" do
        result = described_class.call(id: -1)
        expect(result[:error]).to match(/Couldn't find Faultline::ErrorGroup/)
      end
    end
  end
end
