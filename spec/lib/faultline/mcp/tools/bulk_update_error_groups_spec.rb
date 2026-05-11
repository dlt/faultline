# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::BulkUpdateErrorGroups do
  describe ".mutates?" do
    it "is true" do
      expect(described_class.mutates?).to be true
    end
  end

  describe ".call" do
    let!(:group_a) { create(:error_group, status: "unresolved") }
    let!(:group_b) { create(:error_group, status: "unresolved") }

    context "when mcp_readonly is true (default)" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(true) }

      it "refuses to mutate and leaves groups untouched" do
        result = described_class.call(ids: [group_a.id, group_b.id], action: "resolve")
        expect(result[:error]).to match(/mcp_readonly is true/)
        expect(group_a.reload.status).to eq("unresolved")
      end
    end

    context "when mcp_readonly is false" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(false) }

      it "resolves all listed groups" do
        result = described_class.call(ids: [group_a.id, group_b.id], action: "resolve")

        expect(result[:action]).to eq("resolve")
        expect(result[:affected]).to eq(2)
        expect(result[:ids]).to match_array([group_a.id, group_b.id])
        expect(group_a.reload.status).to eq("resolved")
        expect(group_a.resolved_at).not_to be_nil
      end

      it "unresolves resolved groups and clears resolved_at" do
        group_a.update!(status: "resolved", resolved_at: Time.current)
        described_class.call(ids: [group_a.id], action: "unresolve")
        expect(group_a.reload.status).to eq("unresolved")
        expect(group_a.resolved_at).to be_nil
      end

      it "ignores listed groups" do
        described_class.call(ids: [group_a.id], action: "ignore")
        expect(group_a.reload.status).to eq("ignored")
      end

      it "deletes listed groups and reports the count" do
        result = described_class.call(ids: [group_a.id, group_b.id], action: "delete")
        expect(result[:affected]).to eq(2)
        expect(Faultline::ErrorGroup.where(id: [group_a.id, group_b.id])).to be_empty
      end

      it "reports missing ids" do
        result = described_class.call(ids: [group_a.id, -1], action: "resolve")
        expect(result[:affected]).to eq(1)
        expect(result[:missing_ids]).to eq([-1])
      end

      it "rejects an empty id list" do
        result = described_class.call(ids: [], action: "resolve")
        expect(result[:error]).to match(/non-empty array/)
      end

      it "rejects an unknown action" do
        result = described_class.call(ids: [group_a.id], action: "nuke")
        expect(result[:error]).to match(/Invalid action/)
        expect(group_a.reload.status).to eq("unresolved")
      end
    end
  end
end
