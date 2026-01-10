# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::ErrorGroup, type: :model do
  describe "database constraints" do
    it "enforces unique fingerprint via database" do
      create(:error_group, fingerprint: "abc123")
      duplicate = build(:error_group, fingerprint: "abc123")
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "associations" do
    it "has many error_occurrences" do
      group = create(:error_group)
      occurrence = create(:error_occurrence, error_group: group)
      expect(group.error_occurrences).to include(occurrence)
    end
  end

  describe "#resolve!" do
    it "marks the error as resolved" do
      group = create(:error_group, status: "unresolved")
      group.resolve!
      expect(group.status).to eq("resolved")
      expect(group.resolved_at).to be_present
    end
  end

  describe "#unresolve!" do
    it "marks the error as unresolved" do
      group = create(:error_group, :resolved)
      group.unresolve!
      expect(group.status).to eq("unresolved")
      expect(group.resolved_at).to be_nil
    end
  end

  describe "#ignore!" do
    it "marks the error as ignored" do
      group = create(:error_group)
      group.ignore!
      expect(group.status).to eq("ignored")
    end
  end

  describe "#recently_reopened?" do
    it "returns true when status changed from resolved to unresolved recently" do
      group = create(:error_group, :resolved)
      group.update!(status: "unresolved", last_seen_at: Time.current)
      expect(group.recently_reopened?).to be true
    end

    it "returns false for never-resolved errors" do
      group = create(:error_group)
      expect(group.recently_reopened?).to be false
    end
  end

  describe ".recent" do
    it "orders by last_seen_at descending" do
      _old = create(:error_group, last_seen_at: 2.days.ago)
      recent = create(:error_group, last_seen_at: 1.hour.ago)
      expect(described_class.recent.first).to eq(recent)
    end
  end

  describe ".find_or_create_from_exception" do
    let(:exception) do
      begin
        raise StandardError, "Test error"
      rescue => e
        e
      end
    end

    it "creates a new error group" do
      expect {
        described_class.find_or_create_from_exception(exception)
      }.to change(described_class, :count).by(1)
    end

    it "reuses existing group for same fingerprint" do
      described_class.find_or_create_from_exception(exception)
      expect {
        described_class.find_or_create_from_exception(exception)
      }.not_to change(described_class, :count)
    end
  end

  describe ".sanitize_message" do
    it "replaces numeric IDs with N" do
      result = described_class.sanitize_message("User 12345 not found")
      expect(result).to eq("User N not found")
    end

    it "replaces hex object IDs with ID" do
      result = described_class.sanitize_message("Record 507f1f77bcf86cd799439011 not found")
      expect(result).to eq("Record ID not found")
    end
  end
end
