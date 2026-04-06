import json
import os
import logging
import boto3

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

bedrock    = boto3.client("bedrock-runtime", region_name="us-east-1")
model_id   = os.environ["MODEL_ID"]
max_tokens = int(os.environ["MAX_TOKENS"])


def handler(event, context):
    """
    Receives a chat message, sends it to Amazon Bedrock
    and returns the model response.
    """
    try:
        body       = json.loads(event.get("body", "{}"))
        message    = body.get("message", "").strip()

        if not message:
            return response(400, {"error": "Field 'message' is required"})

        logger.info("Message received: %s", message)

        # Build the request payload for Claude via Bedrock
        payload = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": max_tokens,
            "messages": [
                {
                    "role": "user",
                    "content": message
                }
            ]
        }

        # Invoke the Bedrock model
        bedrock_response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(payload),
            contentType="application/json",
            accept="application/json"
        )

        result = json.loads(bedrock_response["body"].read())
        reply  = result["content"][0]["text"]

        logger.info("Response generated: %s", reply[:100])

        return response(200, {"reply": reply})

    except Exception as e:
        logger.error("Error: %s", str(e))
        return response(500, {"error": "Internal server error"})


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers":    {
            "Content-Type":                "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }
