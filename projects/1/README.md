# aws-static-website-s3-cloudfront-terraform

![AWS](https://img.shields.io/badge/AWS-Cloud%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Static website hosted on AWS with S3 + CloudFront, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
User → CloudFront (CDN, HTTPS) → S3 Bucket (private)
```

| Service | Role |
|---|---|
| **Amazon S3** | Stores the static website files |
| **Amazon CloudFront** | Global CDN; serves content over HTTPS from edge locations |
| **Origin Access Control** | Ensures only CloudFront can read the S3 bucket |

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/1

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your live URL will appear in the terminal:

```
cloudfront_url = "https://____.cloudfront.net"
```

To tear down all resources:

```bash
terraform destroy
```