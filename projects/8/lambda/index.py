import json
import os
import uuid
import logging
import boto3
from datetime import datetime, timezone, timedelta

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb  = boto3.resource("dynamodb")
table     = dynamodb.Table(os.environ["TABLE_NAME"])
ttl_days  = int(os.environ["TTL_DAYS"])


def handler(event, context):
    """
    Demonstrates core DynamoDB operations:
    - PutItem with TTL
    - GetItem by primary key
    - Query using GSI
    - Scan the full table
    - DeleteItem
    """

    # 1. Write an item with TTL
    item_id  = str(uuid.uuid4())
    category = "demo"
    expires  = int((datetime.now(timezone.utc) + timedelta(days=ttl_days)).timestamp())

    item = {
        "pk":         f"ITEM#{item_id}",
        "sk":         f"METADATA#{item_id}",
        "gsi1pk":     f"CATEGORY#{category}",
        "gsi1sk":     f"ITEM#{item_id}",
        "id":         item_id,
        "category":   category,
        "name":       "Demo item",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "expires_at": expires  # TTL field ; DynamoDB deletes this item automatically
    }

    table.put_item(Item=item)
    logger.info("Item written: %s", item_id)

    # 2. Read the item by primary key
    result = table.get_item(Key={"pk": item["pk"], "sk": item["sk"]})
    logger.info("Item read: %s", json.dumps(result.get("Item", {}), default=str))

    # 3. Query using the GSI
    gsi_result = table.query(
        IndexName="gsi1",
        KeyConditionExpression="gsi1pk = :pk",
        ExpressionAttributeValues={":pk": f"CATEGORY#{category}"}
    )
    logger.info("GSI query returned %d items", gsi_result["Count"])

    # 4. Delete the item
    table.delete_item(Key={"pk": item["pk"], "sk": item["sk"]})
    logger.info("Item deleted: %s", item_id)

    return {
        "statusCode": 200,
        "body": json.dumps({
            "item_id":    item_id,
            "gsi_count":  gsi_result["Count"],
            "ttl_days":   ttl_days,
            "expires_at": expires
        })
    }
