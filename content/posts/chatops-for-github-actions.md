---
title: "ChatOps for GitHub Actions"
date: 2020-01-05T16:30:12+09:00
author: Peter Evans
description: "How to do slash command style ChatOps with GitHub Actions"
keywords: ["github", "github actions", "chatops", "slash command", "pull requests", "issues", "issue comment", "slash-command-dispatch"]
---

["ChatOps"](https://www.pagerduty.com/blog/what-is-chatops/) is a term widely credited to GitHub, referring to the practice of performing operations by typing commands in chat messaging applications.

While GitHub Actions has many ways to trigger workflows based on events that occur in a repository, it doesn't have a particularly straightforward way to manually trigger a workflow.

### Manually triggering workflows

You *can* trigger workflows manually by configuring them to listen for the [`repository_dispatch`](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/events-that-trigger-workflows#external-events-repository_dispatch) event, and then sending a call to the GitHub API. I found myself using this method a lot to test actions I was developing. The main problem with this was the awkwardness of calling the API using curl.

Another way to trigger workflows is to configure a workflow on the [`issue_comment`](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/events-that-trigger-workflows#issue-comment-event-issue_comment) event and parse slash commands from the comments. However, in repositories with a lot of activity, the workflow queue gets backed up very quickly trying to handle new `issue_comment` events *and* process the commands themselves.

I wanted to develop something that was a combination of these two methods.

### Slash Command Dispatch

[Slash Command Dispatch](https://github.com/peter-evans/slash-command-dispatch) is a GitHub action that facilitates "ChatOps" by creating repository dispatch events for slash commands. 

The action runs in `issue_comment` event workflows and checks comments for slash commands. When a valid command is found it creates a repository dispatch event that includes a payload containing full details of the command and its context.

Dispatching commands to be processed elsewhere keeps the workflow queue moving quickly and essentially enables parallel processing of workflows.

<img src="/img/slash-command-dispatch.png" alt="Slash Command Dispatch" width="550">

### Demos

See the [demos section](https://github.com/peter-evans/slash-command-dispatch#demos) of the [slash-command-dispatch](https://github.com/peter-evans/slash-command-dispatch) README for a number of live demos.

### Getting started

Follow this guide to get started with a working `/example` command.

#### Command processing setup

1. Create a new repository called, for example, `slash-command-processor`.
   This will be the repository that commands are dispatched to for processing.

2. In your new repository, create the following workflow at `.github/workflows/example-command.yml`.

    <div class="highlight highlight-source-yaml"><pre><span class="pl-ent">name</span>: <span class="pl-s">example-command</span>
    <span class="pl-ent">on</span>:
      <span class="pl-ent">repository_dispatch</span>:
        <span class="pl-ent">types</span>: <span class="pl-s">[example-command]</span>
    <span class="pl-ent">jobs</span>:
      <span class="pl-ent">example</span>:
        <span class="pl-ent">runs-on</span>: <span class="pl-s">ubuntu-latest</span>
        <span class="pl-ent">steps</span>:
          - <span class="pl-ent">name</span>: <span class="pl-s">Add reaction</span>
            <span class="pl-ent">uses</span>: <span class="pl-s">peter-evans/create-or-update-comment@v1</span>
            <span class="pl-ent">with</span>:
              <span class="pl-ent">token</span>: <span class="pl-s">${{ secrets.REPO_ACCESS_TOKEN }}</span>
              <span class="pl-ent">repository</span>: <span class="pl-s">${{ github.event.client_payload.github.payload.repository.full_name }}</span>
              <span class="pl-ent">comment-id</span>: <span class="pl-s">${{ github.event.client_payload.github.payload.comment.id }}</span>
              <span class="pl-ent">reaction-type</span>: <span class="pl-s">hooray</span></pre></div>

3. Create a `repo` scoped Personal Access Token (PAT) by following [this guide](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line).

4. Go to your repository `Settings` -> `Secrets` and `Add a new secret`.

    **Name**: `REPO_ACCESS_TOKEN`

    **Value**: (The PAT created in step 3)

Command processing setup is complete! Now we need to setup command dispatch for our `/example` command.

#### Command dispatch setup

1. Choose a repository or create a new repository to dispatch commands from.
   This will be the repository where issue and pull request comments will be monitored for slash commands.

    In the repository, create the following workflow at `.github/workflows/slash-command-dispatch.yml`.

    **Note**: Change `your-github-username/slash-command-processor` to reference your command processor repository created in the [previous section](#command-processing-setup).

    <div class="highlight highlight-source-yaml"><pre><span class="pl-ent">name</span>: <span class="pl-s">Slash Command Dispatch</span>
    <span class="pl-ent">on</span>:
      <span class="pl-ent">issue_comment</span>:
        <span class="pl-ent">types</span>: <span class="pl-s">[created]</span>
    <span class="pl-ent">jobs</span>:
      <span class="pl-ent">slashCommandDispatch</span>:
        <span class="pl-ent">runs-on</span>: <span class="pl-s">ubuntu-latest</span>
        <span class="pl-ent">steps</span>:
          - <span class="pl-ent">name</span>: <span class="pl-s">Slash Command Dispatch</span>
            <span class="pl-ent">uses</span>: <span class="pl-s">peter-evans/slash-command-dispatch@v1</span>
            <span class="pl-ent">with</span>:
              <span class="pl-ent">token</span>: <span class="pl-s">${{ secrets.REPO_ACCESS_TOKEN }}</span>
              <span class="pl-ent">commands</span>: <span class="pl-s">example</span>
              <span class="pl-ent">repository</span>: <span class="pl-s">your-github-username/slash-command-processor</span></pre></div>

2. Create a new `repo` scoped [PAT](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line), OR, use the one created at step 3 of the [previous section](#command-processing-setup).

3. Go to your repository `Settings` -> `Secrets` and `Add a new secret`.

    **Name**: `REPO_ACCESS_TOKEN`

    **Value**: (The PAT created in step 2)

Command dispatch setup is complete! Now let's test our `/example` command.

#### Testing the command

1. Create a new GitHub Issue in the repository you chose to dispatch commands from.

2. Add a new comment with the text `/example`.

Once the command completes you should see all three reactions on your comment.

<img src="/img/example-command.png" alt="Example Command">

Now you can start to tweak the command and make it do something useful!
