---
title: "GitHub Actions: How to Automate Code Formatting in Pull Requests"
date: 2019-10-17T20:13:45+09:00
author: Peter Evans
description: "How to automatically format code and push it to the pull request branch with GitHub Actions"
keywords: ["github", "github actions", "pull request", "automation", "code formatting", "autopep8", "black", "prettier", "gofmt"]
---

Many programming languages have auto-formatting tools. The most common way to use these is client-side, either using git-hooks to format on `pre-commit`, or text editor plugins that format on save. Since they run client-side they all rely on engineers setting these tools up correctly. Failing to format before raising pull requests often means that checks will fail and corrections will need to be made. Wouldn't it be great to have automated code formatting of pull request branches.

### Automated code formatting of pull request branches

With a lot of trial and error, I discovered this is possible using an `on: pull_request` workflow in GitHub Actions. The following example uses the [autopep8](https://github.com/peter-evans/autopep8) action to format Python code.

**Important caveat 1:** Due to [limitations on forked repositories](https://help.github.com/en/github/automating-your-workflow-with-github-actions/virtual-environments-for-github-actions#token-permissions) these workflows do not work for pull requests raised from forks.

**Important caveat 2:** If you have other pull request checks besides the following workflow then you must use a [Personal Access Token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line) instead of the default `GITHUB_TOKEN`.
This is due to a deliberate limitation imposed by GitHub Actions that events raised by a workflow (such as `push`) cannot trigger further workflow runs.
This is to prevent accidental "infinite loop" situations, and as an anti-abuse measure.
Using a `repo` scoped [Personal Access Token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line) is an approved workaround. See [this GitHub issue](https://github.com/peter-evans/create-pull-request/issues/48) for further detail.

How it works:

1. When a pull request is raised the workflow executes as a check.
2. The code formatter executes and modifies files if necessary.
3. The workflow checks to see if any tracked files by git have been modified.
4. If modified files exist they are committed and pushed to the remote.
5. When using a `repo` scoped [Personal Access Token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line) instead of `GITHUB_TOKEN`, the `push` triggers all pull request checks to run again.

<div class="highlight highlight-source-yaml"><pre><span class="pl-ent">name</span>: <span class="pl-s">auto-format</span>
<span class="pl-ent">on</span>: <span class="pl-s">pull_request</span>
<span class="pl-ent">jobs</span>:
  <span class="pl-ent">format</span>:
    <span class="pl-c"><span class="pl-c">#</span> Check if the PR is not from a fork</span>
    <span class="pl-ent">if</span>: <span class="pl-s">github.event.pull_request.head.repo.full_name == github.repository</span>
    <span class="pl-ent">runs-on</span>: <span class="pl-s">ubuntu-latest</span>
    <span class="pl-ent">steps</span>:
      - <span class="pl-ent">uses</span>: <span class="pl-s">actions/checkout@v1</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">autopep8</span>
        <span class="pl-ent">uses</span>: <span class="pl-s">peter-evans/autopep8@v1.1.0</span>
        <span class="pl-ent">with</span>:
          <span class="pl-ent">args</span>: <span class="pl-s">--exit-code --recursive --in-place --aggressive --aggressive .</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Check for modified files</span>
        <span class="pl-ent">id</span>: <span class="pl-s">git-check</span>
        <span class="pl-ent">run</span>: <span class="pl-s">echo ::set-output name=modified::$(if git diff-index --quiet HEAD --; then echo "false"; else echo "true"; fi)</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Push changes</span>
        <span class="pl-ent">if</span>: <span class="pl-s">steps.git-check.outputs.modified == 'true'</span>
        <span class="pl-ent">run</span>: <span class="pl-s">|</span>
<span class="pl-s">          git config --global user.name 'Peter Evans'</span>
<span class="pl-s">          git config --global user.email 'peter-evans@users.noreply.github.com'</span>
<span class="pl-s">          git remote set-url origin https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/$GITHUB_REPOSITORY</span>
<span class="pl-s">          git checkout $GITHUB_HEAD_REF</span>
<span class="pl-s">          git commit -am "Automated changes"</span>
<span class="pl-s">          git push</span></pre></div>

### Further examples

Automated Python code formatting with [Black](https://github.com/psf/black) via [Black-action](https://github.com/lgeiger/black-action).

<div class="highlight highlight-source-yaml"><pre><span class="pl-ent">name</span>: <span class="pl-s">auto-format</span>
<span class="pl-ent">on</span>: <span class="pl-s">pull_request</span>
<span class="pl-ent">jobs</span>:
  <span class="pl-ent">format</span>:
    <span class="pl-c"><span class="pl-c">#</span> Check if the PR is not from a fork</span>
    <span class="pl-ent">if</span>: <span class="pl-s">github.event.pull_request.head.repo.full_name == github.repository</span>
    <span class="pl-ent">runs-on</span>: <span class="pl-s">ubuntu-latest</span>
    <span class="pl-ent">steps</span>:
      - <span class="pl-ent">uses</span>: <span class="pl-s">actions/checkout@v1</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">black</span>
        <span class="pl-ent">uses</span>: <span class="pl-s">lgeiger/black-action@v1.0.1</span>
        <span class="pl-ent">with</span>:
          <span class="pl-ent">args</span>: <span class="pl-s">.</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Check for modified files</span>
        <span class="pl-ent">id</span>: <span class="pl-s">git-check</span>
        <span class="pl-ent">run</span>: <span class="pl-s">echo ::set-output name=modified::$(if git diff-index --quiet HEAD --; then echo "false"; else echo "true"; fi)</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Push changes</span>
        <span class="pl-ent">if</span>: <span class="pl-s">steps.git-check.outputs.modified == 'true'</span>
        <span class="pl-ent">run</span>: <span class="pl-s">|</span>
<span class="pl-s">          git config --global user.name 'Peter Evans'</span>
<span class="pl-s">          git config --global user.email 'peter-evans@users.noreply.github.com'</span>
<span class="pl-s">          git remote set-url origin https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/$GITHUB_REPOSITORY</span>
<span class="pl-s">          git checkout $GITHUB_HEAD_REF</span>
<span class="pl-s">          git commit -am "Automated changes"</span>
<span class="pl-s">          git push</span></pre></div>

Automated Javascript code formatting with [Prettier](https://prettier.io/).

<div class="highlight highlight-source-yaml"><pre><span class="pl-ent">name</span>: <span class="pl-s">auto-format</span>
<span class="pl-ent">on</span>: <span class="pl-s">pull_request</span>
<span class="pl-ent">jobs</span>:
  <span class="pl-ent">format</span>:
    <span class="pl-c"><span class="pl-c">#</span> Check if the PR is not from a fork</span>
    <span class="pl-ent">if</span>: <span class="pl-s">github.event.pull_request.head.repo.full_name == github.repository</span>
    <span class="pl-ent">runs-on</span>: <span class="pl-s">ubuntu-latest</span>
    <span class="pl-ent">steps</span>:
      - <span class="pl-ent">uses</span>: <span class="pl-s">actions/checkout@v1</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">prettier</span>
        <span class="pl-ent">run</span>: <span class="pl-s">npx prettier --write src/**/*.js</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Check for modified files</span>
        <span class="pl-ent">id</span>: <span class="pl-s">git-check</span>
        <span class="pl-ent">run</span>: <span class="pl-s">echo ::set-output name=modified::$(if git diff-index --quiet HEAD --; then echo "false"; else echo "true"; fi)</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Push changes</span>
        <span class="pl-ent">if</span>: <span class="pl-s">steps.git-check.outputs.modified == 'true'</span>
        <span class="pl-ent">run</span>: <span class="pl-s">|</span>
<span class="pl-s">          git config --global user.name 'Peter Evans'</span>
<span class="pl-s">          git config --global user.email 'peter-evans@users.noreply.github.com'</span>
<span class="pl-s">          git remote set-url origin https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/$GITHUB_REPOSITORY</span>
<span class="pl-s">          git checkout $GITHUB_HEAD_REF</span>
<span class="pl-s">          git commit -am "Automated changes"</span>
<span class="pl-s">          git push</span></pre></div>

Automated Go code formatting with [gofmt](https://golang.org/cmd/gofmt/).

<div class="highlight highlight-source-yaml"><pre><span class="pl-ent">name</span>: <span class="pl-s">auto-format</span>
<span class="pl-ent">on</span>: <span class="pl-s">pull_request</span>
<span class="pl-ent">jobs</span>:
  <span class="pl-ent">format</span>:
    <span class="pl-c"><span class="pl-c">#</span> Check if the PR is not from a fork</span>
    <span class="pl-ent">if</span>: <span class="pl-s">github.event.pull_request.head.repo.full_name == github.repository</span>
    <span class="pl-ent">runs-on</span>: <span class="pl-s">ubuntu-latest</span>
    <span class="pl-ent">steps</span>:
      - <span class="pl-ent">uses</span>: <span class="pl-s">actions/checkout@v1</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">gofmt</span>
        <span class="pl-ent">run</span>: <span class="pl-s">gofmt -s -w .</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Check for modified files</span>
        <span class="pl-ent">id</span>: <span class="pl-s">git-check</span>
        <span class="pl-ent">run</span>: <span class="pl-s">echo ::set-output name=modified::$(if git diff-index --quiet HEAD --; then echo "false"; else echo "true"; fi)</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Push changes</span>
        <span class="pl-ent">if</span>: <span class="pl-s">steps.git-check.outputs.modified == 'true'</span>
        <span class="pl-ent">run</span>: <span class="pl-s">|</span>
<span class="pl-s">          git config --global user.name 'Peter Evans'</span>
<span class="pl-s">          git config --global user.email 'peter-evans@users.noreply.github.com'</span>
<span class="pl-s">          git remote set-url origin https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/$GITHUB_REPOSITORY</span>
<span class="pl-s">          git checkout $GITHUB_HEAD_REF</span>
<span class="pl-s">          git commit -am "Automated changes"</span>
<span class="pl-s">          git push</span></pre></div>

See the following repositories for further details and examples involving automation of pull request workflows.

- [autopep8](https://github.com/peter-evans/autopep8)
- [create-pull-request](https://github.com/peter-evans/create-pull-request)
