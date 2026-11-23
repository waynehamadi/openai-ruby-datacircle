# Datacircle tools for the OpenAI Ruby SDK

Find the best GTM APIs. We benchmark all the GTM APIs and we put the results on our website.

Our website: https://datacircle.dev

This gem gives the official [OpenAI Ruby SDK](https://github.com/openai/openai-ruby) (the `openai` gem) four function tools that call Datacircle's open API, https://api.datacircle.dev/v1. They work with `client.chat.completions` and `client.responses`. You need no key and no account for our API.

| Tool | What the tool gives | Call |
| --- | --- | --- |
| `datacircle_list_apis` | Every GTM API on Datacircle, with the API's slug, number of plans, number of providers and best plan | `GET /apis` |
| `datacircle_best_plans` | One API's plans, sorted by score out of 100, best first. Each plan comes with a rank and a price per 1,000 calls | `GET /apis/{slug}/best` |
| `datacircle_search_plans` | Plans that match a provider or plan name, on all APIs or on one API. You can sort them by score, provider or price | `GET /plans` |
| `datacircle_provider` | The APIs a provider sells, and the provider's rank on each API | `GET /providers/{slug}` |

## Install

```bash
bundle add openai-ruby-datacircle
```

The gem needs the `openai` gem 0.9.0 or later and Ruby 3.2 or later. `run_tools` needs `openai` 0.108.0 or later.

## Use the tools with run_tools

`client.chat.completions.run_tools` runs the tool calls for you:

```ruby
require "openai"
require "openai-ruby-datacircle"

client = OpenAI::Client.new
datacircle = OpenAI::Datacircle::Tools.new

completion = client.chat.completions.run_tools(
  model: "gpt-5.2",
  messages: [{role: :user, content: "Who are the 3 best providers for the email-finder API?"}],
  tools: datacircle.tools,
  tool_handlers: datacircle.handlers
)
puts completion.choices.first.message.content
```

You can list our tools beside your own: `tools: [*datacircle.tools, my_tool]` and `tool_handlers: datacircle.handlers.merge("my_tool" => my_handler)`.

## Run the calls yourself

With `chat.completions.create`, add the model's message to the messages. Then add a tool message for each tool call:

```ruby
messages = [{role: :user, content: "Which APIs does Bright Data sell, and where does it rank on each?"}]

loop do
  message = client.chat.completions.create(model: "gpt-5.2", messages: messages, tools: datacircle.tools).choices.first.message
  messages << message
  if message.tool_calls.to_a.empty?
    puts message.content
    break
  end

  message.tool_calls.each { |tool_call| messages << datacircle.call(tool_call) }
end
```

`datacircle.call` gives `nil` for a call of a tool that isn't ours. You run that call yourself. `chat.completions.stream` works the same way: call `call` on each tool call of `stream.get_final_completion`.

## The Responses API

Give `datacircle.response_tools` to `client.responses.create`. `datacircle.outputs(response)` gives a `function_call_output` item for each call of our tools:

```ruby
input = [{role: :user, content: "What are Bright Data's cheapest plans?"}]

loop do
  response = client.responses.create(model: "gpt-5.2", input: input, tools: datacircle.response_tools)
  outputs = datacircle.outputs(response)
  if outputs.empty?
    puts response.output_text
    break
  end

  input += response.output + outputs
end
```

You can also send only the outputs, with `previous_response_id: response.id`. `client.responses.stream` works the same way: call `outputs` on `stream.get_final_response`.

## Make each call yourself

You can call a tool without a model and read the JSON answer:

```ruby
datacircle.run("datacircle_best_plans", {slug: "email-finder", limit: 3})
# => "{\"api\":\"Employee email\",\"slug\":\"email-finder\",...,\"plans\":[{\"api\":\"Employee email\",\"rank\":1,\"provider\":\"Emelia\",...}]}"
```

`OpenAI::Datacircle::Calls.new` makes the same calls and gives you a Hash. The methods of `Calls` are `list_apis`, `best_plans`, `search_plans` and `provider`.

## What the model reads

Each tool gives the model a JSON object as text. Each plan comes with a rank, provider, plan, score, price per 1,000 (`perThousand`, in dollars) and a page on datacircle.dev. That page lists every field.

When the API gives no data, for example for an unknown slug, the model reads `{"error": "..."}` with the API's message. It reads the same for a network error. The model can then call the tool again. The run keeps going. `run` raises `OpenAI::Datacircle::Error` instead.

`OpenAI::Datacircle::Tools.new(base_url: ...)` sets a new address for the tools, for example a proxy of yours. Leave `base_url` out and the tools call https://api.datacircle.dev/v1.

## Network

Each tool call makes one HTTPS GET request to https://api.datacircle.dev/v1. A tool makes two requests when the model gives a name instead of a slug. A tool also makes two when the model gives a provider instead of an API. A request holds the tool's own arguments and nothing else: no key and nothing from your chats. The API takes up to 60 calls a minute from one IP address. A tool waits once, for a minute at most, when the API asks for a wait. The gem depends only on `openai` and stores nothing.

## Links

- Datacircle: https://datacircle.dev
- The API: https://datacircle.dev/api
- The API's spec: https://api.datacircle.dev/v1/openapi.json
- What each key means: https://datacircle.dev/fields

MIT license.
