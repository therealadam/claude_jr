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

  # Value object representing a Claude API tool
  class Tool
    attr_reader :name, :description, :input_schema

    def initialize(name:, description:, input_schema:)
      @name = name
      @description = description
      @input_schema = input_schema
    end

    def to_h
      {
        name: name,
        description: description,
        input_schema: input_schema
      }
    end
    alias_method :to_json, :to_h
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

    def chat(message, model: MODEL, max_tokens: MAX_TOKENS, tools: []) # steep:ignore
      payload = {
        model: model,
        max_tokens: max_tokens,
        messages: [
          {role: "user", content: message}
        ]
      }
      if tools.any?
        payload[:tools] = tools.map(&:to_h)
      end

      response = connection.post("messages", payload)

      unless response.success?
        error_resp = ErrorResponse.new(response.body)
        raise APIError.new("API request failed: #{error_resp.message}", error_resp)
      end

      ChatResponse.new(response.body) # steep:ignore
    end
  end

  # Wrap successful API responses.
  class ChatResponse
    attr_reader :content, :id, :model, :role, :stop_reason, :stop_sequence, :type, :usage

    def initialize(data)
      @content = parse_content(data.fetch(:content))
      @id = data.fetch(:id)
      @model = data.fetch(:model)
      @role = data.fetch(:role)
      @stop_reason = data.fetch(:stop_reason)
      @stop_sequence = data.fetch(:stop_sequence)
      @type = data.fetch(:type)
      @usage = data.fetch(:usage)
    end

    private

    def parse_content(content)
      return content unless content.is_a?(Array) # steep:ignore

      content.map do |item| # steep:ignore
        case item
        when Hash
          case item[:type]
          when "text"
            {type: "text", text: item[:text]}
          when "tool_use"
            {
              type: "tool_use",
              id: item[:id],
              name: item[:name],
              input: item[:input]
            }
          else
            item # Pass through unknown content types
          end
        else
          item # Pass through non-Hash content
        end
      end
    end
  end

  # Wrap error API responses.
  class ErrorResponse
    attr_reader :message, :error_type, :type

    def initialize(data) # steep:ignore
      error_data = data.fetch(:error, {}) # steep:ignore
      @message = error_data.fetch(:message)
      @error_type = error_data.fetch(:type)
      @type = data.fetch(:type)
    end
  end
end
