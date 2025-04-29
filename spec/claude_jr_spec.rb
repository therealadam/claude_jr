# frozen_string_literal: true

require "faraday/adapter/test"

RSpec.describe ClaudeJr do
  it "has a version number" do
    expect(ClaudeJr::VERSION).not_to be nil
  end

  describe ClaudeJr::Client do
    let(:api_key) { "test-api-key" }
    let(:success_body) { {result: "Hello from Claude"} }
    let(:failure_body) { {error: "Bad Request"} }
    subject { described_class.new(api_key: api_key) }

    describe "#chat" do
      context "when response is successful" do
        before do
          stubs = Faraday::Adapter::Test::Stubs.new do |stub|
            stub.post("v1/messages") do |_env|
              # ...inspect env.body if needed...
              [200, {"Content-Type" => "application/json"}, success_body.to_json]
            end
          end

          test_connection = Faraday.new(url: ClaudeJr::Client::API_URL) do |f|
            f.request :json
            f.response :json, parser_options: {symbolize_names: true}
            f.adapter :test, stubs
          end

          subject.connection = test_connection
        end

        it "returns the parsed response" do
          response = subject.chat("Hello, world", model: "claude-3-7-sonnet-20250219", max_tokens: 1024)
          expect(response).to eq(success_body)
        end
      end

      context "when response fails" do
        before do
          stubs = Faraday::Adapter::Test::Stubs.new do |stub|
            stub.post("v1/messages") do |_env|
              [400, {"Content-Type" => "application/json"}, failure_body.to_json]
            end
          end

          test_connection = Faraday.new(url: ClaudeJr::Client::API_URL) do |f|
            f.request :json
            f.response :json, parser_options: {symbolize_names: true}
            f.adapter :test, stubs
          end

          subject.connection = test_connection
        end

        it "raises APIError with details" do
          expect do
            subject.chat("Hello, world", model: "claude-3-7-sonnet-20250219", max_tokens: 1024)
          end.to raise_error(ClaudeJr::APIError, /API request failed/)
        end
      end
    end
  end
end
