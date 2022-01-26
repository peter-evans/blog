---
title: "kdef: Declarative resource management for Kafka"
date: 2022-01-26T22:35:12+09:00
author: Peter Evans
description: "Introducing kdef, a tool for declarative management of Kafka resources such as topics and ACLs"
keywords: ["kafka", "declarative", "topic", "acl", "git-ops", "management", "yaml", "json"]
---

Introducing [kdef](https://github.com/peter-evans/kdef), a tool for declarative management of Kafka resources.

kdef aims to provide an easy way to manage resources in a Kafka cluster by having them defined explicitly in a human-readable format. Changes to resource definitions can be reviewed like code and applied to a cluster.

kdef was designed to support being run in a CI-CD environment, allowing teams to manage Kafka resource definitions in source control with pull requests ([GitOps](https://www.gitops.tech/)).

![kdef demo](/img/kdef-demo.gif)

### Features

- Definition support for:
    - Topics
    - ACLs
    - Per-broker configs
    - Cluster-wide broker configs
- YAML and JSON definition formats
- TLS and SASL mechanisms (PLAIN, SCRAM, AWS_MSK_IAM)
- CLI scripting support (input via stdin, JSON output, etc.)

### Highlights

kdef shows a diff of exactly what is changing. This allows a dry-run of the changes to be reviewed easily before being applied.

Example output:
```sh
topic definition "tutorial_topic1" diff (local -> remote):
 {
   "apiVersion": "v1",
   "kind": "topic",
   "metadata": {
     "name": "tutorial_topic1"
   },
   "spec": {
     "configs": {
-      "retention.ms": "86400000"
+      "retention.ms": "43200000"
     },
     "deleteUndefinedConfigs": false,
-    "partitions": 3,
+    "partitions": 6,
     "replicationFactor": 2,
     "managedAssignments": {
       "balance": "new",
       "selection": "topic-cluster-use"
     },
     "maintainLeaders": false
   },
   "state": {
     "assignments": [
       [
         1,
         2
       ],
       [
         2,
         1
       ],
       [
         1,
         2
+      ],
+      [
+        2,
+        1
+      ],
+      [
+        1,
+        2
+      ],
+      [
+        2,
+        1
       ]
     ]
   }
 }
```

kdef is scripting-friendly, supporting features such as input via stdin and JSON output.

Passing a topic definition to kdef via stdin:
```sh
cat <<EOF | kdef apply - --dry-run
apiVersion: v1
kind: topic
metadata:
  name: tutorial_topic2
spec:
  configs:
    retention.ms: "86400000"
  partitions: 3
  replicationFactor: 2
EOF
```

JSON output from kdef being piped to jq:
```sh
kdef apply "definitions/topic/*.yml" --dry-run --json-output | jq -r '.[] | "\(.local.metadata.name):\n\(.diff)"'
```

### Documentation

See the [manual](https://peter-evans.github.io/kdef) for installation, configuration and usage instructions.
