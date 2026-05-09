# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::RecentOccurrences do
  describe ".call" do
    let(:group) { create(:error_group) }

    it "returns occurrences ordered newest first" do
      old = create(:error_occurrence, error_group: group, created_at: 1.day.ago)
      new = create(:error_occurrence, error_group: group, created_at: 1.minute.ago)

      result = described_class.call(group_id: group.id)
      ids = result[:occurrences].map { |o| o[:id] }
      expect(ids).to eq([new.id, old.id])
    end

    it "honors the limit, clamped to [1,100]" do
      create_list(:error_occurrence, 5, error_group: group)

      expect(described_class.call(group_id: group.id, limit: 2)[:occurrences].size).to eq(2)
      expect(described_class.call(group_id: group.id, limit: 9999)[:limit]).to eq(100)
    end

    it "scopes occurrences to the requested group" do
      other = create(:error_group)
      create(:error_occurrence, error_group: other)
      mine = create(:error_occurrence, error_group: group)

      result = described_class.call(group_id: group.id)
      ids = result[:occurrences].map { |o| o[:id] }
      expect(ids).to eq([mine.id])
    end

    it "returns an error when the group does not exist" do
      result = described_class.call(group_id: -1)
      expect(result[:error]).to match(/Couldn't find Faultline::ErrorGroup/)
    end
  end
end
