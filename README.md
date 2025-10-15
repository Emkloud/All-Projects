# Tic‑Tac‑Toe on AWS (Terraform + GitHub Actions)

A secure, cost‑aware deployment of a static two‑player tic‑tac‑toe website on AWS using Terraform. The app is served by Nginx on an EC2 instance behind an Application Load Balancer (ALB). CI runs plan/scan on PRs; merges to `main` deploy automatically via GitHub OIDC.

## Repository Structure
```
windsurf/
├─ infra/
│  ├─ main.tf
│  ├─ variables.tf
│  ├─ outputs.tf
│  └─ (local tfstate if using local backend)
└─ .github/workflows/
   ├─ ci.yml      # PR: fmt/validate/tflint/tfsec/plan + PR comment
   └─ deploy.yml  # main: init/plan/apply + outputs summary
```

## What Gets Deployed
- **Networking**: `VPC`, 2 public subnets, IGW, routes.
- **Security**: SG for ALB (HTTP 80 from 0.0.0.0/0), SG for EC2 (HTTP only from ALB). No SSH; access via SSM.
- **Compute**: `t3.micro` EC2 with Amazon Linux 2023. IMDSv2 required.
- **IAM**: EC2 role with `AmazonSSMManagedInstanceCore` via instance profile.
- **Load Balancer**: ALB + target group + HTTP listener.
- **App**: Static two‑player tic‑tac‑toe (hot‑seat) served by Nginx via EC2 `user_data`.

## Prerequisites
- Terraform `1.1.9` (or compatible with AWS provider `~> 4.67`).
- AWS CLI configured on your machine (used only for local runs).
- AWS account with permissions to create VPC/EC2/ELB/IAM/SSM.
- Optional but recommended: remote backend (S3 state + DynamoDB lock).

## Quick Start (Local)
From `infra/`:
```powershell
# Optional: use a specific AWS profile
$env:AWS_PROFILE = "<your-profile>"

terraform init
terraform plan -out=tfplan `
  -var "region=us-east-1" `
  -var "project_name=tic-tac-toe" `
  -var "profile=<your-profile>"

terraform apply "tfplan"
```
After apply, outputs include:
- `test_url` – open this to play the game.
- `alb_dns_name` – raw ALB DNS.

Destroy when done:
```powershell
terraform destroy -auto-approve `
  -var "region=us-east-1" `
  -var "project_name=tic-tac-toe" `
  -var "profile=<your-profile>"
```

## CI/CD (GitHub Actions)
Workflows are in `.github/workflows/`.

- **CI (PR checks)**: `ci.yml`
  - Triggers on PRs to `main` affecting `infra/**`.
  - Steps: `fmt` → `init` → `validate` → `tflint` → `tfsec` → `plan`.
  - Uploads `tfplan` and `plan.txt` artifacts; posts a plan summary comment on the PR.

- **Deploy (main)**: `deploy.yml`
  - Triggers on push to `main`.
  - Runs `init` → `plan` → `apply` (auto‑approve), then prints the `test_url` in the job summary.

### GitHub OIDC → AWS (No static keys)
Set two repository secrets:
- `AWS_REGION` (e.g., `us-east-1`)
- `AWS_ROLE_TO_ASSUME` (IAM role ARN to assume)

In AWS IAM:
1. Create the GitHub OIDC provider (if not present):
   - URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
2. Create an IAM role to be assumed by GitHub Actions with a trust policy restricting your repo/branches, for example:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:<your-org>/<your-repo>:pull_request",
            "repo:<your-org>/<your-repo>:ref:refs/heads/main"
          ]
        }
      }
    }
  ]
}
```
Attach a permissions policy allowing Terraform to manage `ec2`, `elasticloadbalancing`, `iam` (limited to instance profile/role usage), `ssm`, and VPC resources. Tighten to least‑privilege as needed.

### Branch/PR Flow
- Create a feature branch → commit changes in `infra/` → push and open a PR → CI runs checks and plan → after approval, merge into `main` → Deploy workflow applies changes.

## Variables (see `infra/variables.tf`)
- **`project_name`**: default `tic-tac-toe`.
- **`region`**: default `us-east-1`.
- **`profile`**: AWS CLI profile name; empty in CI (OIDC creds).
- **`vpc_cidr`**: default `10.0.0.0/16`.
- **`public_subnet_cidrs`**: defaults for 2 public subnets.
- **`instance_type`**: default `t3.micro`.

## Security Posture
- No SSH exposure. Access via **SSM Session Manager**.
- EC2 **IMDSv2 required**.
- EC2 SG allows HTTP only from ALB SG; ALB SG allows HTTP from the internet.
- For HTTPS: add ACM cert + HTTPS listener + HTTP→HTTPS redirect.

## Cost Estimate (us‑east‑1, low traffic)
- **ALB**: ~$17–$20/month (hourly + small LCUs)
- **EC2 t3.micro**: ~$7.60/month
- **EBS 10GiB**: ~$0.80/month
- **Data egress**: ~$0.09/GB beyond the first 1 GB free
- Estimate: **~$26–$30/month** at idle/low traffic. Remove ALB or use S3/CloudFront to reduce.

## Troubleshooting
- Plan/apply fails with interpolation near JS template strings: ensure `${...}` in `user_data` are escaped as `$${...}` in Terraform.
- Error `HttpEndpoint` invalid: ensure `metadata_options` has `http_endpoint = "enabled"` and `http_tokens = "required"`.
- Provider version issues: Terraform pinned to `1.1.9` and AWS provider `~> 4.67`. Update both consistently if you upgrade.
- If the ALB shows 5xx during rollout, instance may be rebooting after `user_data` change; wait a minute and refresh.

## Roadmap / Options
- HTTPS (ACM) + WAF on ALB.
- Private subnets + NAT (higher cost, stronger isolation).
- Autoscaling group + launch template for zero‑downtime rollouts.
- Remote backend (S3 + DynamoDB) for shared state and locking.

## License
MIT (or your preferred license).
