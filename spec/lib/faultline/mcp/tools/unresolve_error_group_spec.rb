# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::UnresolveErrorGroup do
  describe ".mutates?" do
    it "is true" do
      expect(described_class.mutates?).to be true
    end
  end

  describe ".call" do
    let!(:group) { create(:error_group, :resolved) }

    context "when mcp_readonly is true (default)" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(true) }

      it "refuses to mutate and returns an error" do
        result = described_class.call(id: group.id)
        expect(result[:error]).to match(/mcp_readonly is true/)
        expect(group.reload.status).to eq("resolved")
      end
    end

    context "when mcp_readonly is false" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(false) }

      it "marks the group unresolved and clears resolved_at" do
        result = described_class.call(id: group.id)

        expect(result[:unresolved]).to be true
        expect(result[:group][:status]).to eq("unresolved")
        expect(group.reload.resolved_at).to be_nil
      end

      it "returns an error when the group does not exist" do
        result = described_class.call(id: -1)
        expect(result[:error]).to match(/Couldn't find Faultline::ErrorGroup/)
      end
    end
  end
end
