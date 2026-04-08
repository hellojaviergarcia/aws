# aws-serverless-production-lambda-apigateway-dynamodb-cognito-terraform

![AWS](https://img.shields.io/badge/AWS-Solutions%20Architect%20Associate-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Production-grade serverless architecture with authentication built on Lambda, API Gateway, DynamoDB and Cognito, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
Client
  ↓
Cognito (sign up / sign in → JWT token)
  ↓
API Gateway (JWT authorizer validates token on every request)
  ↓
Lambda (extracts userId from JWT claims)
  ↓
DynamoDB (tasks scoped per user)
```

| Service | Role |
|---|---|
| **Amazon Cognito** | User Pool for sign-up, sign-in and JWT token issuance |
| **API Gateway** | HTTP API with JWT authorizer ; rejects unauthenticated requests |
| **AWS Lambda** | Business logic ; extracts userId from JWT and queries DynamoDB |
| **Amazon DynamoDB** | Tasks table with userId as partition key ; data isolated per user |
| **IAM** | Grants Lambda least-privilege access to DynamoDB and CloudWatch |

---

## Endpoints

All endpoints require a valid Cognito JWT token in the `Authorization` header.

| Method | Path | Description |
|---|---|---|
| `GET` | `/tasks` | List all tasks for the authenticated user |
| `POST` | `/tasks` | Create a new task |
| `DELETE` | `/tasks/{taskId}` | Delete a task |

---

## How to Use

```bash
API="https://xxxx.execute-api.us-east-1.amazonaws.com/prod"
USER_POOL_ID="us-east-1_xxxxxxxxx"
CLIENT_ID="xxxxxxxxxxxxxxxxxxxxxxxxxx"

# 1. Create a user in Cognito
aws cognito-idp sign-up \
  --client-id $CLIENT_ID \
  --username user@example.com \
  --password MyPassword123!

# 2. Confirm the user (skip email verification for testing)
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id $USER_POOL_ID \
  --username user@example.com

# 3. Get a JWT token
TOKEN=$(aws cognito-idp initiate-auth \
  --client-id $CLIENT_ID \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=user@example.com,PASSWORD=MyPassword123! \
  --query "AuthenticationResult.IdToken" \
  --output text)

# 4. Use the API with the token
curl $API/tasks -H "Authorization: $TOKEN"

curl -X POST $API/tasks \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "My first task"}'
```

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **Cognito** → User Pools → `serverless-prod-users` → App clients
- **API Gateway** → APIs → `serverless-prod-api` → Authorization
- **Lambda** → Functions → `serverless-prod-function`
- **DynamoDB** → Tables → `serverless-prod-tasks`
- **CloudWatch** → Log Groups → `/aws/lambda/serverless-prod-function`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/13

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your resource details will appear in the terminal:

```
api_url                = "https://xxxx.execute-api.us-east-1.amazonaws.com/prod"
cognito_user_pool_id   = "us-east-1_xxxxxxxxx"
cognito_client_id      = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
dynamodb_table_name    = "serverless-prod-tasks"
lambda_function_name   = "serverless-prod-function"
```

To tear down all resources:

```bash
terraform destroy
```
