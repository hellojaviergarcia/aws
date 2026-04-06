# aws-monitoring-cloudwatch-terraform

![AWS](https://img.shields.io/badge/AWS-Cloud%20Practitioner-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-brightgreen?style=flat)

AWS observability setup built with CloudWatch logs, metric alarms, a dashboard and SNS email notifications, fully deployed as Infrastructure as Code with Terraform.

---

## Architecture

```
Lambda Function
├── CloudWatch Log Group    → stores execution logs (7 day retention)
├── CloudWatch Alarm: Errors   → triggers if errors ≥ 1 in 5 minutes
├── CloudWatch Alarm: Duration → triggers if duration ≥ 5000ms
└── SNS Topic → sends email alert when any alarm triggers
```

| Service | Role |
|---|---|
| **AWS Lambda** | Monitored resource that generates logs and metrics |
| **CloudWatch Logs** | Stores Lambda execution logs with retention policy |
| **CloudWatch Alarms** | Triggers notifications based on error and duration thresholds |
| **CloudWatch Dashboard** | Unified view of invocations, errors and duration metrics |
| **Amazon SNS** | Sends email alerts when an alarm triggers or recovers |
| **IAM** | Grants Lambda least-privilege access to CloudWatch Logs |

---

## How to Verify

After deploying, verify the resources in the AWS Console:

- **CloudWatch** → Log Groups → `/aws/lambda/monitoring-function`
- **CloudWatch** → Alarms → `monitoring-lambda-errors` and `monitoring-lambda-duration`
- **CloudWatch** → Dashboards → `monitoring-dashboard`
- **SNS** → Topics → `monitoring-alerts` → confirm the email subscription

> ⚠️ After deploying, check your inbox and confirm the SNS subscription to start receiving alerts.

---

## How to Replicate

```bash
# 1. Clone the repo
git clone https://github.com/hellojaviergarcia/aws.git
cd aws/projects/4

# 2. Set your alert email in variables.tf
alert_email = "your-email@example.com"

# 3. Configure your AWS credentials
aws configure

# 4. Deploy
terraform init
terraform plan
terraform apply
```

After `apply` completes, your resource details will appear in the terminal:

```
sns_topic_arn              = "arn:aws:sns:us-east-1:xxxxxxxxxxxx:monitoring-alerts"
lambda_function_name       = "monitoring-function"
cloudwatch_dashboard_url   = "https://us-east-1.console.aws.amazon.com/cloudwatch/..."
lambda_errors_alarm_name   = "monitoring-lambda-errors"
lambda_duration_alarm_name = "monitoring-lambda-duration"
```

To tear down all resources:

```bash
terraform destroy
```
