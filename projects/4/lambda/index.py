import json
import logging

# Configure the root logger at INFO level.
# Lambda automatically captures anything written to the root logger
# and sends it to the CloudWatch log group for this function.
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Lambda entry point. Called on every invocation.

    This function is intentionally simple ; its purpose is to serve
    as a monitored resource that generates CloudWatch logs and metrics.
    In a real project, this would contain your application's business logic.

    Args:
        event:   The input data passed to the function (dict).
                 When invoked manually, this can be any JSON object.
        context: Runtime information provided by Lambda (function name,
                 remaining time, request ID, etc.). Not used here.

    Returns:
        A dict with statusCode and body ; the standard Lambda response format.
    """
    # Log the full incoming event at INFO level.
    # This log entry will appear in CloudWatch Logs under the function's log group.
    logger.info("Event received: %s", json.dumps(event))

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "OK"})
    }
