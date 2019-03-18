---
title: "Smoke Testing Containers"
date: 2019-03-14T21:18:44+09:00
author: Peter Evans
description: "Smoke testing Docker containers with CircleCI"
tags: ["smoke testing", "docker", "containers", "circleci", "curl", "dockerize", "postman"]
---

Smoke testing is a class of testing designed to determine if something is ready for more rigorous testing. The terminology appears to have [originated from plumbing](https://en.wikipedia.org/wiki/Smoke_testing_(mechanical)) where smoke is used to test for leaks in a closed system of pipes. It also seems to be widely used in electronics to refer to the practice of turning on a new piece of hardware for the first time and considering it a success if none of the components overheat and start to smoke.

<img src="/img/smoking-circuit-board.jpg" alt="Smoke Testing Electronics" width="500">

In software engineering, smoke testing is used to reveal basic failures that can allow us to immediately reject a software build. It is also sometimes called _"Build Verification Testing," "Confidence Testing,”_ or _"Sanity Testing."_ The tests are usually a fast, simple check of major functionality to confirm that a build is ready to be subject to further testing. It can prevent flawed artifacts being released into QA environments, wasting both time and resources.

With smoke tests we can address basic questions, such as...

- Does my component/service run?
- Are interfaces accessible?
- Do the main features appear to work?

### But I already have unit tests!

Unit tests and other types of testing that run before the final artifact is produced will not catch problems with packaging.
Smoke tests are executed against the final artifact that will be published and/or deployed to a QA environment.
In some cases the artifact will just be a compiled binary and there might be very little that can go wrong.
Containers, however, are a minefield of dependencies and security updates and it can be difficult to have a high degree of confidence about your final container image without testing it!
Of course we can test it locally, but it should be automated in any good CI/CD pipeline.
We should be able to update our `Dockerfile` and `git push` knowing that if we have broken something obvious it will be caught.
This is where smoke tests can save us from causing a serious fire!

![Burning Docker](/img/burning-docker.jpg)

### Smoke testing Docker containers with CircleCI

There are various ways to smoke test containers but I will outline a couple of techniques using [CircleCI](https://circleci.com/).
CircleCI is probably the trickiest I've experienced due to the way they isolate the job container from the Docker build when using the `docker` executor type.
There is an option to avoid this by using the [`machine` executor type](https://circleci.com/docs/2.0/executor-types/#using-machine) that runs jobs in a dedicated, ephemeral VM.
However, they warn that this method may incur additional fees in a future pricing update.
So the following techniques assume use of the `docker` executor type.

#### Networking containers

To [run Docker commands](https://circleci.com/docs/2.0/building-docker-images/) you must specify the `setup_remote_docker` key to create a remote Docker environment.
This is completely isolated from your job container so if, for example, you attempt to curl a running Docker container you will find it has no connectivity.

```bash
curl: (7) Failed to connect to localhost port 8080: Connection refused
```

To run our smoke tests, in whatever form they take, we need to package them in a container of their own and network them to the container we want to test.
Here are two examples using publicly available Docker images to verify our service is running and returning a response from the `/healthcheck` endpoint.

An example using the Docker image [appropriate/curl](https://hub.docker.com/r/appropriate/curl/) to execute a `curl` request.
<script src="https://gist.github.com/peter-evans/2de20f87f567c3d638a33bba60941c20.js?file=curl-example.yml"></script>

An similar example using the Docker image [jwilder/dockerize](https://hub.docker.com/r/jwilder/dockerize/) to wait for a response from the healthcheck endpoint.
<script src="https://gist.github.com/peter-evans/2de20f87f567c3d638a33bba60941c20.js?file=dockerize-example.yml"></script>

#### Custom smoke tests

Using `curl` or [dockerize](https://github.com/jwilder/dockerize) to simply check for a `200 OK` response will most likely not be enough to adequately smoke test our container.
Those tools do, however, perform a necessary role of making sure that the service is up and running before we execute further tests.

Smoke tests can take whatever form you like provided they are executable via a container.
The following example demonstrates executing a [Postman](https://www.getpostman.com/) collection of smoke tests with the [postman/newman](https://hub.docker.com/r/postman/newman) Docker image.
Note that in order to make our test files (in this case a JSON Postman collection) available to the test executor we create a separate container to store them.
This container defines a volume at the path we want our test files to be accessible in the executor container.
That volume is then mounted in the executor container using the `--volumes-from` flag to make the test files available at runtime.

<script src="https://gist.github.com/peter-evans/2de20f87f567c3d638a33bba60941c20.js?file=smoke-test-example.yml"></script>

See the code in [this repository](https://github.com/peter-evans/smoke-testing) for a complete example of these techniques.

![I don't always deploy](/img/i-dont-always-deploy.jpg)
