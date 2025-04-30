# frozen_string_literal: true

require "faraday/adapter/test"

RSpec.describe ClaudeJr::Client do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) {
    Faraday.new { |b|
      b.request :json
      b.response :json, parser_options: {symbolize_names: true}
      b.adapter(:test, stubs)
    }
  }
  let(:api_key) { "test-api-key" }
  let(:success_body) do
    {
      content: [{text: "Hi! My name is Claude.", type: "text"}],
      id: "msg_test",
      model: "claude-3-7-sonnet-20250219",
      role: "assistant",
      stop_reason: "end_turn",
      stop_sequence: nil,
      type: "message",
      usage: {input_tokens: 2095, output_tokens: 503}
    }
  end
  let(:failure_body) do
    {
      error: {message: "Invalid request", type: "invalid_request_error"},
      type: "error"
    }
  end
  subject { described_class.new(api_key: api_key) }
  before { subject.connection = conn }

  describe "#chat" do
    context "when response is successful" do
      before do
        stubs.post("/messages") do |_env|
          [200, {"Content-Type" => "application/json"}, success_body.to_json]
        end
      end

      it "returns the parsed ChatResponse object" do
        response = subject.chat("Hello, world")

        expect(response).to be_a(ClaudeJr::ChatResponse)
        expect(response.id).to eq("msg_test")
        expect(response.content).to eq([{text: "Hi! My name is Claude.", type: "text"}])
      end
    end

    context "when response fails" do
      before do
        stubs.post("/messages") do |_env|
          [400, {"Content-Type" => "application/json"}, failure_body.to_json]
        end
      end

      it "raises APIError with an ErrorResponse" do
        expect do
          subject.chat("Hello, world", model: "claude-3-7-sonnet-20250219", max_tokens: 1024)
        end.to raise_error do |error|
          expect(error).to be_a(ClaudeJr::APIError)
          expect(error.message).to include("Invalid request")
          expect(error.error_response).to be_a(ClaudeJr::ErrorResponse)
          expect(error.error_response.error_type).to eq("invalid_request_error")
        end
      end
    end
  end
end
