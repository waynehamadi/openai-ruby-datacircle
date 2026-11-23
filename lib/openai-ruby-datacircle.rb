# frozen_string_literal: true

require 'json'
require 'openai'
require_relative 'openai_ruby_datacircle/version'
require_relative 'openai_ruby_datacircle/client'
require_relative 'openai_ruby_datacircle/calls'
require_relative 'openai_ruby_datacircle/tools'

module OpenAI
  # Datacircle's open API as four function tools for the official openai gem, with no key: find the best GTM APIs. We
  # benchmark all the GTM APIs and we put the results on our website, https://datacircle.dev
  #
  #   datacircle = OpenAI::Datacircle::Tools.new
  #   client.chat.completions.run_tools(model: ..., messages: [...], tools: datacircle.tools,
  #                                     tool_handlers: datacircle.handlers)
  #
  # datacircle_list_apis, datacircle_best_plans, datacircle_search_plans and datacircle_provider make one GET of
  # https://api.datacircle.dev/v1 each. Tools#call runs a chat tool call into its tool message, Tools#outputs a
  # response's function calls into function_call_output items. The API's error, or why it could not be reached, goes to
  # the model as {"error": ...}.
  module Datacircle
  end
end
