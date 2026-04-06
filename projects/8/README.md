# aws-database-dynamodb-terraform

![AWS](https://img.shields.io/badge/AWS-Cloud%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Advanced DynamoDB setup with Global Secondary Index, TTL, Streams and Point-in-Time Recovery, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
DynamoDB Table
├── Primary Key: pk (partition) + sk (sort)
├── GSI: gsi1pk + gsi1sk → enables querying by category
├── TTL: expires_at → items auto-deleted after 30 days
├── Streams: NEW_AND_OLD_IMAGES → captures every change
└── PITR: enabled → restore to any point in last 35 days
        ↓
Lambda → demonstrates PutItem, GetItem, Query (GSI), DeleteItem
```

| Service | Role |
|---|---|
| **Amazon DynamoDB** | NoSQL table with composite key, GSI, TTL, Streams and PITR |
| **Global Secondary Index** | Allows querying by a different key without scanning the full table |
| **TTL** | Automatically deletes expired items to reduce storage costs |
| **DynamoDB Streams** | Captures every data change for event-driven processing |
| **Point-in-Time Recovery** | Enables table restore to any point in the last 35 days |
| **AWS Lambda** | Demonstrates all DynamoDB operations |
| **IAM** | Grants Lambda least-privilege access to DynamoDB and CloudWatch |

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **DynamoDB** → Tables → `database-table` → Overview, Indexes, Exports and streams
- **DynamoDB** → Tables → `database-table` → Additional settings → TTL and PITR
- **Lambda** → Functions → `database-function` → Test → invoke and check CloudWatch logs
- **CloudWatch** → Log Groups → `/aws/lambda/database-function`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/8

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your resource details will appear in the terminal:

```
dynamodb_table_name  = "database-table"
dynamodb_table_arn   = "arn:aws:dynamodb:us-east-1:xxxxxxxxxxxx:table/database-table"
dynamodb_stream_arn  = "arn:aws:dynamodb:us-east-1:xxxxxxxxxxxx:table/database-table/stream/..."
lambda_function_name = "database-function"
```

To tear down all resources:

```bash
terraform destroy
```
