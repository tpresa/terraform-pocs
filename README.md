# EMR + Terragrunt POC

Minimal examples of AWS EMR deployed via Terragrunt, in eight variants:

- **emr-multinode** — 1 master + N core nodes (default 2).
- **emr-singlenode** — master only, HDFS replication forced to 1.
- **emr-serverless** — no cluster; an EMR Serverless application that scales to zero when idle.
- **emr-on-eks** — an EKS cluster + a virtual cluster registered against a namespace; jobs run as pods.
- **emr-managed-scaling** — a cluster that EMR resizes automatically between min/max bounds.
- **emr-instance-fleets** — instance fleets instead of groups: a diversified Spot + On-Demand mix with weighted capacity, plus an all-Spot task fleet.
- **emr-steps** — a transient cluster that runs a step (SparkPi) and auto-terminates on completion; the only variant that actually runs a job.
- **emr-security-config** — a cluster with at-rest encryption (S3 SSE-KMS + local-disk/EBS) backed by a customer-managed KMS key, with optional node-to-node TLS.

## Layout

```
.
├── terragrunt.hcl                    # root: S3 backend + AWS provider
├── modules/
│   ├── emr-multinode/                # master + core_instance_group
│   ├── emr-singlenode/               # master only, dfs.replication=1
│   ├── emr-serverless/               # serverless application, scales to zero
│   ├── emr-on-eks/                   # EKS cluster + EMR virtual cluster
│   ├── emr-managed-scaling/          # cluster + aws_emr_managed_scaling_policy
│   ├── emr-instance-fleets/          # master/core/task fleets, Spot + On-Demand mix
│   ├── emr-steps/                    # transient cluster, runs a step then self-terminates
│   └── emr-security-config/          # KMS key + aws_emr_security_configuration, encrypted cluster
└── live/
    └── dev/
        ├── emr-multinode/
        │   └── terragrunt.hcl
        ├── emr-singlenode/
        │   └── terragrunt.hcl
        ├── emr-serverless/
        │   └── terragrunt.hcl
        ├── emr-on-eks/
        │   └── terragrunt.hcl
        ├── emr-managed-scaling/
        │   └── terragrunt.hcl
        ├── emr-instance-fleets/
        │   └── terragrunt.hcl
        ├── emr-steps/
        │   └── terragrunt.hcl
        └── emr-security-config/
            └── terragrunt.hcl
```

## Prerequisites

- AWS credentials (`aws configure` or env vars)
- Terraform >= 1.3, Terragrunt >= 0.50
- An S3 bucket + DynamoDB table for remote state (edit the root `terragrunt.hcl`)
- A VPC subnet ID and S3 bucket for EMR logs for the cluster variants (edit the per-environment `terragrunt.hcl`)
- An S3 bucket for the serverless variant's job scripts/data (subnet optional)
- Two subnets (different AZs) and an S3 bucket for the EMR-on-EKS variant; `kubectl` is not required (RBAC is applied by Terraform)
- Two or more subnets (different AZs) for the instance-fleets variant — EMR picks the AZ with the best capacity/price
- A subnet + log bucket for the security-config variant (same as multinode); it provisions its own customer-managed KMS key. Node-to-node TLS is optional and needs a PEM certificate bundle in S3

## Deploy

Pick a variant and apply it:

```bash
# multi-node
cd live/dev/emr-multinode
terragrunt init
terragrunt plan
terragrunt apply
```

```bash
# single-node
cd live/dev/emr-singlenode
terragrunt init
terragrunt plan
terragrunt apply
```

```bash
# serverless
cd live/dev/emr-serverless
terragrunt init
terragrunt plan
terragrunt apply
```

```bash
# on EKS
cd live/dev/emr-on-eks
terragrunt init
terragrunt plan
terragrunt apply
```

```bash
# managed scaling
cd live/dev/emr-managed-scaling
terragrunt init
terragrunt plan
terragrunt apply
```

```bash
# instance fleets
cd live/dev/emr-instance-fleets
terragrunt init
terragrunt plan
terragrunt apply
```

```bash
# steps (transient — runs SparkPi, then terminates itself)
cd live/dev/emr-steps
terragrunt init
terragrunt plan
terragrunt apply
```

```bash
# security configuration (encrypted at rest with a customer-managed KMS key)
cd live/dev/emr-security-config
terragrunt init
terragrunt plan
terragrunt apply
```

> **Note:** `emr-steps` is transient. The apply succeeds once the cluster
> reaches `RUNNING`, but the cluster terminates itself after the step finishes,
> so a later `terragrunt plan` will show it wants to recreate the cluster —
> Terraform expects a persistent resource, which an ephemeral job cluster isn't.

The variants are independent — their state lives under separate keys
(`live/dev/emr-multinode/...`, `live/dev/emr-singlenode/...`,
`live/dev/emr-serverless/...`, `live/dev/emr-on-eks/...`,
`live/dev/emr-managed-scaling/...`, `live/dev/emr-instance-fleets/...`,
`live/dev/emr-steps/...`, `live/dev/emr-security-config/...`)
so they can coexist in the same account.

## Destroy

```bash
terragrunt destroy
```
