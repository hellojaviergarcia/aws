# aws-compute-ec2-autoscaling-terraform

![AWS](https://img.shields.io/badge/AWS-Cloud%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

AWS compute project demonstrating EC2 Auto Scaling with Launch Templates and CloudWatch CPU-based scaling policies, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
Auto Scaling Group (min: 1, max: 3, desired: 1)
├── Launch Template → Amazon Linux 2023 + Apache HTTP Server
├── Security Group  → allows HTTP (80) and SSH (22)
├── Scale Up Policy   → adds 1 instance when CPU ≥ 70%
└── Scale Down Policy → removes 1 instance when CPU ≤ 30%
        ↕
CloudWatch Alarms → trigger scaling policies based on CPU metrics
```

| Service | Role |
|---|---|
| **Amazon EC2** | Virtual machines running the Apache web server |
| **Launch Template** | Defines instance configuration ; AMI, type, user data, security group |
| **Auto Scaling Group** | Manages instance count automatically across availability zones |
| **Scaling Policies** | Add or remove instances based on CPU thresholds |
| **CloudWatch Alarms** | Monitor CPU and trigger scaling policies at 70% and 30% |
| **Security Group** | Allows HTTP and SSH inbound traffic |

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **EC2** → Auto Scaling Groups → `compute-asg`
- **EC2** → Launch Templates → `compute-lt`
- **EC2** → Instances → running instances launched by the ASG
- **EC2** → Security Groups → `compute-sg`
- **CloudWatch** → Alarms → `compute-cpu-high` and `compute-cpu-low`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/6

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your resource details will appear in the terminal:

```
autoscaling_group_name = "compute-asg"
launch_template_id     = "lt-xxxxxxxxxxxxxxxxx"
security_group_id      = "sg-xxxxxxxxxxxxxxxxx"
ami_id                 = "ami-xxxxxxxxxxxxxxxxx"
scale_up_policy_arn    = "arn:aws:autoscaling:us-east-1:xxxxxxxxxxxx:scalingPolicy:..."
scale_down_policy_arn  = "arn:aws:autoscaling:us-east-1:xxxxxxxxxxxx:scalingPolicy:..."
```

To tear down all resources:

```bash
terraform destroy
```
