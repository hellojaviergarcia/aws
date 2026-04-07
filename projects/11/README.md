# aws-multilingual-processing-translate-comprehend-terraform

![AWS](https://img.shields.io/badge/AWS-AI%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Multilingual text processing pipeline built with Amazon Translate and Comprehend, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
API Gateway
├── POST /translate → Lambda → Translate (auto-detect + translate)
└── POST /analyze   → Lambda → Translate → Comprehend
                                           (sentiment, entities, key phrases)
```

| Service | Role |
|---|---|
| **Amazon Translate** | Auto-detects source language and translates to target language |
| **Amazon Comprehend** | Detects sentiment, entities and key phrases in translated text |
| **AWS Lambda** | Orchestrates both services per request |
| **API Gateway** | Exposes the pipeline as two HTTP endpoints |
| **IAM** | Grants Lambda least-privilege access to Translate and Comprehend |

---

## Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/translate` | Auto-detect language and translate to target |
| `POST` | `/analyze` | Translate to English and run full Comprehend analysis |

---

## How to Use

```bash
API="https://xxxx.execute-api.us-east-1.amazonaws.com/prod"

# Translate text (auto-detects source language)
curl -X POST $API/translate \
  -H "Content-Type: application/json" \
  -d '{"text": "Hola, como estas?", "target_language": "en"}'

# Translate and analyze sentiment, entities and key phrases
curl -X POST $API/analyze \
  -H "Content-Type: application/json" \
  -d '{"text": "AWS es una plataforma increible para construir soluciones en la nube"}'
```

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **API Gateway** → APIs → `multilingual-api` → Routes
- **Lambda** → Functions → `multilingual-function` → Test each route
- **CloudWatch** → Log Groups → `/aws/lambda/multilingual-function`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/11

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your resource details will appear in the terminal:

```
api_url              = "https://xxxx.execute-api.us-east-1.amazonaws.com/prod"
translate_url        = "https://xxxx.execute-api.us-east-1.amazonaws.com/prod/translate"
analyze_url          = "https://xxxx.execute-api.us-east-1.amazonaws.com/prod/analyze"
lambda_function_name = "multilingual-function"
```

To tear down all resources:

```bash
terraform destroy
```
