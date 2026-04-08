# aws-data-lake-s3-glue-athena-terraform

![AWS](https://img.shields.io/badge/AWS-Solutions%20Architect%20Associate-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Serverless data lake on AWS with S3 storage layers, Glue data catalog and Athena SQL queries, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
Raw Data (S3)
    ↓
Glue Crawler → infers schema → Glue Catalog (database + tables)
    ↓
Athena → SQL queries over S3 data → Results (S3)
```

```
S3 Layers
├── raw/       → landing zone ; incoming data (versioned, lifecycle policy)
├── processed/ → cleaned and transformed data
└── athena/    → Athena query results (encrypted at rest)
```

| Service | Role |
|---|---|
| **Amazon S3** | Three-layer storage ; raw, processed and query results |
| **AWS Glue Crawler** | Scans S3 and automatically infers schema ; runs daily |
| **AWS Glue Catalog** | Central metadata repository ; tables and schema definitions |
| **Amazon Athena** | Serverless SQL engine ; queries S3 data directly, no ETL needed |
| **Athena Workgroup** | Isolates queries, enforces result location and caps bytes scanned |
| **IAM** | Grants Glue least-privilege access to S3 and the catalog |

---

## How to Use

```bash
# 1. After deploying, run the Glue crawler to populate the catalog
aws glue start-crawler --name data-lake-sales-crawler

# 2. Wait for the crawler to finish (~1-2 minutes)
aws glue get-crawler --name data-lake-sales-crawler \
  --query "Crawler.State" --output text

# 3. Open Athena in the AWS Console and run the named query
#    Athena → Query editor → Workgroup: data-lake-workgroup
#    Saved queries → sales-summary → Run
```

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **S3** → Buckets → `data-lake-raw-xxxx` → `sales/2024/data.csv` should exist
- **Glue** → Crawlers → `data-lake-sales-crawler` → Run crawler
- **Glue** → Databases → `data_lake_db` → Tables → `sales` should appear after crawl
- **Athena** → Query editor → Workgroup: `data-lake-workgroup` → run `SELECT * FROM sales LIMIT 10`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/15

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your resource details will appear in the terminal:

```
raw_bucket_name            = "data-lake-raw-xxxx"
processed_bucket_name      = "data-lake-processed-xxxx"
athena_results_bucket_name = "data-lake-athena-results-xxxx"
glue_database_name         = "data_lake_db"
glue_crawler_name          = "data-lake-sales-crawler"
athena_workgroup_name      = "data-lake-workgroup"
```

To tear down all resources:

```bash
terraform destroy
```
