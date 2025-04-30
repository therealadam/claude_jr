# frozen_string_literal: true

require "faraday/adapter/test"

RSpec.describe ClaudeJr::Tool do
  let(:input_schema) do
    {
      type: "object",
      properties: {
        location: {
          type: "string",
          description: "The city and state, e.g. San Francisco, CA"
        }
      },
      required: ["location"]
    }
  end

  subject do
    described_class.new(
      name: "get_weather",
      description: "Get the current weather in a given location",
      input_schema: input_schema
    )
  end

  it "serializes to the expected hash structure" do
    expected = {
      name: "get_weather",
      description: "Get the current weather in a given location",
      input_schema: input_schema
    }

    expect(subject.to_h).to eq(expected)
    expect(subject.to_json).to eq(expected)
  end
end

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
  let(:multi_turn_body) do
    {
      content: [
        {role: "user", content: "Hello there."},
        {role: "assistant", content: "Hi, I'm Claude. How can I help you?"},
        {role: "user", content: "Can you explain LLMs in plain English?"}
      ],
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

    context "when response contains multiple turns" do
      before do
        stubs.post("/messages") do |_env|
          [200, {"Content-Type" => "application/json"}, multi_turn_body.to_json]
        end
      end

      it "returns the parsed ChatResponse object" do
        response = subject.chat("Hello, world")

        expect(response).to be_a(ClaudeJr::ChatResponse)
        expect(response.id).to eq("msg_test")
        expect(response.content).to eq([
          {role: "user", content: "Hello there."},
          {role: "assistant", content: "Hi, I'm Claude. How can I help you?"},
          {role: "user", content: "Can you explain LLMs in plain English?"}
        ])
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

    context "when using tools" do
      let(:tools) do
        [{
          name: "get_weather",
          description: "Get the current weather in a given location",
          input_schema: {
            type: "object",
            properties: {
              location: {
                type: "string",
                description: "The city and state, e.g. San Francisco, CA"
              }
            },
            required: ["location"]
          }
        }]
      end

      before do
        stubs.post("/messages") do |env|
          body = JSON.parse(env.body)
          expect(body["tools"]).to eq(JSON.parse(tools.to_json))
          [200, {"Content-Type" => "application/json"}, success_body.to_json]
        end
      end

      it "includes tools in the request payload" do
        response = subject.chat("What's the weather?", tools: tools)
        expect(response).to be_a(ClaudeJr::ChatResponse)
      end

      let(:tool) do
        ClaudeJr::Tool.new(
          name: "get_weather",
          description: "Get the current weather in a given location",
          input_schema: {
            type: "object",
            properties: {
              location: {
                type: "string",
                description: "The city and state, e.g. San Francisco, CA"
              }
            },
            required: ["location"]
          }
        )
      end

      let(:tool_hash) { tool.to_h }
      let(:expected_tool_json) { JSON.parse(tool_hash.to_json) }

      before do
        stubs.post("/messages") do |env|
          body = JSON.parse(env.body)
          expect(body["tools"]).to eq([expected_tool_json])
          [200, {"Content-Type" => "application/json"}, success_body.to_json]
        end
      end

      it "accepts an array of Tool instances" do
        response = subject.chat("What's the weather?", tools: [tool])
        expect(response).to be_a(ClaudeJr::ChatResponse)
      end

      it "accepts an array of hash tool definitions" do
        response = subject.chat("What's the weather?", tools: [tool_hash])
        expect(response).to be_a(ClaudeJr::ChatResponse)
      end
    end

    context "when response contains tool use" do
      let(:tool_use_body) do
        {
          content: [
            {
              type: "text",
              text: "<thinking>To answer this question, I will: 1. Use the get_weather tool to get the current weather in San Francisco.</thinking>"
            },
            {
              type: "tool_use",
              id: "toolu_01A09q90qw90lq917835lq9",
              name: "get_weather",
              input: {location: "San Francisco, CA"}
            }
          ],
          id: "msg_test",
          model: "claude-3-7-sonnet-20250219",
          role: "assistant",
          stop_reason: "end_turn",
          stop_sequence: nil,
          type: "message",
          usage: {input_tokens: 2095, output_tokens: 503}
        }
      end

      before do
        stubs.post("/messages") do |_env|
          [200, {"Content-Type" => "application/json"}, tool_use_body.to_json]
        end
      end

      it "parses tool use content correctly" do
        response = subject.chat("What's the weather in San Francisco?")

        expect(response.content).to eq([
          {
            type: "text",
            text: "<thinking>To answer this question, I will: 1. Use the get_weather tool to get the current weather in San Francisco.</thinking>"
          },
          {
            type: "tool_use",
            id: "toolu_01A09q90qw90lq917835lq9",
            name: "get_weather",
            input: {location: "San Francisco, CA"}
          }
        ])
      end
    end
  end
end
