# frozen_string_literal: true

require "faraday"
require "json"
require_relative "claude_jr/version"

module ClaudeJr
  class Error < StandardError; end

  # Exception wrapping an ErrorResponse
  class APIError < Error
    attr_reader :error_response

    def initialize(message, error_response)
      super(message)
      @error_response = error_response
    end
  end

  class << self
    def client = Client.new
  end

  # Value object representing an Ollama API tool
  class Tool
    attr_reader :name, :description, :parameters

    def initialize(name:, description:, parameters:)
      @name = name
      @description = description
      @parameters = parameters
    end

    def to_h
      {
        type: "function",
        function: {
          name: name,
          description: description,
          parameters: parameters
        }
      }
    end
    alias_method :to_json, :to_h
  end

  # Connection to the Ollama API
  class Client
    API_URL = "http://localhost:11434/api"
    MODEL = "llama3.2"

    attr_accessor :connection

    def initialize
      self.connection = Faraday.new(url: API_URL) do |f|
        f.headers["content-type"] = "application/json"
        f.request :json
        f.response :json, parser_options: {symbolize_names: true}
        f.adapter Faraday.default_adapter
      end
    end

    def chat(message, model: MODEL, tools: nil)
      payload = {
        model: model,
        messages: [
          {role: "user", content: message}
        ],
        stream: false
      }

      if tools&.any?
        tools_array = Array(tools)
        payload[:tools] = tools_array.map { |tool|
          tool.is_a?(Tool) ? tool.to_h : tool
        }
      end

      response = connection.post("chat", payload)

      unless response.success?
        body = response.body # : Hash[Symbol, untyped]
        error_resp = ErrorResponse.new(body)
        raise APIError.new("API request failed: #{error_resp.message}", error_resp)
      end

      body = response.body # : Hash[Symbol, untyped]
      ChatResponse.new(body)
    end
  end

  # Wrap successful API responses
  class ChatResponse
    attr_reader :model, :created_at, :message, :done, :total_duration,
      :load_duration, :prompt_eval_count, :prompt_eval_duration,
      :eval_count, :eval_duration

    def initialize(data)
      @model = data.fetch(:model)
      @created_at = data.fetch(:created_at)
      @message = parse_message(data.fetch(:message))
      @done = data.fetch(:done)
      @total_duration = data.fetch(:total_duration)
      @load_duration = data.fetch(:load_duration)
      @prompt_eval_count = data.fetch(:prompt_eval_count)
      @prompt_eval_duration = data.fetch(:prompt_eval_duration)
      @eval_count = data.fetch(:eval_count)
      @eval_duration = data.fetch(:eval_duration)
    end

    private

    def parse_message(message)
      {
        role: message.fetch(:role),
        content: message.fetch(:content),
        tool_calls: parse_tool_calls(message[:tool_calls])
      }
    end

    def parse_tool_calls(tool_calls)
      return [] unless tool_calls&.any?

      tool_calls.map do |call|
        {
          function: {
            name: call.dig(:function, :name),
            arguments: call.dig(:function, :arguments)
          }
        }
      end
    end
  end

  # Wrap error API responses
  class ErrorResponse
    attr_reader :message

    def initialize(data)
      @message = data.fetch(:error, "Unknown error")
    end
  end
end
