# SeniorCare CDN Stack (S3 + CloudFront)

This stack deploys an S3 bucket for static hosting (private) and a CloudFront distribution with HTTPS (default CloudFront domain). Use it to serve the SeniorCare multi-page website.

## Deploy

From `seniorcare/infra/stack-cdn/`:

```bash
terraform init
terraform apply -auto-approve
```

Outputs:
- `cloudfront_domain_name`
- `cloudfront_url`
- `site_bucket`

## Upload site files

Use AWS CLI to sync the static site:

```bash
aws s3 sync ../../site s3://$(terraform output -raw site_bucket) \
  --delete --cache-control max-age=3600,public --exclude ".DS_Store"
```

Then open the `cloudfront_url` output.

## Notes
- Default HTTPS works without a custom domain. Later you can add ACM + Route 53 to use your own domain.
- Security headers are added via a CloudFront response headers policy.
- OAC is used; the S3 bucket is not public.
