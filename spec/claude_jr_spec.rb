# frozen_string_literal: true

require "faraday/adapter/test"

RSpec.describe ClaudeJr::Tool do
  let(:parameters) do
    {
      type: "object",
      properties: {
        location: {
          type: "string",
          description: "The location to get the weather for, e.g. San Francisco, CA"
        },
        format: {
          type: "string",
          description: "The format to return the weather in",
          enum: ["celsius", "fahrenheit"]
        }
      },
      required: ["location", "format"]
    }
  end

  subject do
    described_class.new(
      name: "get_current_weather",
      description: "Get the current weather for a location",
      parameters: parameters
    )
  end

  it "serializes to the expected hash structure" do
    expected = {
      type: "function",
      function: {
        name: "get_current_weather",
        description: "Get the current weather for a location",
        parameters: parameters
      }
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

  let(:success_body) do
    {
      model: "llama3.2",
      created_at: "2023-12-12T14:13:43.416799Z",
      message: {
        role: "assistant",
        content: "Hello! How are you today?"
      },
      done: true,
      total_duration: 5191566416,
      load_duration: 2154458,
      prompt_eval_count: 26,
      prompt_eval_duration: 383809000,
      eval_count: 298,
      eval_duration: 4799921000
    }
  end

  let(:failure_body) do
    {
      error: "Model not found: invalid-model"
    }
  end

  subject { described_class.new }
  before { subject.connection = conn }

  describe "#chat" do
    context "when response is successful" do
      before do
        stubs.post("/chat") do |_env|
          [200, {"Content-Type" => "application/json"}, success_body.to_json]
        end
      end

      it "returns the parsed ChatResponse object" do
        response = subject.chat("Hello, world")

        expect(response).to be_a(ClaudeJr::ChatResponse)
        expect(response.model).to eq("llama3.2")
        expect(response.message[:content]).to eq("Hello! How are you today?")
      end
    end

    context "when response fails" do
      before do
        stubs.post("/chat") do |_env|
          [404, {"Content-Type" => "application/json"}, failure_body.to_json]
        end
      end

      it "raises APIError with an ErrorResponse" do
        expect do
          subject.chat("Hello, world", model: "invalid-model")
        end.to raise_error do |error|
          expect(error).to be_a(ClaudeJr::APIError)
          expect(error.message).to include("Model not found")
          expect(error.error_response).to be_a(ClaudeJr::ErrorResponse)
          expect(error.error_response.message).to eq("Model not found: invalid-model")
        end
      end
    end

    context "when using tools" do
      let(:tool) do
        ClaudeJr::Tool.new(
          name: "get_current_weather",
          description: "Get the current weather for a location",
          parameters: {
            type: "object",
            properties: {
              location: {
                type: "string",
                description: "The location to get the weather for"
              },
              format: {
                type: "string",
                enum: ["celsius", "fahrenheit"]
              }
            },
            required: ["location", "format"]
          }
        )
      end

      let(:tool_use_body) do
        {
          model: "llama3.2",
          created_at: "2024-07-22T20:33:28.123648Z",
          message: {
            role: "assistant",
            content: "",
            tool_calls: [
              {
                function: {
                  name: "get_current_weather",
                  arguments: {
                    format: "celsius",
                    location: "Paris, FR"
                  }
                }
              }
            ]
          },
          done: true,
          total_duration: 885095291,
          load_duration: 3753500,
          prompt_eval_count: 122,
          prompt_eval_duration: 328493000,
          eval_count: 33,
          eval_duration: 552222000
        }
      end

      before do
        stubs.post("/chat") do |env|
          body = JSON.parse(env.body)
          expect(body["tools"]).to eq([JSON.parse(tool.to_json.to_json)])
          [200, {"Content-Type" => "application/json"}, tool_use_body.to_json]
        end
      end

      it "includes tools in the request payload" do
        response = subject.chat("What's the weather?", tools: [tool])
        expect(response).to be_a(ClaudeJr::ChatResponse)
        expect(response.message[:tool_calls]).to eq([{
          function: {
            name: "get_current_weather",
            arguments: {
              format: "celsius",
              location: "Paris, FR"
            }
          }
        }])
      end
    end
  end
end
