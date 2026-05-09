# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::CreateGithubIssue do
  describe ".mutates?" do
    it "is true" do
      expect(described_class.mutates?).to be true
    end
  end

  describe ".call" do
    let!(:group) { create(:error_group) }

    before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(false) }

    context "when GitHub is not configured" do
      before { allow(Faultline.configuration).to receive(:github_configured?).and_return(false) }

      it "returns an error" do
        result = described_class.call(id: group.id)
        expect(result[:error]).to match(/GitHub is not configured/)
      end
    end

    context "when GitHub is configured" do
      before do
        allow(Faultline.configuration).to receive(:github_configured?).and_return(true)
      end

      it "returns an error when the group has no occurrences" do
        result = described_class.call(id: group.id)
        expect(result[:error]).to match(/no occurrences/)
      end

      it "delegates to GithubIssueCreator and returns its result" do
        create(:error_occurrence, error_group: group)
        creator = instance_double(Faultline::GithubIssueCreator)
        allow(Faultline::GithubIssueCreator).to receive(:new).and_return(creator)
        allow(creator).to receive(:create).and_return(success: true, issue_url: "https://example/1", issue_number: 1)

        result = described_class.call(id: group.id)
        expect(result[:success]).to be true
        expect(result[:issue_number]).to eq(1)
      end

      it "returns an error when the group does not exist" do
        result = described_class.call(id: -1)
        expect(result[:error]).to match(/Couldn't find Faultline::ErrorGroup/)
      end
    end

    context "when mcp_readonly is true" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(true) }

      it "blocks the call before any GitHub interaction" do
        expect(Faultline::GithubIssueCreator).not_to receive(:new)
        result = described_class.call(id: group.id)
        expect(result[:error]).to match(/mcp_readonly is true/)
      end
    end
  end
end
