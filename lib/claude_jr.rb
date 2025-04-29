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
    attr_accessor :api_key

    def client = Client.new(api_key: api_key)
  end

  # Connection to the Claude API
  class Client
    API_URL = "https://api.anthropic.com/v1"
    API_VERSION = "2023-06-01"
    MODEL = "claude-3-7-sonnet-20250219"
    MAX_TOKENS = 1024

    attr_accessor :connection

    def initialize(api_key:)
      @api_key = api_key
      self.connection = Faraday.new(url: API_URL) do |f|
        f.headers["x-api-key"] = @api_key
        f.headers["anthropic-version"] = API_VERSION
        f.headers["content-type"] = "application/json"
        f.request :json
        f.response :json, parser_options: {symbolize_names: true}
        f.adapter Faraday.default_adapter
      end
    end

    def chat(message, model: MODEL, max_tokens: MAX_TOKENS)
      payload = {
        model: model,
        max_tokens: max_tokens,
        messages: [
          {role: "user", content: message}
        ]
      }
      response = connection.post("messages", payload.to_json)
      unless response.success?
        error_resp = ErrorResponse.new(response.body)
        raise APIError.new("API request failed: #{error_resp.message}", error_resp)
      end

      ChatResponse.new(response.body)
    end
  end

  # Wrap successful API responses.
  class ChatResponse
    attr_reader :content, :id, :model, :role, :stop_reason, :stop_sequence, :type, :usage

    def initialize(data)
      @content = data.fetch(:content)
      @id = data.fetch(:id)
      @model = data.fetch(:model)
      @role = data.fetch(:role)
      @stop_reason = data.fetch(:stop_reason)
      @stop_sequence = data.fetch(:stop_sequence)
      @type = data.fetch(:type)
      @usage = data.fetch(:usage)
    end
  end

  # Wrap error API responses.
  class ErrorResponse
    attr_reader :message, :error_type, :type

    def initialize(data)
      error_data = data.fetch(:error, {})
      @message = error_data.fetch(:message)
      @error_type = error_data.fetch(:type)
      @type = data.fetch(:type)
    end
  end
end
