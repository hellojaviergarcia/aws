import json
import os
import uuid
import logging
import boto3
from datetime import datetime, timezone

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(os.environ["TABLE_NAME"])


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path   = event.get("rawPath", "")

    # Extract authenticated user ID from Cognito JWT claims
    claims  = event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {})
    user_id = claims.get("sub", "anonymous")

    if method == "GET" and path.endswith("/tasks"):
        return get_tasks(user_id)

    if method == "POST" and path.endswith("/tasks"):
        body = json.loads(event.get("body", "{}"))
        return create_task(user_id, body)

    if method == "DELETE" and "/tasks/" in path:
        task_id = event.get("pathParameters", {}).get("taskId")
        return delete_task(user_id, task_id)

    return response(405, {"error": "Method not allowed"})


def get_tasks(user_id):
    """Returns all tasks for the authenticated user."""
    result = table.query(
        KeyConditionExpression="userId = :uid",
        ExpressionAttributeValues={":uid": user_id}
    )
    return response(200, result.get("Items", []))


def create_task(user_id, body):
    """Creates a new task for the authenticated user."""
    title = body.get("title", "").strip()

    if not title:
        return response(400, {"error": "Field 'title' is required"})

    item = {
        "userId":     user_id,
        "taskId":     str(uuid.uuid4()),
        "title":      title,
        "status":     "pending",
        "created_at": datetime.now(timezone.utc).isoformat()
    }

    table.put_item(Item=item)
    logger.info("Task created: %s for user %s", item["taskId"], user_id)
    return response(201, item)


def delete_task(user_id, task_id):
    """Deletes a task owned by the authenticated user."""
    if not task_id:
        return response(400, {"error": "taskId is required"})

    table.delete_item(Key={"userId": user_id, "taskId": task_id})
    logger.info("Task deleted: %s for user %s", task_id, user_id)
    return response(200, {"message": f"Task {task_id} deleted"})


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers":    {"Content-Type": "application/json"},
        "body":       json.dumps(body, default=str)
    }
