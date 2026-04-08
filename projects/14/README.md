# aws-disaster-recovery-route53-rds-s3-terraform

![AWS](https://img.shields.io/badge/AWS-Solutions%20Architect%20Associate-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Disaster recovery architecture on AWS with cross-region RDS read replica, S3 cross-region replication and Route 53 health checks, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
PRIMARY REGION (us-east-1)              DR REGION (eu-west-1)
─────────────────────────               ──────────────────────
S3 Primary Bucket                  →    S3 DR Bucket (Standard-IA)
  Cross-Region Replication              (automatic, real-time)

RDS MySQL Multi-AZ (primary)       →    RDS Read Replica
  Automated backups (7 days)            (promoted on failover)

Route 53 Health Check
  monitors primary RDS (TCP:3306)
```

| Service | Role |
|---|---|
| **RDS MySQL Multi-AZ** | Primary database with synchronous standby in second AZ |
| **RDS Read Replica** | Cross-region replica in eu-west-1 ; promoted during DR failover |
| **S3 Cross-Region Replication** | Automatically replicates objects to DR bucket in eu-west-1 |
| **Route 53 Health Check** | Monitors primary RDS endpoint ; detects failures within 90 seconds |
| **IAM** | Grants S3 least-privilege access to replicate objects |

---

## DR Strategy ; Warm Standby

This project implements a **Warm Standby** DR strategy:

- The DR environment is always running (not cold)
- RDS read replica is continuously updated from the primary
- S3 data is replicated in real time
- In a failover event, promote the RDS read replica to standalone and redirect traffic

**RTO (Recovery Time Objective):** ~15-30 minutes (time to promote replica + DNS propagation)
**RPO (Recovery Point Objective):** seconds (replication lag)

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **RDS** → Databases → `disaster-recovery-primary-db` → Multi-AZ = Yes
- **RDS** → Databases → `disaster-recovery-dr-db` → Role = Replica (eu-west-1)
- **S3** → `disaster-recovery-primary-xxxx` → Management → Replication rules
- **S3** → `disaster-recovery-dr-xxxx` → verify it exists in eu-west-1
- **Route 53** → Health checks → `disaster-recovery-health-check`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/14

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

> ⚠️ Change `db_password` in `variables.tf` before deploying.

> ⚠️ RDS and the cross-region read replica take ~15-20 minutes to deploy. This is expected.

After `apply` completes, your resource details will appear in the terminal:

```
primary_s3_bucket       = "disaster-recovery-primary-xxxx"
dr_s3_bucket            = "disaster-recovery-dr-xxxx"
primary_rds_endpoint    = "disaster-recovery-primary-db.xxxx.us-east-1.rds.amazonaws.com:3306"
dr_rds_endpoint         = "disaster-recovery-dr-db.xxxx.eu-west-1.rds.amazonaws.com:3306"
primary_rds_multi_az    = true
route53_health_check_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

To tear down all resources:

```bash
terraform destroy
```
