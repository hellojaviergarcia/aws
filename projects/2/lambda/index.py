import json
import os
import uuid
import boto3
from datetime import datetime, timezone

# DynamoDB client; initialised outside the handler so it can be reused across invocations
dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(os.environ["TABLE_NAME"])


def handler(event, context):
    """
    The Lambda's entry point.
    API Gateway sends the HTTP method and the route in the event.
    """
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path   = event.get("rawPath", "")

    # Route using the HTTP method
    if method == "GET" and path.endswith("/todos"):
        return get_todos()

    if method == "POST" and path.endswith("/todos"):
        body = json.loads(event.get("body", "{}"))
        return create_todo(body)

    if method == "DELETE" and "/todos/" in path:
        todo_id = event.get("pathParameters", {}).get("id")
        return delete_todo(todo_id)

    return response(405, {"error": "Method not allowed"})


# Handlers

def get_todos():
    """Returns all tasks stored in DynamoDB."""
    result = table.scan()
    return response(200, result.get("Items", []))


def create_todo(body):
    """Create a new task with a unique ID."""
    title = body.get("title", "").strip()

    if not title:
        return response(400, {"error": "The 'title' field is mandatory"})

    item = {
        "id":         str(uuid.uuid4()),  # Automatically generated unique ID
        "title":      title,
        "done":       False,
        "created_at": datetime.now(timezone.utc).isoformat()
    }

    table.put_item(Item=item)
    return response(201, item)


def delete_todo(todo_id):
    """Delete a task by its ID."""
    if not todo_id:
        return response(400, {"error": "ID not provided"})

    table.delete_item(Key={"id": todo_id})
    return response(200, {"message": f"Task {todo_id} deleted"})


# Usefulness

def response(status_code, body):
    """Format the response in the format expected by API Gateway."""
    return {
        "statusCode": status_code,
        "headers":    {"Content-Type": "application/json"},
        "body":       json.dumps(body, ensure_ascii=False)
    }
