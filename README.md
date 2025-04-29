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

## The prompts and processes
