# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "sets user_class to User" do
      expect(config.user_class).to eq("User")
    end

    it "sets user_method to :current_user" do
      expect(config.user_method).to eq(:current_user)
    end

    it "sets custom_context to nil" do
      expect(config.custom_context).to be_nil
    end

    it "sets default ignored_exceptions" do
      expect(config.ignored_exceptions).to include("ActiveRecord::RecordNotFound")
      expect(config.ignored_exceptions).to include("ActionController::RoutingError")
    end

    it "sets default notification_cooldown to 5 minutes" do
      expect(config.notification_cooldown).to eq(5.minutes)
    end

    it "has empty notifiers by default" do
      expect(config.notifiers).to eq([])
    end

    it "sets enable_middleware to true" do
      expect(config.enable_middleware).to be true
    end

    it "sets retention_days to 90" do
      expect(config.retention_days).to eq(90)
    end
  end

  describe "#add_notifier" do
    it "adds notifier to list" do
      notifier = double("notifier")
      config.add_notifier(notifier)
      expect(config.notifiers).to include(notifier)
    end
  end

  describe "#github_configured?" do
    it "returns false when github_repo is nil" do
      config.github_repo = nil
      config.github_token = "token"
      expect(config.github_configured?).to be false
    end

    it "returns false when github_token is nil" do
      config.github_repo = "org/repo"
      config.github_token = nil
      expect(config.github_configured?).to be false
    end

    it "returns true when both are set" do
      config.github_repo = "org/repo"
      config.github_token = "token"
      expect(config.github_configured?).to be true
    end
  end

  describe "#resolved_app_name" do
    it "returns app_name if set" do
      config.app_name = "MyApp"
      expect(config.resolved_app_name).to eq("MyApp")
    end

    it "falls back to Rails app name" do
      config.app_name = nil
      expect(config.resolved_app_name).to be_present
    end
  end

  describe "#resolved_filter_parameters" do
    it "combines filter_parameters with Rails config and sanitize_fields" do
      config.filter_parameters = [:custom_secret]
      result = config.resolved_filter_parameters
      expect(result).to include(:custom_secret)
      expect(result).to include("password")
    end
  end
end
