# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Mcp::Tools::ListErrorGroups do
  describe ".call" do
    it "returns the most recent groups by last_seen_at desc" do
      old = create(:error_group, last_seen_at: 2.days.ago)
      new = create(:error_group, last_seen_at: 1.minute.ago)

      result = described_class.call({})

      ids = result[:groups].map { |g| g[:id] }
      expect(ids).to eq([new.id, old.id])
    end

    it "serializes group fields the dashboard exposes" do
      group = create(:error_group, exception_class: "RuntimeError", occurrences_count: 5)

      result = described_class.call({})
      payload = result[:groups].first

      expect(payload).to include(
        id: group.id,
        exception_class: "RuntimeError",
        occurrences_count: 5,
        status: "unresolved"
      )
      expect(payload[:last_seen_at]).to be_a(String)
    end

    context "with status filter" do
      it "filters by status" do
        unresolved = create(:error_group, status: "unresolved")
        create(:error_group, :resolved)

        result = described_class.call(status: "unresolved")
        ids = result[:groups].map { |g| g[:id] }
        expect(ids).to eq([unresolved.id])
      end

      it "rejects invalid status with an error" do
        result = described_class.call(status: "garbage")
        expect(result[:error]).to match(/Invalid status/)
      end
    end

    context "with since filter" do
      it "excludes groups with last_seen_at older than since" do
        old = create(:error_group, last_seen_at: 5.days.ago)
        new = create(:error_group, last_seen_at: 1.hour.ago)

        result = described_class.call(since: 1.day.ago.iso8601)
        ids = result[:groups].map { |g| g[:id] }

        expect(ids).to include(new.id)
        expect(ids).not_to include(old.id)
      end

      it "ignores unparseable since values" do
        create(:error_group)
        result = described_class.call(since: "not-a-time")
        expect(result[:groups]).not_to be_empty
      end
    end

    context "with search filter" do
      it "filters by message substring" do
        match = create(:error_group, sanitized_message: "database connection lost")
        create(:error_group, sanitized_message: "permission denied")

        result = described_class.call(search: "connection")
        ids = result[:groups].map { |g| g[:id] }
        expect(ids).to eq([match.id])
      end
    end

    context "with limit" do
      it "clamps limit to the [1,100] range" do
        create_list(:error_group, 5)
        expect(described_class.call(limit: 0)[:limit]).to eq(1)
        expect(described_class.call(limit: 9999)[:limit]).to eq(100)
      end

      it "honors the requested limit" do
        create_list(:error_group, 5)
        result = described_class.call(limit: 2)
        expect(result[:groups].size).to eq(2)
      end
    end
  end
end
