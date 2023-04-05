---
title: "Automating Gradle dependency updates with GitHub Actions"
date: 2020-06-05T17:34:21+09:00
author: Peter Evans
description: "How to automate Gradle dependency updates with GitHub Actions"
keywords: ["gradle", "lockfile", "dependencies", "update", "github", "github actions", "pull request", "automation"]
---

Using Gradle's [dependency locking](https://docs.gradle.org/current/userguide/dependency_locking.html) feature we can create an automated process to periodically create a pull request for dependency updates.

See an [example pull request](https://github.com/peter-evans/gradle-auto-dependency-updates/pull/2) using the method outlined in this article.

### Configuring dependency locking

1. Firstly, make sure the gradle wrapper is up to date. This is necessary in order to use the feature preview in the next step.

    ```
    gradle wrapper --gradle-version 6.5
    ```

2. Enable the `ONE_LOCKFILE_PER_PROJECT` feature preview in *settings.gradle.kts*. You can read more about this feature [here](https://docs.gradle.org/current/userguide/dependency_locking.html#single_lock_file_per_project).

    ```
    rootProject.name = "example-api"

    enableFeaturePreview("ONE_LOCKFILE_PER_PROJECT")
    ```

3. Add the following section to *build.gradle.kts* to version lock all configurations. See the [documentation here](https://docs.gradle.org/current/userguide/dependency_locking.html#enabling_locking_on_configurations) if you would like to customise this for specific configurations.

    ```
    dependencyLocking {
        lockAllConfigurations()
    }
    ```

4. **Optionally**, add the following if you would like to create a lockfile for the `buildscript` section. This can be used to version lock plugins.

    ```
    buildscript {
        repositories {
            mavenCentral()
            jcenter()
        }
        dependencies {
            classpath("com.jfrog.bintray.gradle:gradle-bintray-plugin:1.8.+")
        }
        configurations.classpath {
            resolutionStrategy.activateDependencyLocking()
        }
    }

    apply(plugin = "com.jfrog.bintray")
    ```

5. Write a `gradle.lockfile` for your current dependencies. If you followed step 4, you will also have a `buildscript-gradle.lockfile`.

    ```
    ./gradlew dependencies --write-locks
    ```

6. Check the lockfiles into source control. The lockfiles will now make sure that `./gradlew build` uses strict versions from the lockfile.

7. Specify [version ranges](https://docs.gradle.org/current/userguide/single_versions.html) for your dependencies. The range should include all versions that you are happy to accept version updates for. For example, `1.2.+` for just patch updates, `1.+` for minor updates, and `+` to include major version updates.

### Automate dependency updates

Add the following GitHub Actions workflow to periodically create a pull request containing dependency updates.
The following example uses the [create-pull-request](https://github.com/peter-evans/create-pull-request) action and executes once a week.

Note that if you want pull requests created by this action to trigger checks then a repo scoped [PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) should be used instead of the default `GITHUB_TOKEN`.
It is *highly recommended* to make sure checks run and build the new pull request in CI.
This will verify that the dependency versions in the new lockfile will build and pass tests.

<div class="highlight highlight-source-yaml"><pre><span class="pl-ent">name</span>: <span class="pl-s">Update Dependencies</span>
<span class="pl-ent">on</span>:
  <span class="pl-ent">schedule</span>:
    - <span class="pl-ent">cron</span>:  <span class="pl-s"><span class="pl-pds">'</span>0 1 * * 1<span class="pl-pds">'</span></span>
<span class="pl-ent">jobs</span>:
  <span class="pl-ent">update-dep</span>:
    <span class="pl-ent">runs-on</span>: <span class="pl-s">ubuntu-latest</span>
    <span class="pl-ent">steps</span>:
      - <span class="pl-ent">uses</span>: <span class="pl-s">actions/checkout@v3</span>
      - <span class="pl-ent">uses</span>: <span class="pl-s">actions/setup-java@v1</span>
        <span class="pl-ent">with</span>:
          <span class="pl-ent">java-version</span>: <span class="pl-c1">1.8</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Grant execute permission for gradlew</span>
        <span class="pl-ent">run</span>: <span class="pl-s">chmod +x gradlew</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Perform dependency resolution and write new lockfiles</span>
        <span class="pl-ent">run</span>: <span class="pl-s">./gradlew dependencies --write-locks</span>
      - <span class="pl-ent">name</span>: <span class="pl-s">Create Pull Request</span>
        <span class="pl-ent">uses</span>: <span class="pl-s">peter-evans/create-pull-request@v5</span>
        <span class="pl-ent">with</span>:
            <span class="pl-ent">token</span>: <span class="pl-s">${{ secrets.PAT }}</span>
            <span class="pl-ent">commit-message</span>: <span class="pl-s">Update dependencies</span>
            <span class="pl-ent">title</span>: <span class="pl-s">Update dependencies</span>
            <span class="pl-ent">body</span>: <span class="pl-s">|</span>
<span class="pl-s">              - Dependency updates</span>
<span class="pl-s"></span>  
              <span class="pl-s">Auto-generated by [create-pull-request][1]</span>
  
              <span class="pl-ent">[1]</span>: <span class="pl-s">https://github.com/peter-evans/create-pull-request</span>
            <span class="pl-ent">branch</span>: <span class="pl-s">update-dependencies</span></pre></div>

See the code in [this repository](https://github.com/peter-evans/gradle-auto-dependency-updates) for a complete example.
