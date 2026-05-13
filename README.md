# EMR + Terragrunt POC

Minimal example of an AWS EMR cluster deployed via Terragrunt.

## Layout

```
.
├── terragrunt.hcl              # root: S3 backend + AWS provider
├── modules/
│   └── emr/                    # local Terraform module (cluster + IAM)
└── live/
    └── dev/
        └── emr/
            └── terragrunt.hcl  # dev environment inputs
```

## Prerequisites

- AWS credentials (`aws configure` or env vars)
- Terraform >= 1.3, Terragrunt >= 0.50
- An S3 bucket + DynamoDB table for remote state (edit the root `terragrunt.hcl`)
- A VPC subnet ID and S3 bucket for EMR logs (edit `live/dev/emr/terragrunt.hcl`)

## Deploy

```bash
cd live/dev/emr
terragrunt init
terragrunt plan
terragrunt apply
```

## Destroy

```bash
terragrunt destroy
```
