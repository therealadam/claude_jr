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

## Introduce response objects

Again, Copilot (o3-mini is working really well at the time of writing; I'd rather use Sonnet-3.5 but that frequently errors out mysteriously in Copilot) is pretty adept at taking cURL examples from Anthropic's API docs and generating Ruby code and tests.

I ended up taking a pomo or two to put backstops in place. Namely, I made sure that lint checks (standard.rb), tests, and steep type checking all pass. Some of this was implemented by Copilot, namely the RBS types. But the larger goal here was my own, applying my own aesthetic and a bit of creativity to the project. This is a thing LLMs are good at _supporting_. I'm setting a direction and giving them computer constraints. Occassinally, I ask it how to implement them. 

Computers should do the work so people can do the thinking!

TK ...commentary on writing and refactoring tests along the way?

## Add tool usage

The key to most LLM-assisted development is taking small, manageable steps. And, not telling the Copilot too much in advance, lest it tries to solve everything in one turn and goes a little wild. Again, it's like working with an overzealous junior developer whose eyes are bigger than their stomach, per se.

First, pass the tools parameter in API requests, verbatim. Pasting in sample input or output as part of the prompt helps _a lot_. Pretty easy for the LLM. Given a context with the source file, types, and tests, it made appropriate changes to each.

Second, implement helpers to generate the tools parameter JSON/schema. Writing the code looks alright here. But, Copilot got itself turned around providing exhaustive test cases here. 

Third, parse tool responses and invoke a method. Again, providing sample JSON or `curl` inputs goes a long way! As does having a default `rake` task that verifies all the changes.

Another RBS + Steep side-quest: I gained a _lot_ of `steep:ignore` magic comments on this one. Not sure if the tool isn't working for me or if I'm using the tool wrong. 🙃

## TK Adapt to Ollama API
