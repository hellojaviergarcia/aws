# aws-serverless-api-lambda-apigateway-dynamodb-terraform

![AWS](https://img.shields.io/badge/AWS-Cloud%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Serverless REST API built on AWS with Lambda, API Gateway and DynamoDB, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
Client → API Gateway (HTTP) → Lambda (Python) → DynamoDB
```

| Service | Role |
|---|---|
| **API Gateway** | Exposes the HTTP endpoints publicly |
| **AWS Lambda** | Executes the business logic on each request |
| **Amazon DynamoDB** | NoSQL database; stores the tasks |
| **IAM** | Grants Lambda least-privilege access to DynamoDB and CloudWatch |
| **CloudWatch** | Stores Lambda execution logs |

---

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/todos` | List all tasks |
| `POST` | `/todos` | Create a new task |
| `DELETE` | `/todos/{id}` | Delete a task by ID |

---

## How to Use

Add your API URL to **test.py**:
```python
API = "https://____.execute-api.us-east-1.amazonaws.com/prod/todos"
```

Then run:
```bash
pip install requests
python test.py
```

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/2

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your API URL will appear in the terminal:

```
api_url = "https://____.execute-api.us-east-1.amazonaws.com/prod/todos"
```

To tear down all resources:

```bash
terraform destroy
```