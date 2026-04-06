# aws-storage-s3-lifecycle-versioning-terraform

![AWS](https://img.shields.io/badge/AWS-Cloud%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

AWS storage project demonstrating S3 versioning, lifecycle policies and cross-region replication, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
Primary Bucket (us-east-1)
├── Versioning: enabled ; every overwrite keeps the previous version
├── Lifecycle Policy
│   ├── Day 0   → S3 Standard
│   ├── Day 30  → S3 Standard-IA (40% cheaper)
│   ├── Day 90  → S3 Glacier Instant Retrieval (68% cheaper)
│   └── Day 180 → permanent deletion
└── Replication → Replica Bucket (eu-west-1, stored in Standard-IA)
```

| Service | Role |
|---|---|
| **Amazon S3 ; Primary** | Main storage bucket in us-east-1 |
| **Versioning** | Keeps previous versions of every object for data protection |
| **Lifecycle Policy** | Automatically moves objects to cheaper storage classes over time |
| **Amazon S3 ; Replica** | Cross-region replica bucket in eu-west-1 for disaster recovery |
| **IAM Role + Policy** | Grants S3 least-privilege access to replicate objects |

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **S3** → Buckets → `storage-primary-xxxx` → Properties → Versioning and Lifecycle rules
- **S3** → Buckets → `storage-primary-xxxx` → Management → Replication rules
- **S3** → Buckets → `storage-replica-xxxx` → verify it exists in eu-west-1
- **IAM** → Roles → `storage-replication-role`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/5

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your bucket details will appear in the terminal:

```
primary_bucket_name  = "storage-primary-xxxx"
primary_bucket_arn   = "arn:aws:s3:::storage-primary-xxxx"
replica_bucket_name  = "storage-replica-xxxx"
replica_bucket_arn   = "arn:aws:s3:::storage-replica-xxxx"
replication_role_arn = "arn:aws:iam::xxxxxxxxxxxx:role/storage-replication-role"
```

To tear down all resources:

```bash
terraform destroy
```
