# aws-three-tier-architecture-alb-autoscaling-rds-terraform

![AWS](https://img.shields.io/badge/AWS-Solutions%20Architect%20Associate-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Production-grade three-tier architecture on AWS with ALB, EC2 Auto Scaling and RDS Multi-AZ, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
Internet
    ↓
ALB (public subnets: us-east-1a, us-east-1b)
    ↓
Auto Scaling Group ; EC2 (private subnets: us-east-1a, us-east-1b)
    ↓
RDS MySQL Multi-AZ (db subnets: us-east-1a, us-east-1b)
```

```
VPC (10.0.0.0/16)
├── Public Subnets    10.0.1.0/24 · 10.0.2.0/24  → ALB
├── Private Subnets   10.0.3.0/24 · 10.0.4.0/24  → EC2 (ASG)
└── Database Subnets  10.0.5.0/24 · 10.0.6.0/24  → RDS Multi-AZ
```

| Service | Role |
|---|---|
| **Application Load Balancer** | Distributes traffic across EC2 instances in multiple AZs |
| **Auto Scaling Group** | Maintains desired EC2 capacity and scales based on CPU |
| **Launch Template** | Defines EC2 configuration ; AMI, instance type, user data |
| **RDS MySQL Multi-AZ** | Primary database with automatic failover to standby in second AZ |
| **Security Groups** | Least privilege per tier ; ALB → EC2 → RDS only |
| **CloudWatch Alarms** | Trigger scale up at CPU ≥ 70% and scale down at CPU ≤ 30% |

---

## Design Decisions

**Why Multi-AZ RDS?**
Multi-AZ deploys a synchronous standby replica in a second Availability Zone. If the primary instance fails, AWS automatically fails over to the standby with no manual intervention, minimising downtime.

**Why private subnets for EC2?**
EC2 instances have no public IP and are not directly accessible from the internet. All traffic must go through the ALB, which acts as the single entry point. This reduces the attack surface.

**Why ELB health checks on the ASG?**
Using `health_check_type = "ELB"` means the ASG uses the ALB health check to determine if an instance is healthy, not just EC2 status checks. This ensures unhealthy instances are replaced before users are affected.

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **EC2** → Load Balancers → `three-tier-alb` → open DNS name in browser
- **EC2** → Auto Scaling Groups → `three-tier-asg` → Activity and Instances
- **EC2** → Target Groups → `three-tier-tg` → Targets → all instances healthy
- **RDS** → Databases → `three-tier-db` → Multi-AZ = Yes
- **VPC** → Subnets → verify 6 subnets across 2 AZs

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/12

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

> ⚠️ Before deploying, change `db_password` in `variables.tf` ; the default value is a placeholder and should never be used in production.

> ⚠️ RDS takes ~5-10 minutes to deploy. This is expected.

After `apply` completes, your resource details will appear in the terminal:

```
alb_dns_name           = "http://three-tier-alb-xxxx.us-east-1.elb.amazonaws.com"
autoscaling_group_name = "three-tier-asg"
rds_endpoint           = "three-tier-db.xxxx.us-east-1.rds.amazonaws.com:3306"
rds_multi_az           = true
vpc_id                 = "vpc-xxxxxxxxxxxxxxxxx"
```

Open the `alb_dns_name` in your browser to see the running application.

To tear down all resources:

```bash
terraform destroy
```
