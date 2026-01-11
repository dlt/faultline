# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Notifiers::Telegram do
  let(:bot_token) { "123456789:ABCDEF" }
  let(:chat_id) { "-1001234567890" }
  let(:notifier) { described_class.new(bot_token: bot_token, chat_id: chat_id) }
  let(:error_group) { create(:error_group) }
  let(:occurrence) { create(:error_occurrence, error_group: error_group) }

  describe "#initialize" do
    it "sets bot_token" do
      expect(notifier.instance_variable_get(:@bot_token)).to eq(bot_token)
    end

    it "sets chat_id" do
      expect(notifier.instance_variable_get(:@chat_id)).to eq(chat_id)
    end
  end

  describe "#call" do
    let(:response_double) { instance_double(Net::HTTPSuccess, is_a?: true) }

    before do
      allow(Net::HTTP).to receive(:post_form).and_return(response_double)
    end

    it "sends message via Telegram API" do
      expect(Net::HTTP).to receive(:post_form).and_return(response_double)
      notifier.call(error_group, occurrence)
    end

    context "when request fails" do
      let(:response_double) { instance_double(Net::HTTPBadRequest, is_a?: false, body: "error") }

      it "logs error" do
        expect(Rails.logger).to receive(:error).with(/API error/)
        notifier.call(error_group, occurrence)
      end
    end

    context "when exception raised" do
      before do
        allow(Net::HTTP).to receive(:post_form).and_raise(StandardError.new("Connection failed"))
      end

      it "logs error" do
        expect(Rails.logger).to receive(:error).with(/Failed to send/)
        notifier.call(error_group, occurrence)
      end
    end
  end

  describe "message formatting" do
    let(:message) { notifier.send(:format_telegram_message, error_group, occurrence) }

    it "includes title with HTML bold" do
      expect(message).to include("<b>")
    end

    it "includes exception class in code tags" do
      expect(message).to include("<code>#{error_group.exception_class}</code>")
    end

    it "includes type label" do
      expect(message).to include("<b>Type:</b>")
    end

    it "includes message label" do
      expect(message).to include("<b>Message:</b>")
    end

    it "includes count" do
      expect(message).to include("<b>Count:</b>")
    end

    it "includes location" do
      expect(message).to include("<b>Location:</b>")
    end

    context "when reopened" do
      before { allow(error_group).to receive(:recently_reopened?).and_return(true) }

      it "includes reopened notice in italics" do
        expect(message).to include("<i>This error was previously resolved")
      end
    end

    context "with user identifier" do
      before do
        allow(occurrence).to receive(:user_identifier).and_return("john@example.com")
      end

      it "includes user" do
        expect(message).to include("<b>User:</b>")
        expect(message).to include("john@example.com")
      end
    end

    context "with URL" do
      it "includes URL with method" do
        expect(message).to include("<b>URL:</b>")
        expect(message).to include(occurrence.request_method)
      end
    end
  end

  describe "#escape_html" do
    it "escapes ampersand" do
      expect(notifier.send(:escape_html, "foo & bar")).to eq("foo &amp; bar")
    end

    it "escapes less than" do
      expect(notifier.send(:escape_html, "foo < bar")).to eq("foo &lt; bar")
    end

    it "escapes greater than" do
      expect(notifier.send(:escape_html, "foo > bar")).to eq("foo &gt; bar")
    end
  end
end
