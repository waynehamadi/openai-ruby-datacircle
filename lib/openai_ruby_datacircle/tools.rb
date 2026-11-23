# frozen_string_literal: true

module OpenAI
  module Datacircle
    LIST_APIS = 'datacircle_list_apis'
    BEST_PLANS = 'datacircle_best_plans'
    SEARCH_PLANS = 'datacircle_search_plans'
    PROVIDER = 'datacircle_provider'

    # The four tools' names, in the order Tools#tools gives them.
    NAMES = [LIST_APIS, BEST_PLANS, SEARCH_PLANS, PROVIDER].freeze

    # The four tools for client.chat.completions (create, stream and run_tools) and client.responses (create and
    # stream), and the run of the calls the model makes.
    #
    #   datacircle = OpenAI::Datacircle::Tools.new
    #   completion = client.chat.completions.create(model: ..., messages: messages, tools: datacircle.tools)
    #   message = completion.choices.first.message
    #   messages << message
    #   message.tool_calls.to_a.each { |tool_call| messages << datacircle.call(tool_call) }
    #
    # It holds no state: one can serve many threads.
    class Tools
      ABOUT = {
        LIST_APIS => "Lists the GTM APIs on Datacircle's sheet (https://datacircle.dev), with each API's slug, how many " \
                     "plans and providers it has and its best plan. Call it first to find an API's slug.",
        BEST_PLANS => "Gives an API's plans best first by their score out of 100 on Datacircle's benchmark " \
                      '(https://datacircle.dev), each with its rank, provider, plan, $ per 1,000 calls and its page. ' \
                      "#{PRICE}",
        SEARCH_PLANS => "Searches every plan on Datacircle's sheet (https://datacircle.dev), or one API's, by provider " \
                        'or plan name, sorted by score, provider or price. Gives how many were found and up to limit ' \
                        "of them. #{PRICE}",
        PROVIDER => "Gives each API one provider sells and its rank on each on Datacircle's benchmark " \
                    '(https://datacircle.dev), with its best plan there, its best rank first. total is how many APIs ' \
                    'it sells, ranked on how many of them it has a rank.'
      }.freeze

      PARAMETERS = {
        LIST_APIS => {
          'query' => { 'type' => 'string', 'description' => "Words of the API's name or slug, like email or linkedin " \
                                                              'profile: the APIs that hold the most of them come ' \
                                                              "first. The sheet's order when left out." },
          'limit' => { 'type' => 'integer', 'minimum' => 1, 'maximum' => 200,
                       'description' => 'How many APIs to give, 1 to 200. 20 when left out: the sheet has about 150.' }
        },
        BEST_PLANS => {
          'slug' => { 'type' => 'string', 'description' => "The API's slug, like email-finder or linkedin-profile, as " \
                                                             'datacircle_list_apis gives it.' },
          'limit' => { 'type' => 'integer', 'minimum' => 1, 'maximum' => 50,
                       'description' => 'How many plans to give, 1 to 50. 10 when left out.' }
        },
        SEARCH_PLANS => {
          'query' => { 'type' => 'string', 'description' => "Words that must all appear in the provider's or plan's " \
                                                              'name, like bright data.' },
          'api' => { 'type' => 'string', 'description' => "Only this API's plans: its name or slug, like email-finder. " \
                                                            "A provider's name goes in query, never here. Every API " \
                                                            'when left out.' },
          'sort' => { 'type' => 'string', 'enum' => %w[score provider price],
                      'description' => 'score (best first, the default), provider (A to Z) or price ($ per 1,000, ' \
                                       'lowest first).' },
          'limit' => { 'type' => 'integer', 'minimum' => 1, 'maximum' => 50,
                       'description' => 'How many plans to give, 1 to 50. 10 when left out.' },
          'offset' => { 'type' => 'integer', 'minimum' => 0,
                        'description' => 'How many found plans to skip first. 0 when left out.' }
        },
        PROVIDER => {
          'slug' => { 'type' => 'string', 'description' => "The provider's slug, like bright-data, or its name, like " \
                                                             'Bright Data: the name is made a slug.' }
        }
      }.freeze

      REQUIRED = { BEST_PLANS => ['slug'], PROVIDER => ['slug'] }.freeze

      # base_url: where the tools call, https://api.datacircle.dev/v1 when left out.
      def initialize(base_url: nil)
        @base_url = base_url || Client::BASE
      end

      # The four tools for a chat completion's tools: (create, stream and run_tools), each a function tool.
      def tools
        NAMES.map { |name| { type: :function, function: function(name) } }
      end

      # The four tools for a response's tools: (client.responses.create and stream), each a function tool.
      def response_tools
        NAMES.map { |name| { type: :function, **function(name), strict: false } }
      end

      # The four tools' handlers for run_tools' tool_handlers:, by name. Each takes the model's arguments and gives the
      # answer as JSON text, {"error": ...} when the API gives no data, so that the run goes on.
      def handlers
        NAMES.to_h { |name| [name, ->(arguments) { output(name, arguments) }] }
      end

      # Whether name is one of the four tools'.
      def handles?(name)
        NAMES.include?(name.to_s)
      end

      # The tool message that answers a tool call of a chat completion's message (message.tool_calls), to add to the
      # messages after the message; nil for a call of a tool that isn't one of the four, which you run yourself.
      def call(tool_call)
        function = value(tool_call, :function)
        name = value(function, :name)
        return nil unless handles?(name)

        { role: :tool, tool_call_id: value(tool_call, :id), content: output(name, value(function, :arguments)) }
      end

      # A function_call_output item for each call of the four tools in a response (or its output), to add to the next
      # request's input. A call of another function gets none: you run it yourself.
      def outputs(response)
        items = response.is_a?(Array) ? response : Array(value(response, :output))
        items.filter_map do |item|
          next unless value(item, :type).to_s == 'function_call' && handles?(value(item, :name))

          { type: :function_call_output, call_id: value(item, :call_id),
            output: output(value(item, :name), value(item, :arguments)) }
        end
      end

      # The answer of one tool to the model's arguments (a JSON object, as text or a Hash), as JSON text. Raises Error
      # with words for the model when the API gives no data, the arguments can't be read or the tool is not one of the
      # four. Keys the tool doesn't take are dropped, a number sent as text is read, one out of range is brought into it.
      def run(name, arguments = nil)
        raise Error, "No tool is named #{name.to_s.inspect}: the tools are #{NAMES.join(', ')}" unless handles?(name)

        found = answer(name.to_s, read(arguments))
        raise Error, found['error'] if found.keys == ['error']

        JSON.generate(found)
      end

      # The answer the model reads: run's JSON, or {"error": ...} with words it can act on.
      def output(name, arguments)
        run(name, arguments)
      rescue Error => e
        JSON.generate('error' => e.message)
      end

      private

      def function(name)
        parameters = { 'type' => 'object', 'properties' => PARAMETERS[name] }
        parameters['required'] = REQUIRED[name] if REQUIRED.key?(name)
        { name: name, description: ABOUT[name], parameters: parameters }
      end

      def answer(name, given)
        calls = Calls.new(base_url: @base_url)
        case name
        when LIST_APIS then calls.list_apis(**pick(given, :query, :limit))
        when BEST_PLANS then calls.best_plans(**pick(given, :slug, :limit))
        when SEARCH_PLANS then calls.search_plans(**pick(given, :query, :api, :sort, :limit, :offset))
        when PROVIDER then calls.provider(**pick(given, :slug))
        end
      end

      def pick(given, *keys)
        keys.each_with_object({}) { |key, kept| kept[key] = given[key.to_s] unless given[key.to_s].nil? }
      end

      # The model's arguments as a Hash of strings: none is {}, and text that is no JSON object is an Error.
      def read(arguments)
        given = arguments.is_a?(String) ? JSON.parse(arguments.strip.empty? ? '{}' : arguments) : arguments || {}
        raise Error, "The arguments are no JSON object of this tool's parameters" unless given.is_a?(Hash)

        given.to_h { |key, item| [key.to_s, item] }
      rescue JSON::ParserError
        raise Error, "The arguments are no JSON object of this tool's parameters"
      end

      # A field of what the SDK gives (a model, like OpenAI::Chat::ChatCompletionMessageFunctionToolCall) or of a Hash
      # an app writes (symbol or string keys).
      def value(item, key)
        item = item.to_h if !item.is_a?(Hash) && !item.is_a?(Array) && item.respond_to?(:to_h)
        return nil unless item.is_a?(Hash)

        item.key?(key) ? item[key] : item[key.to_s]
      end
    end
  end
end
