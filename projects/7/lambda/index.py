import json
import logging

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Processes messages from SQS.
    SQS sends messages in batches ; each record is one message.
    """
    for record in event.get("Records", []):
        body = record.get("body", "")

        try:
            # Try to parse the message as JSON
            message = json.loads(body)

            # SNS wraps the message in a Message field
            if "Message" in message:
                payload = json.loads(message["Message"])
            else:
                payload = message

            logger.info("Message processed: %s", json.dumps(payload))

        except json.JSONDecodeError:
            # If not JSON, log as plain text
            logger.info("Message processed: %s", body)

    return {"statusCode": 200, "body": "OK"}
