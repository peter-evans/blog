---
title: "Synthetic Monitoring: Building Confidence in Distributed Systems"
date: 2026-02-02T09:00:00+00:00
author: Peter Evans
description: "An introduction to synthetic monitoring and how it helps build confidence in distributed systems with low traffic"
keywords: ["synthetic monitoring", "active monitoring", "distributed systems", "observability"]
---

Tangential to my main area of responsibility at GitHub, I recently worked with another engineer on a side project to create a synthetic monitoring service. It launched this week and so I thought I would share a little about what it is, and the motivation behind it.

Let's say you've just finished deploying a new service or spun up infrastructure in a new region. The dashboards are all green. CPU utilization looks normal. Memory is fine. No errors in the logs. Everything appears healthy.

But is it actually working? :thinking:

When you have little to no real traffic flowing through a new deployment, traditional monitoring doesn't give you the full picture. Metrics can only tell you what's happening with the traffic you have. If you have no traffic, you have no signal.

### Low Traffic Challenges

Over the last couple of years, we've built GitHub in multiple regions for [GitHub Enterprise Cloud with data residency](https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/about-github-enterprise-cloud-with-data-residency). Each new region involves deploying a full stack of all of GitHub's services, databases, caches, and so on. This has brought challenges around confidence in new deployments because, initially, there is little to no user traffic in these new regions.

For many service teams, the answer to this problem has been manual verification. Someone would log in, click around, create some test data, and confirm that things seemed to work. This approach has obvious drawbacks: it's tedious, it doesn't scale, and it's prone to human error.

### Synthetic Monitoring

Synthetic monitoring (also called "active monitoring") is a technique where you simulate real user actions against your service to verify it's working correctly. Unlike passive monitoring that watches logs and metrics, synthetic monitoring actively exercises your system and verifies the results.
Think of it as having a tireless robot that continuously performs the same actions a real user would, reporting back on whether things worked and how long they took.

This concept isn't new. Companies have been using synthetic monitoring for years to verify that their public-facing websites load correctly, often running tests from multiple geographic locations to ensure global availability.

### What We Built

Our synthetic monitoring service runs a suite of tests against multiple deployment environments on a regular schedule. Each test simulates a real user workflow: creating resources, making API calls, verifying the results, and cleaning up after itself.

The tests run continuously, every few minutes, across all environments we care about. When something fails, we know about it immediately. When latency degrades, we see it in the telemetry. Most importantly, we can compare behavior across environments to spot anomalies that might otherwise go unnoticed.

We instrument every operation automatically, so engineers contributing new tests don't need to think about metrics or observability. They simply write code that exercises the functionality they care about, and the framework handles the rest. This low barrier to entry will be crucial for adoption across the organization.

### The Two-Stage Approach

One interesting challenge we encountered was testing asynchronous behavior. Many systems don't complete all their work synchronously. Background jobs run, events propagate, and downstream systems react. If you only test the synchronous response, you might miss failures that happen after the initial request returns successfully.

To address this, we structured our tests in two stages. The first stage performs the initial operations and records what it created. The second stage runs after a delay, checking that asynchronous processes completed successfully. This gives us confidence not just in the immediate response, but in the entire workflow end-to-end.

### Why This Matters

There's something deeply satisfying about transforming an anxiety-inducing question into an automated, continuous answer. "Is this environment healthy?" used to require deep investigation. Now it's a dashboard we can glance at.

Beyond the peace of mind, synthetic monitoring has proven valuable in unexpected ways. Recently, our telemetry showed elevated latency in one particular region. Before anyone could start investigating, AI-powered SRE automation had already correlated the anomaly with a scheduled failover test being run by our performance engineering team. What could have been a 30-minute investigation was resolved in seconds with a clear explanation. The synthetic monitoring data provided the signal, and AI connected the dots. :muscle:

We hope the service will also help us catch regressions earlier. Issues that might go unnoticed for hours or days in low-traffic environments should now surface within minutes. That faster feedback loop will mean faster fixes and less impact on users.

### Looking Ahead

The synthetic monitoring service is now running, continuously verifying that our systems are healthy across multiple environments. It's not a replacement for other forms of testing or monitoring, but it fills an important gap in our observability story.

If you're facing similar challenges, I'd encourage you to explore synthetic monitoring. There's nothing quite like being able to answer "Is it working?" with data instead of hope!
