# aws-generative-ai-bedrock-chatbot-terraform

![AWS](https://img.shields.io/badge/AWS-AI%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Serverless generative AI chatbot built on Amazon Bedrock (Claude), with a web interface hosted on S3 + CloudFront and a Lambda API, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
User → CloudFront → S3 (web interface)
              ↓
User → API Gateway (POST /chat) → Lambda → Amazon Bedrock (Claude)
```

| Service | Role |
|---|---|
| **Amazon Bedrock** | Hosts the Claude model and generates AI responses |
| **AWS Lambda** | Receives chat messages and invokes Bedrock |
| **API Gateway** | Exposes the Lambda as a public HTTP endpoint |
| **Amazon S3** | Stores the chatbot web interface |
| **Amazon CloudFront** | Serves the web interface globally over HTTPS |
| **IAM** | Grants Lambda least-privilege access to Bedrock and CloudWatch |

---

## How to Use

1. Open the `website/index.html` file and replace `API_URL` with your API Gateway URL from the outputs
2. Run `terraform apply` again to upload the updated file to S3
3. Open the CloudFront URL in your browser and start chatting

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **CloudFront** → Distributions → open the URL → chatbot interface should load
- **API Gateway** → APIs → `bedrock-chatbot-api` → Routes → `POST /chat`
- **Lambda** → Functions → `bedrock-chatbot-function` → Test with `{"message": "Hello"}`
- **CloudWatch** → Log Groups → `/aws/lambda/bedrock-chatbot-function`
- **Bedrock** → Model access → confirm `Claude 3 Haiku` is enabled in us-east-1

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/9

# 2. Configure your AWS credentials
aws configure

# 3. Enable Bedrock model access in the AWS Console
#    Bedrock → Model access → Enable Claude 3 Haiku

# 4. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your resource details will appear in the terminal:

```
cloudfront_url       = "https://xxxx.cloudfront.net"
api_url              = "https://xxxx.execute-api.us-east-1.amazonaws.com/prod/chat"
lambda_function_name = "bedrock-chatbot-function"
bedrock_model_id     = "anthropic.claude-3-haiku-20240307-v1:0"
```

> ⚠️ Before deploying, enable Claude 3 Haiku model access in the AWS Console under **Bedrock → Model access**. Without this step the Lambda will return a 500 error.

To tear down all resources:

```bash
terraform destroy
```
