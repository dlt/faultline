# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::DeleteErrorGroup do
  describe ".mutates?" do
    it "is true" do
      expect(described_class.mutates?).to be true
    end
  end

  describe ".call" do
    let!(:group) { create(:error_group, occurrences_count: 3) }

    context "when mcp_readonly is true (default)" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(true) }

      it "refuses to mutate and leaves the group in place" do
        result = described_class.call(id: group.id)
        expect(result[:error]).to match(/mcp_readonly is true/)
        expect { group.reload }.not_to raise_error
      end
    end

    context "when mcp_readonly is false" do
      before { allow(Faultline.configuration).to receive(:mcp_readonly).and_return(false) }

      it "destroys the group and reports the occurrence count" do
        result = described_class.call(id: group.id)

        expect(result[:deleted]).to be true
        expect(result[:id]).to eq(group.id)
        expect(result[:occurrences_deleted]).to eq(3)
        expect { group.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "cascades to error occurrences" do
        create(:error_occurrence, error_group: group)
        described_class.call(id: group.id)
        expect(Faultline::ErrorOccurrence.where(error_group_id: group.id)).to be_empty
      end

      it "returns an error when the group does not exist" do
        result = described_class.call(id: -1)
        expect(result[:error]).to match(/Couldn't find Faultline::ErrorGroup/)
      end
    end
  end
end
