# SeniorCare Website

Multi-page, accessible marketing site inspired by careforth.com. Deployed two ways:

- ALB + ASG + Nginx (zero-downtime rollouts)
- S3 + CloudFront (default HTTPS domain; add custom domain later)

## Repository Structure

- `seniorcare/site/`
  - Static pages: `index.html`, `services/`, `who-we-serve/`, `about.html`, `resources/`, `contact.html`, `privacy.html`, `terms.html`
  - Partials: `partials/header.html`, `partials/footer.html`
  - Assets: `assets/styles.css`, `assets/include.js`
- `seniorcare/infra/stack-cdn/`
  - S3 (private) + CloudFront (HTTPS) + OAC + security headers
  - Outputs: `cloudfront_url`, `site_bucket`
- `seniorcare/infra/stack-asg/`
  - VPC, Subnets, ALB, Target Group, ASG + Launch Template
  - Nginx user-data pulls site from S3

## Prerequisites

- Terraform >= 1.5
- AWS credentials configured (profile optional)
- AWS CLI for syncing site to S3 and optional invalidations

## Deploy Path A: S3 + CloudFront (HTTPS by default)

1) Initialize and apply infrastructure

```bash
cd seniorcare/infra/stack-cdn
terraform init
terraform apply -auto-approve
```

2) Upload site files to S3 bucket output by Terraform

```bash
aws s3 sync ../../site s3://$(terraform output -raw site_bucket) \
  --delete --cache-control max-age=3600,public --exclude ".DS_Store"
```

3) Open the CloudFront URL

```bash
terraform output cloudfront_url
```

Notes:
- First publish may take ~5–10 minutes to propagate.
- Header/footer are injected client-side via `assets/include.js`.

Optional: Force-refresh cache after content updates

```bash
DIST_ID=$(terraform output -raw cloudfront_domain_name | awk -F. '{print $1}')
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"
```

## Deploy Path B: ALB + ASG (Zero Downtime on EC2)

This path serves the same site via Nginx behind an Application Load Balancer. The ASG performs rolling refreshes for updates.

1) Ensure the CDN stack is applied first to get the site bucket name

```bash
cd seniorcare/infra/stack-cdn
BUCKET=$(terraform output -raw site_bucket)
```

2) Apply the ASG stack, passing the bucket

```bash
cd ../stack-asg
terraform init
terraform apply -auto-approve -var "site_bucket=$BUCKET"
```

3) Test URL (HTTP)

```bash
terraform output test_url
```

Notes:
- This path is HTTP by default. To add HTTPS on ALB, add ACM certificate + 443 listener + HTTP→HTTPS redirect when you have a custom domain.

## Custom Domain (later)

When you purchase a domain:
- ACM certificate in us-east-1 (for CloudFront) validated by DNS
- Route 53 hosted zone alias A/AAAA to CloudFront
- Optionally set HSTS preload, custom response headers, and redirects

## Development Tips

- Update content in `seniorcare/site/` and re-sync to S3
- Keep accessibility (focus-visible, alt text), performance (lazy images), and SEO (titles/meta) in mind
- `terraform fmt -recursive` and `terraform validate` before apply

## Cleanup

```bash
# CDN stack
cd seniorcare/infra/stack-cdn
terraform destroy -auto-approve

# ASG stack
cd ../stack-asg
terraform destroy -auto-approve
```
