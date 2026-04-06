# aws-messaging-sns-sqs-terraform

![AWS](https://img.shields.io/badge/Amazon_AWS-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)

Event-driven messaging architecture built with SNS, SQS and Lambda, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
Publisher → SNS Topic → SQS Queue → Lambda (processor)
                                ↓
                        Dead Letter Queue (failed messages)
```

| Service | Role |
|---|---|
| **Amazon SNS** | Publishes messages to all subscribers |
| **Amazon SQS** | Decouples the publisher from the processor ; buffers messages |
| **Dead Letter Queue** | Captures messages that failed after 3 processing attempts |
| **AWS Lambda** | Consumes and processes messages from the SQS queue |
| **IAM** | Grants Lambda least-privilege access to SQS and CloudWatch |
| **CloudWatch** | Stores Lambda execution logs |

---

## How to Use

Publish a message to the SNS topic using the AWS CLI:

```bash
aws sns publish \
  --topic-arn <sns_topic_arn> \
  --message '{"event": "order_created", "id": "123"}' \
  --region us-east-1
```

Then check the Lambda logs in CloudWatch to confirm the message was processed:

```
CloudWatch → Log Groups → /aws/lambda/messaging-function
```

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **SNS** → Topics → `messaging-topic`
- **SQS** → Queues → `messaging-queue` and `messaging-dlq`
- **Lambda** → Functions → `messaging-function` → Triggers → SQS
- **CloudWatch** → Log Groups → `/aws/lambda/messaging-function`

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/7

# 2. Configure your AWS credentials
aws configure

# 3. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your resource details will appear in the terminal:

```
sns_topic_arn        = "arn:aws:sns:us-east-1:xxxxxxxxxxxx:messaging-topic"
sqs_queue_url        = "https://sqs.us-east-1.amazonaws.com/xxxxxxxxxxxx/messaging-queue"
sqs_queue_arn        = "arn:aws:sqs:us-east-1:xxxxxxxxxxxx:messaging-queue"
dlq_url              = "https://sqs.us-east-1.amazonaws.com/xxxxxxxxxxxx/messaging-dlq"
lambda_function_name = "messaging-function"
```

To tear down all resources:

```bash
terraform destroy
```
