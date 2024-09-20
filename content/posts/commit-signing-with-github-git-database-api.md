---
title: "Commit signing with GitHub's Git database API"
date: 2024-09-20T16:23:32+01:00
author: Peter Evans
description: "How to sign commits with GitHub's Git database REST API"
keywords: ["git", "github", "commit", "signing", "verified", "api"]
---

[Commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification) is a feature where GitHub will mark signed commits as "verified" to give confidence that changes are from a trusted source. Some organizations require commit signing, and enforce it with branch protection rules.

In a recent major version update of [create-pull-request](https://github.com/peter-evans/create-pull-request), I added the ability to have commits signed with bot-generated tokens.
You can read about this feature and its token requirements [here](https://github.com/peter-evans/create-pull-request/blob/main/docs/concepts-guidelines.md#commit-signature-verification-for-bots).

In this post I want to touch on some of the technical aspects of implementing this feature using GitHub's [REST API endpoints for Git database](https://docs.github.com/en/rest/git?apiVersion=2022-11-28).
There are plenty of articles that deal with the basics of using this API.
So, instead, I want to highlight some edge cases and considerations for delivering a well-rounded implementation.

### Payload limits

The API has a 40MiB payload limit, which I think applies to all the endpoints, although you are only likely to notice it when creating large git blobs or trees.
As of writing, this limit is not officially documented.

For blobs, it means that the size of a single file cannot exceed the limit.
If you need to support files larger than the limit, then unfortunately, the Git database API cannot be used.

If you hit the limit when creating a large tree, you can modify the implementation to create a tree in multiple parts.
Chunk the tree objects and create a tree per chunk in a chain, each referencing the previous.

```typescript
  // Chunk the tree objects
  const chunkSize = 100
  const chunkedTreeObjects: TreeObject[][] = Array.from(
    {length: Math.ceil(treeObjects.length / chunkSize)},
    (_, i) => treeObjects.slice(i * chunkSize, i * chunkSize + chunkSize)
  )

  // Create a tree per chunk where the base_tree references the previous chunk
  let treeSha = parentCommit.tree
  for (let i = 0; i < chunkedTreeObjects.length; i++) {
    const {data: tree} = await this.octokit.rest.git.createTree({
      owner,
      repo
      base_tree: treeSha,
      tree: chunkedTreeObjects[i]
    })
    treeSha = tree.sha
  }
```

### Rate limits

For most implementations it will probably make sense to implement blob creation with concurrency.
Trees with a large number of blobs could take a long time to process in series.
The key to doing this well is to deliberately slow calls enough to not hit GitHub's rate limits.

There are many ways this could be done, depending on your language and/or framework.

```typescript
  import pLimit from 'p-limit'

  // Limit async task concurrency for blob creation to 10
  const blobCreationLimit = pLimit(10)
  const treeObjects = await Promise.all(
    commit.changes.map(async ({path, mode, content}) => {
        const {data: blob} = await blobCreationLimit(() =>
          this.octokit.rest.git.createBlob({
            owner,
            repo,
            content,
            encoding: 'base64'
          })
        )
        return <TreeObject>{
          path,
          mode,
          sha: blob.sha,
          type: 'blob'
        }
    })
  )
```

### Empty commits

For some implementations it may be necessary to handle the creation of empty commits.
This can be done by setting the `tree` to the parent commit's tree.

```typescript
  // In the case of an empty commit, the tree references the parent's tree
  let treeSha = parentCommit.tree

  const {data: commit} = await this.octokit.rest.git.createCommit({
    owner,
    repo,
    parents: [parentCommit.sha],
    tree: treeSha,
    message: commitMessage
  })
```

### Submodules

To create commits containing changes to a submodules' commit SHA, create a tree object with type `commit`.

```typescript
  return <TreeObject>{
    path,
    mode: '160000',
    sha: submoduleCommitSha,
    type: 'commit'
  }
```

### Symlinks

To handle changes to symlinks, create a blob and make sure to read the symlink's link.
An easy coding mistake would be for the file IO code to follow the symlink path and read the content of the target.

```typescript
  const content = fs.readlinkSync(path, {encoding: 'buffer'}).toString('base64')

  const {data: blob} = this.octokit.rest.git.createBlob({
    owner,
    repo
    content,
    encoding: 'base64'
  })
```

### Complete example

That wraps up some of the edge cases I experienced when working on my own implementation.
Check out [create-pull-request](https://github.com/peter-evans/create-pull-request) for the full source code of the snippets.
