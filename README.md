# EMR + Terragrunt POC

Minimal examples of AWS EMR deployed via Terragrunt, in four variants:

- **emr-multinode** — 1 master + N core nodes (default 2).
- **emr-singlenode** — master only, HDFS replication forced to 1.
- **emr-serverless** — no cluster; an EMR Serverless application that scales to zero when idle.
- **emr-on-eks** — an EKS cluster + a virtual cluster registered against a namespace; jobs run as pods.

## Layout

```
.
├── terragrunt.hcl                    # root: S3 backend + AWS provider
├── modules/
│   ├── emr-multinode/                # master + core_instance_group
│   ├── emr-singlenode/               # master only, dfs.replication=1
│   ├── emr-serverless/               # serverless application, scales to zero
│   └── emr-on-eks/                   # EKS cluster + EMR virtual cluster
└── live/
    └── dev/
        ├── emr-multinode/
        │   └── terragrunt.hcl
        ├── emr-singlenode/
        │   └── terragrunt.hcl
        ├── emr-serverless/
        │   └── terragrunt.hcl
        └── emr-on-eks/
            └── terragrunt.hcl
```

## Prerequisites

- AWS credentials (`aws configure` or env vars)
- Terraform >= 1.3, Terragrunt >= 0.50
- An S3 bucket + DynamoDB table for remote state (edit the root `terragrunt.hcl`)
- A VPC subnet ID and S3 bucket for EMR logs for the cluster variants (edit the per-environment `terragrunt.hcl`)
- An S3 bucket for the serverless variant's job scripts/data (subnet optional)
- Two subnets (different AZs) and an S3 bucket for the EMR-on-EKS variant; `kubectl` is not required (RBAC is applied by Terraform)

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

The variants are independent — their state lives under separate keys
(`live/dev/emr-multinode/...`, `live/dev/emr-singlenode/...`,
`live/dev/emr-serverless/...`, `live/dev/emr-on-eks/...`) so they can coexist in
the same account.

## Destroy

```bash
terragrunt destroy
```
