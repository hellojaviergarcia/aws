import json
import os
import uuid
import boto3
from datetime import datetime, timezone

# Initialising the DynamoDB client outside the handler is a performance best practice.
# Lambda reuses the same execution environment across warm invocations,
# so the client is created once and reused rather than on every request.
dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(os.environ["TABLE_NAME"]) # Table name injected via environment variable


def handler(event, context):
    """
    Lambda entry point. Called by API Gateway on every HTTP request.

    API Gateway v2 (payload format 2.0) sends the HTTP method inside
    event["requestContext"]["http"]["method"] and the full path in event["rawPath"].

    We use path.endswith() instead of exact equality because the raw path
    includes the stage prefix (e.g. /prod/todos instead of /todos).
    """
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path   = event.get("rawPath", "")

    if method == "GET" and path.endswith("/todos"):
        return get_todos()

    if method == "POST" and path.endswith("/todos"):
        body = json.loads(event.get("body", "{}"))
        return create_todo(body)

    if method == "DELETE" and "/todos/" in path:
        # Path parameters are available under event["pathParameters"]
        # API Gateway parses {id} from the route template and injects it here
        todo_id = event.get("pathParameters", {}).get("id")
        return delete_todo(todo_id)

    return response(405, {"error": "Method not allowed"})


# ── Handlers ─────────────────────────────────────────────────

def get_todos():
    """
    Returns all tasks from DynamoDB using a full table Scan.
    Scan reads every item in the table ; acceptable for small datasets.
    For large tables, consider using Query with a GSI instead.
    """
    result = table.scan()
    return response(200, result.get("Items", []))


def create_todo(body):
    """
    Creates a new task with an auto-generated UUID as the primary key.
    Returns 400 if the title field is missing or empty.
    Returns 201 with the created item on success.
    """
    title = body.get("title", "").strip()

    if not title:
        return response(400, {"error": "The 'title' field is mandatory"})

    item = {
        "id":         str(uuid.uuid4()),               # uuid4 generates a random, globally unique ID
        "title":      title,
        "done":       False,                            # Default status for new tasks
        "created_at": datetime.now(timezone.utc).isoformat() # ISO 8601 timestamp in UTC
    }

    table.put_item(Item=item) # Writes the item to DynamoDB ; overwrites if id already exists
    return response(201, item)


def delete_todo(todo_id):
    """
    Deletes a task by its primary key (id).
    DynamoDB's delete_item is idempotent ; deleting a non-existent item does not raise an error.
    """
    if not todo_id:
        return response(400, {"error": "ID not provided"})

    table.delete_item(Key={"id": todo_id})
    return response(200, {"message": f"Task {todo_id} deleted"})


# ── Utility ──────────────────────────────────────────────────

def response(status_code, body):
    """
    Formats the return value in the structure expected by API Gateway v2.
    The statusCode, headers and body fields are all required.
    ensure_ascii=False preserves non-ASCII characters (e.g. accented letters) in the response.
    """
    return {
        "statusCode": status_code,
        "headers":    {"Content-Type": "application/json"},
        "body":       json.dumps(body, ensure_ascii=False)
    }
