# ☁️ AWS Projects

> A curated collection of hands-on AWS projects built with Terraform, demonstrating real-world cloud architecture across compute, storage, networking, security, AI and more.

![AWS](https://img.shields.io/badge/Amazon_AWS-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)

---

## Projects

| # | Project | Services | Link |
|---|---|---|---|
| 01 | Static website hosting | S3, CloudFront | [→](./projects/1/README.md) |
| 02 | Serverless REST API | Lambda, API Gateway, DynamoDB | [→](./projects/2/README.md) |
| 03 | Network & security foundation | VPC, Subnets, Security Groups, IAM | [→](./projects/3/README.md) |
| 04 | Observability setup | CloudWatch, SNS, Lambda | [→](./projects/4/README.md) |
| 05 | S3 storage management | S3 Versioning, Lifecycle, Replication | [→](./projects/5/README.md) |
| 06 | EC2 Auto Scaling | EC2, Launch Templates, ASG, CloudWatch | [→](./projects/6/README.md) |
| 07 | Event-driven messaging | SNS, SQS, DLQ, Lambda | [→](./projects/7/README.md) |
| 08 | NoSQL database | DynamoDB, GSI, TTL, Streams | [→](./projects/8/README.md) |
| 09 | Generative AI chatbot | Bedrock, Lambda, S3, CloudFront | [→](./projects/9/README.md) |
| 10 | Content analysis pipeline | Rekognition, Comprehend, Transcribe | [→](./projects/10/README.md) |
| 11 | Multilingual processing | Translate, Comprehend, Lambda | [→](./projects/11/README.md) |
| 12 | Three-tier architecture | ALB, Auto Scaling, RDS Multi-AZ | [→]() |
| 13 | Serverless production architecture | Lambda, API Gateway, DynamoDB, Cognito | [→]() |
| 14 | Disaster recovery | Route 53, RDS, S3 Cross-Region | [→]() |
| 15 | Data lake | S3, Glue, Athena, QuickSight | [→]() |

---

## Stack

All projects follow the same principles:

- **Infrastructure as Code** ; every resource is defined in Terraform and deployable with a single command
- **Least privilege** ; IAM roles and policies grant only the permissions each service needs
- **Replicable** ; no shared state, no hardcoded credentials, no manual prerequisites

---

## How to use any project

```bash
git clone https://github.com/hellojaviergarcia/aws.git

# Select project id to deploy
cd aws/projects/<project-id>

# Config AWS IAM account token access
aws configure

terraform init
terraform plan
terraform apply
```
