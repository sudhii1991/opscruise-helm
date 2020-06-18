# Opscruise helmchart installation readme

## WIP
This Repo is a work in progress.

## Original Instructions
This chart is in the process of being refactored.  For new instructions, see [Instructions](#instructions).

For original instructions, see [original-instructions.md](./original-instructions.md).

## Instructions

> **Note:** These instructions are not fully functinal, but they *should* be the goal.


### TL;DR
```sh
helm add opscruise https://helm.opscruise.com
helm install opscruise
```

### Introduction

This chart installs the [OpsCruise](https://www.opscruise.com/) Autonomous Application Performance system.

### Prerequisites

#### Versions

| Item         | Version              | Provided |
| ------------ | -------------------- | -------- |
| Kubernetes   | V1.11 +              | n        |
| cAdvisor     | V0.35.0 +            | y        |
| NodeExporter | node-exporter1.1.0 + | y        |
| KSM Exporter | V1.6.0 +             | y        |
| Prometheus   | V2.17.1 +            | y        |
| Helm         | V3 +                 | n        |


#### Outbound Connections

The following outbound connections must be allowed:

```
<yourname>.opscruise.io:443,9093
auth.opscruise.io:8443
```

#### Credentials
You should have received couple of yaml files `opscruise-values.yaml` and `aws-values.yaml`
add your aws credentials in the aws-values.yaml


### Installing the Chart
To install the chart with release name `my-release`
#### Add the opscruise repo:
helm repo add opscruise-repo `opscruise-repo-url`
```sh
helm upgrade --install my-release opscruise-repo/opscruise --namespace <your-namespace> --create-namespace -f opscruise-values.yaml -f aws-values.yaml

```

