---
title: "Lightweight Architecture Decision Records"
date: 2018-05-24T15:47:59+09:00
author: Peter Evans
description: "Lightweight Architecture Decision Records"
keywords: ["lightweight", "architecture", "decision", "records", "software documentation", "markdown"]
---


>__*"Lightweight Architecture Decision Records is a technique for capturing important architectural decisions along with their context and consequences."*__

— ["Lightweight Architecture Decision Records", ThoughtWorks Technology Radar](https://www.thoughtworks.com/radar/techniques/lightweight-architecture-decision-records)


### Making architecture and design decisions

In my experience architecture decisions are often made verbally while gathered around a whiteboard.
This is a great way to hash out the design while you’re still exploring the architecture.
However, if no record of that process is made six months later most people will be hard pressed to remember the full context and reason why decisions were made and important details will be forgotten.

When joining a team with established systems and software it's often very easy to criticise the way it was designed.
However, those decisions may well have been the best course of action given the context and constraints at the time.
Documenting these architecture and design decisions and the context they were made in can be a valuable record for future team members and external oversight.

These days many teams favour highly readable code and tests rather than writing extensive documentation.
Few engineers enjoy writing documentation so what is the minimum we need to document to maintain an effective record of architecture decisions?


### Lightweight Architecture Decision Records

The idea of recording architecture decisions has been written about in various forms for a while, but a version was proposed in [this excellent blog post](http://thinkrelevance.com/blog/2011/11/15/documenting-architecture-decisions) by Michael Nygard.

>*"An architecture decision record is a short text file in a format similar to an Alexandrian pattern that describes a set of forces and a single decision in response to those forces."*

He proposes a short document with just five sections:

- Title
- Context
- Decision
- Status [Proposed, Accepted, Deprecated, Superseded]
- Consequences

The beauty of this format is its simplicity.
It requires very little training and even engineers skeptical of the value of recording architecture decisions will be able to accept the low effort required.

Here is an example template.
```
# 1. Title

## Status

[Proposed, Accepted, Deprecated, Superseded]

## Context

## Decision

## Consequences
```


### Tips for using Lightweight Architecture Decision Records

- Use markdown and store along with the component it relates to in source control
- Number the files sequentially
- Keep it brief and use plain, easy to understand language
- Peer review as you would code
- For cross cutting decisions that affect multiple components consider making a separate "architecture" repository
- When you make a decision document it immediately!


### Real-world example

This is a real-world example of using Lightweight Architecture Decision Records by [GOV.UK](https://www.gov.uk/) for their migration to AWS.
https://github.com/alphagov/govuk-aws/tree/master/docs/architecture/decisions
