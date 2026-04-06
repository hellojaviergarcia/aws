# aws-networking-security-vpc-iam-terraform

![AWS](https://img.shields.io/badge/AWS-Cloud%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

AWS network and security foundation built with VPC, public and private subnets, security groups and IAM, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24)  → Internet Gateway → Internet
│   └── Security Group: allows HTTP, HTTPS, SSH
└── Private Subnet (10.0.2.0/24) → no internet access
    └── Security Group: allows traffic from public subnet only
```

| Service | Role |
|---|---|
| **Amazon VPC** | Isolated private network for all resources |
| **Public Subnet** | For resources that need internet access |
| **Private Subnet** | For internal resources with no direct internet access |
| **Internet Gateway** | Allows the public subnet to reach the internet |
| **Route Tables** | Define traffic routing rules per subnet |
| **Security Groups** | Resource-level firewall ; least privilege per layer |
| **IAM Role + Policy** | Least-privilege role ready to be assumed by EC2 or Lambda |

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **VPC** → Your VPCs, Subnets, Internet Gateways, Route Tables
- **EC2** → Security Groups
- **IAM** → Roles → `networking-security-app-role`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/3

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your resource IDs will appear in the terminal:

```
vpc_id                    = "vpc-xxxxxxxxxxxxxxxxx"
public_subnet_id          = "subnet-xxxxxxxxxxxxxxxxx"
private_subnet_id         = "subnet-xxxxxxxxxxxxxxxxx"
public_security_group_id  = "sg-xxxxxxxxxxxxxxxxx"
private_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
iam_role_arn              = "arn:aws:iam::xxxxxxxxxxxx:role/networking-security-app-role"
iam_instance_profile_name = "networking-security-app-profile"
```

To tear down all resources:

```bash
terraform destroy
```
