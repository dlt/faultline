# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::ApplicationRecord do
  describe ".configure_database_connection!" do
    let(:original_config) { Faultline.configuration.dup }

    after do
      # Reset configuration after each test
      Faultline.instance_variable_set(:@configuration, original_config)
    end

    context "when database_key is nil" do
      before do
        Faultline.configuration.database_key = nil
      end

      it "does not call connects_to" do
        expect(described_class).not_to receive(:connects_to)
        described_class.configure_database_connection!
      end
    end

    context "when database_key is set but database is not configured" do
      before do
        Faultline.configuration.database_key = :nonexistent_database
      end

      it "logs a warning and does not call connects_to" do
        expect(Rails.logger).to receive(:warn).with(/not found in database.yml/)
        expect(described_class).not_to receive(:connects_to)
        described_class.configure_database_connection!
      end
    end
  end

  describe ".table_name_prefix" do
    it "returns faultline_" do
      expect(described_class.table_name_prefix).to eq("faultline_")
    end
  end

  describe ".abstract_class" do
    it "is true" do
      expect(described_class.abstract_class).to be true
    end
  end
end
