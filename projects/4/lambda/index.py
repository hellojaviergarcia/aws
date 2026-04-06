import json
import logging

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Simple Lambda function used as the monitored resource.
    Logs the incoming event and returns a success response.
    """
    logger.info("Event received: %s", json.dumps(event))

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "OK"})
    }
