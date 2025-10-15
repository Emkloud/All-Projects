# Barista Cafe on AWS (Terraform + EC2 + ALB)

A beautiful single‑page cafe website inspired by the Barista Cafe template (tooplate 2137), deployed on AWS using Terraform. The site is served by Nginx on an EC2 instance behind an Application Load Balancer (ALB).

## Repository Structure
```
cafe/
  └─ infra/
     ├─ main.tf
     ├─ variables.tf
     └─ outputs.tf
```

## What Gets Deployed
- **Networking**: VPC with 2 public subnets, IGW, route table.
- **Security**: SG for ALB (HTTP 80 from internet) and SG for EC2 (HTTP only from ALB). No SSH; use SSM if access is needed.
- **Compute**: EC2 `t3.micro` (Amazon Linux 2023), IMDSv2 required.
- **IAM**: EC2 role with `AmazonSSMManagedInstanceCore` via instance profile.
- **Load Balancer**: ALB + target group + HTTP listener.
- **App**: Static cafe landing page with modern styling, installed by `user_data` into Nginx.

## Prerequisites
- Terraform >= 1.1.0
- AWS CLI configured (for local deploys) and an AWS account with permissions to create VPC/EC2/ELB/IAM/SSM.

## Quick Start
From `cafe/infra/`:
```bash
# Optional: set your AWS profile (Git Bash)
export AWS_PROFILE=<your-profile>

terraform init
terraform plan -out=tfplan \
  -var "region=us-east-1" \
  -var "project_name=barista-cafe" \
  -var "profile=${AWS_PROFILE}"

t terraform apply "tfplan"
```
Open the output `test_url` to view the site.

Destroy when done:
```bash
terraform destroy -auto-approve \
  -var "region=us-east-1" \
  -var "project_name=barista-cafe" \
  -var "profile=${AWS_PROFILE}"
```

## Customization
- Update the HTML/CSS in `user_data` inside `cafe/infra/main.tf` to tweak branding, menu items, and content.
- For HTTPS, add an ACM certificate and replace the HTTP listener with HTTPS.

## Cost Note
Approx idle monthly in `us-east-1`:
- ALB ~$17–$20
- EC2 t3.micro ~$7–$8
- EBS 10GiB ~$0.8
Total ~$26–$30/month (estimate). Destroy resources when done.

## Troubleshooting
- If ALB shows 5xx initially, give the instance a minute to finish `user_data` and restart Nginx.
- Ensure IMDSv2 is required in `metadata_options` and SSM is installed if you need access.
