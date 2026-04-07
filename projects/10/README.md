# aws-content-analysis-rekognition-comprehend-transcribe-terraform

![AWS](https://img.shields.io/badge/AWS-AI%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

Content analysis pipeline built with Amazon Rekognition, Comprehend and Transcribe, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
API Gateway
├── POST /analyze/image → Lambda → Rekognition (labels, text, moderation)
├── POST /analyze/text  → Lambda → Comprehend (sentiment, entities, key phrases)
└── POST /analyze/audio → Lambda → Transcribe (speech to text)
                                        ↓
                              S3 (input files + results)
```

| Service | Role |
|---|---|
| **Amazon Rekognition** | Detects labels, text and moderation flags in images |
| **Amazon Comprehend** | Detects sentiment, entities and key phrases in text |
| **Amazon Transcribe** | Converts audio files to text |
| **AWS Lambda** | Orchestrates all three AI services |
| **API Gateway** | Exposes the pipeline as three HTTP endpoints |
| **Amazon S3** | Stores input files and Transcribe output |
| **IAM** | Grants Lambda least-privilege access to each AI service |

---

## Endpoints

| Method | Path | Service | Description |
|---|---|---|---|
| `POST` | `/analyze/image` | Rekognition | Analyze an image from S3 |
| `POST` | `/analyze/text` | Comprehend | Analyze sentiment and entities in text |
| `POST` | `/analyze/audio` | Transcribe | Start a transcription job for an audio file |

---

## How to Use

```bash
API="https://xxxx.execute-api.us-east-1.amazonaws.com/prod"

# Analyze text
curl -X POST $API/analyze/text \
  -H "Content-Type: application/json" \
  -d '{"text": "AWS is an amazing cloud platform with great AI services!"}'

# Analyze an image stored in S3
curl -X POST $API/analyze/image \
  -H "Content-Type: application/json" \
  -d '{"s3_key": "images/photo.jpg"}'

# Start audio transcription for a file stored in S3
curl -X POST $API/analyze/audio \
  -H "Content-Type: application/json" \
  -d '{"s3_key": "audio/recording.mp3"}'
```

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **API Gateway** → APIs → `content-analysis-api` → Routes
- **Lambda** → Functions → `content-analysis-function` → Test each route
- **S3** → Buckets → `content-analysis-bucket-xxxx` → upload test files
- **CloudWatch** → Log Groups → `/aws/lambda/content-analysis-function`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/10

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
s3_bucket_name       = "content-analysis-bucket-xxxx"
lambda_function_name = "content-analysis-function"
analyze_image_url    = "https://xxxx.execute-api.us-east-1.amazonaws.com/prod/analyze/image"
analyze_text_url     = "https://xxxx.execute-api.us-east-1.amazonaws.com/prod/analyze/text"
analyze_audio_url    = "https://xxxx.execute-api.us-east-1.amazonaws.com/prod/analyze/audio"
```

To tear down all resources:

```bash
terraform destroy
```
