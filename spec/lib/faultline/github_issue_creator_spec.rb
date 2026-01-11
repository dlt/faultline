# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::GithubIssueCreator do
  let(:error_group) { create(:error_group) }
  let(:occurrence) { create(:error_occurrence, error_group: error_group) }
  let(:creator) { described_class.new(error_group: error_group, error_occurrence: occurrence) }

  before do
    allow(Faultline.configuration).to receive(:github_repo).and_return("owner/repo")
    allow(Faultline.configuration).to receive(:github_token).and_return("ghp_token")
    allow(Faultline.configuration).to receive(:github_labels).and_return(["bug", "error"])
  end

  describe "#create" do
    context "when not configured" do
      before do
        allow(Faultline.configuration).to receive(:github_repo).and_return(nil)
        allow(Faultline.configuration).to receive(:github_token).and_return(nil)
      end

      it "returns error hash" do
        result = creator.create
        expect(result).to eq({ error: "GitHub not configured" })
      end
    end

    context "when configured" do
      let(:http_double) { instance_double(Net::HTTP) }
      let(:success_response) do
        instance_double(
          Net::HTTPCreated,
          code: "201",
          body: { "html_url" => "https://github.com/owner/repo/issues/123", "number" => 123 }.to_json
        )
      end

      before do
        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=)
        allow(http_double).to receive(:open_timeout=)
        allow(http_double).to receive(:read_timeout=)
        allow(http_double).to receive(:request).and_return(success_response)
      end

      it "sends request to GitHub API" do
        expect(http_double).to receive(:request) do |request|
          expect(request["Authorization"]).to eq("Bearer ghp_token")
          expect(request["Accept"]).to eq("application/vnd.github+json")
          expect(request["X-GitHub-Api-Version"]).to eq("2022-11-28")
          success_response
        end
        creator.create
      end

      it "returns success hash with issue details" do
        result = creator.create
        expect(result[:success]).to be true
        expect(result[:issue_url]).to eq("https://github.com/owner/repo/issues/123")
        expect(result[:issue_number]).to eq(123)
      end

      context "when API returns error" do
        let(:error_response) { instance_double(Net::HTTPUnprocessableEntity, code: "422", body: "Validation failed") }

        before do
          allow(http_double).to receive(:request).and_return(error_response)
        end

        it "returns error hash" do
          result = creator.create
          expect(result[:error]).to include("GitHub API error")
        end
      end

      context "when exception raised" do
        before do
          allow(http_double).to receive(:request).and_raise(StandardError.new("Connection failed"))
        end

        it "returns error hash" do
          result = creator.create
          expect(result[:error]).to include("Failed to create issue")
        end
      end
    end
  end

  describe "issue title formatting" do
    it "includes Faultline prefix" do
      title = creator.send(:issue_title)
      expect(title).to start_with("[Faultline]")
    end

    it "includes exception class" do
      title = creator.send(:issue_title)
      expect(title).to include(error_group.exception_class)
    end

    it "truncates long messages" do
      error_group.sanitized_message = "A" * 200
      title = creator.send(:issue_title)
      # The title format is: "[Faultline] ExceptionClass: message..."
      # The message is truncated to 80 chars, so total length varies
      expect(title).to include("...")
    end
  end

  describe "issue labels" do
    it "returns configured labels" do
      labels = creator.send(:issue_labels)
      expect(labels).to eq(["bug", "error"])
    end

    context "when no labels configured" do
      before { allow(Faultline.configuration).to receive(:github_labels).and_return(nil) }

      it "returns empty array" do
        labels = creator.send(:issue_labels)
        expect(labels).to eq([])
      end
    end
  end

  describe "issue body formatting" do
    let(:body) { creator.send(:issue_body) }

    it "includes Error Details section" do
      expect(body).to include("## Error Details")
    end

    it "includes exception class" do
      expect(body).to include(error_group.exception_class)
    end

    it "includes message" do
      expect(body).to include(error_group.sanitized_message)
    end

    it "includes file location" do
      expect(body).to include(error_group.file_path)
      expect(body).to include(error_group.line_number.to_s)
    end

    it "includes occurrences count" do
      expect(body).to include(error_group.occurrences_count.to_s)
    end

    it "includes Stack Trace section" do
      expect(body).to include("## Stack Trace")
    end

    it "includes footer attribution" do
      expect(body).to include("Created by [Faultline]")
    end
  end

  describe "#format_backtrace" do
    it "limits to 20 lines" do
      long_backtrace = (1..30).map { |i| "line#{i}" }
      allow(occurrence).to receive(:parsed_backtrace).and_return(long_backtrace)
      backtrace = creator.send(:format_backtrace)
      expect(backtrace.lines.count).to eq(20)
    end

    it "returns message when backtrace blank" do
      allow(occurrence).to receive(:parsed_backtrace).and_return([])
      backtrace = creator.send(:format_backtrace)
      expect(backtrace).to eq("No backtrace available")
    end
  end

  describe "#local_variables_section" do
    context "when no local variables" do
      before { allow(occurrence).to receive(:local_variables).and_return(nil) }

      it "returns empty string" do
        section = creator.send(:local_variables_section)
        expect(section).to eq("")
      end
    end

    context "with local variables" do
      before do
        allow(occurrence).to receive(:local_variables).and_return({ "user" => { "id" => 1 } })
      end

      it "includes Local Variables header" do
        section = creator.send(:local_variables_section)
        expect(section).to include("## Local Variables")
      end
    end
  end

  describe "#format_value" do
    it "handles hashes" do
      result = creator.send(:format_value, { "key" => "value" })
      expect(result).to eq('{"key":"value"}')
    end

    it "handles strings" do
      result = creator.send(:format_value, "test")
      expect(result).to eq('"test"')
    end

    it "truncates long strings" do
      result = creator.send(:format_value, "A" * 200)
      expect(result).to include("...")
    end

    it "handles other types" do
      result = creator.send(:format_value, 123)
      expect(result).to eq("123")
    end
  end
end
