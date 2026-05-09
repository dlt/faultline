# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::GetErrorGroup do
  describe ".call" do
    it "returns the group plus its recent occurrences" do
      group = create(:error_group)
      old = create(:error_occurrence, error_group: group, created_at: 2.hours.ago)
      new = create(:error_occurrence, error_group: group, created_at: 1.minute.ago)

      result = described_class.call(id: group.id)

      expect(result[:group][:id]).to eq(group.id)
      expect(result[:recent_occurrences].map { |o| o[:id] }).to eq([new.id, old.id])
    end

    it "returns an error when the group does not exist" do
      result = described_class.call(id: -1)
      expect(result[:error]).to match(/Couldn't find Faultline::ErrorGroup/)
    end

    it "does not include heavy fields (backtrace, locals) in the occurrence summary" do
      group = create(:error_group)
      create(:error_occurrence, :with_local_variables, error_group: group)

      occ = described_class.call(id: group.id)[:recent_occurrences].first
      expect(occ).not_to have_key(:backtrace)
      expect(occ).not_to have_key(:local_variables)
    end
  end
end
