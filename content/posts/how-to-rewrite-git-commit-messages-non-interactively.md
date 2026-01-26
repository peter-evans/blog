---
title: "How to rewrite Git commit messages non-interactively"
date: 2023-11-08T11:23:13
author: Peter Evans
description: "How to rewrite Git commit messages without interactive commands"
keywords: ["git", "commit", "message", "rewrite", "change", "interactive", "rebase"]
---

I had a situation recently where I needed to rewrite the first commit message of a pull request branch, but I couldn't use interactive commands because it was going to be automated in a workflow.

To explain the use case more fully, I was writing a GitHub Actions workflow that automatically creates a Jira issue for a pull request. The Jira issue key is then added to the pull request title. In addition, I also wanted to rewrite the first commit message of the pull request branch to include the Jira issue key. This associates it correctly with the Jira issue and allows the commits to be linked to from Jira.

### Rewriting Git commit messages

It turns out that there are a number of ways to rewrite Git commit messages, but all of them seem to require interactive commands like `git rebase -i` or `git commit --amend`. Eventually I found a promising solution in [this Stackoverflow answer](https://stackoverflow.com/a/76797054/11934042).🔍 It emulates the behaviour of the interactive command `git commit --fixup=reword:<commit_hash>` to make it non-interactive.

The solution they outlined uses a git alias to rewrite the commit message non-interactively. I picked it apart into separate commands that can be run in a script or GitHub Actions workflow.

```bash
    NEWLINE=$'\n'
    amend_message="amend! $commit_hash${NEWLINE}${NEWLINE}$new_commit_message"

    git config --global user.email "${{ github.actor_id }}+${{ github.actor }}@users.noreply.github.com"
    git config --global user.name "${{ github.actor }}"

    git commit --allow-empty --only -m "$amend_message"
    GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash "$commit_hash^"
    git push --force-with-lease
```

**Notes:**

- The snippet above assumes two variables are set. The `commit_hash` of the commit to rewrite, and `new_commit_message` containing the string to replace the commit message with.
- Getting the newlines to correctly render in the `amend!` message is tricky. Those lines are very deliberate to make sure the amend commit message is formatted correctly. This includes the double quotes around `$amend_message` in the `git commit` command.
- The lines setting the user with `git config` include GitHub Actions context variables. Replace these if you are running the script elsewhere.
