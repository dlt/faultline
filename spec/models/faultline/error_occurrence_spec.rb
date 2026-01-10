# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::ErrorOccurrence, type: :model do
  describe "associations" do
    it "belongs to error_group" do
      occurrence = create(:error_occurrence)
      expect(occurrence.error_group).to be_a(Faultline::ErrorGroup)
    end

    it "has many error_contexts" do
      occurrence = create(:error_occurrence)
      expect(occurrence.error_contexts).to eq([])
    end
  end

  describe "#parsed_backtrace" do
    it "parses JSON backtrace" do
      occurrence = create(:error_occurrence, backtrace: '["line1", "line2"]')
      expect(occurrence.parsed_backtrace).to eq(["line1", "line2"])
    end

    it "returns empty array for nil backtrace" do
      occurrence = build(:error_occurrence, backtrace: nil)
      expect(occurrence.parsed_backtrace).to eq([])
    end

    it "returns empty array for invalid JSON" do
      occurrence = build(:error_occurrence, backtrace: "not json")
      expect(occurrence.parsed_backtrace).to eq([])
    end
  end

  describe "#parsed_local_variables" do
    it "returns local_variables hash" do
      occurrence = create(:error_occurrence, :with_local_variables)
      expect(occurrence.parsed_local_variables).to be_a(Hash)
      expect(occurrence.parsed_local_variables["user"]).to be_present
    end

    it "returns empty hash when nil" do
      occurrence = build(:error_occurrence, local_variables: nil)
      expect(occurrence.parsed_local_variables).to eq({})
    end
  end

  describe "#app_backtrace_lines" do
    it "filters to app lines only" do
      backtrace = [
        "#{Rails.root}/app/models/user.rb:10:in `save'",
        "/gems/activerecord/lib/base.rb:100:in `save'",
        "#{Rails.root}/app/controllers/users_controller.rb:5:in `create'"
      ].to_json

      occurrence = build(:error_occurrence, backtrace: backtrace)
      app_lines = occurrence.app_backtrace_lines

      expect(app_lines.length).to eq(2)
      expect(app_lines.all? { |l| l.include?(Rails.root.to_s) }).to be true
    end
  end

  describe "#source_context" do
    it "returns nil when no app backtrace" do
      occurrence = build(:error_occurrence, backtrace: "[]")
      expect(occurrence.source_context).to be_nil
    end
  end

  describe ".recent" do
    it "orders by created_at descending" do
      old = create(:error_occurrence, created_at: 2.days.ago)
      new = create(:error_occurrence, created_at: 1.hour.ago)

      expect(described_class.recent.first).to eq(new)
    end
  end
end
