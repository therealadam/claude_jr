# frozen_string_literal: true

require "faraday"
require "json"
require_relative "claude_jr/version"

module ClaudeJr
  class Error < StandardError; end
  class APIError < Error; end

  class << self
    attr_accessor :api_key

    def client = Client.new(api_key: self.api_key)
  end

  class Client
    API_URL = "https://api.anthropic.com/v1"
    API_VERSION = "2023-06-01"
    MODEL = 'claude-3-7-sonnet-20250219'
    MAX_TOKENS = 1024

    attr_accessor :connection

    def initialize(api_key:)
      @api_key = api_key
      self.connection = Faraday.new(url: API_URL) do |f|
        f.headers["x-api-key"] = @api_key
        f.headers["anthropic-version"] = API_VERSION
        f.headers["content-type"] = "application/json"
        f.request :json
        f.response :json, parser_options: { symbolize_names: true }
        f.adapter Faraday.default_adapter
      end
    end

    def chat(message, model: MODEL, max_tokens: MAX_TOKENS)
      payload = {
        model: model,
        max_tokens: max_tokens,
        messages: [
          { role: "user", content: message }
        ]
      }
      response = connection.post("messages", payload.to_json)
      if response.success?
        response.body
      else
        raise APIError, "API request failed: #{response.body}"
      end
    end
  end
end

