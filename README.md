# Claude, Jr.

<!-- TOC -->
* [Claude, Jr.](#claude-jr)
  * [Ground rules](#ground-rules)
  * [The prompts and processes](#the-prompts-and-processes)
<!-- TOC -->

A proof-of-concept for building out dependencies with LLM instead of supply chains.

## Ground rules

- Pretend we are in an application already using Faraday.
- No other library dependencies are allowed.
- All LLM-generated code must lint cleanly and pass tests.
- Code should pass the sniff test:
  - Any developer should be expected to change the code _by hand_ if desired
  - Or, ask an LLM to update the code in a future session
  - We should be able to wholesale replace this code (and its callsites) in a day or so

## 1. A baseline HTTP client

Build me a basic Ruby integration with the Claude API. Use the Faraday Ruby library for HTTP interactions. Here's how to call the API via curl:

```
curl https://api.anthropic.com/v1/messages \
--header "x-api-key: $ANTHROPIC_API_KEY" \
--header "anthropic-version: 2023-06-01" \
--header "content-type: application/json" \
--data \
'{
"model": "claude-3-7-sonnet-20250219",
"max_tokens": 1024,
"messages": [
{"role": "user", "content": "Hello, world"}
]
}'
```

This yields a sufficient-looking client. Entirely up to Ruby community standards for splitting up files.
I'm swimming somewhat upstream by inlining all the logic in one file though. We'll see if that continues to annoy me.

Same sort of thing when I asked to generate a tests. I wanted to avoid pulling in VCR, but also don't want to pay for API calls every test run. On the upside, o3-mini used `Faraday::Adapter::Test::Stubs` to define test matchers. TIL! On the downside, it was slightly wrong in its usage (assumed the base URL specified in the client would convey to test stubs). A bit of tweaking fixed this.

So far, so good. Very much the "pairing with very fast but mostly wrong junior dev" experience.
