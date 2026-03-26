import json
import os
import boto3
import urllib.parse

sqs = boto3.client("sqs")
s3 = boto3.client("s3")

QUEUE_URL = os.environ["SQS_QUEUE_URL"]


def lambda_handler(event, context):
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        size = record["s3"]["object"].get("size", 0)
        etag = record["s3"]["object"].get("eTag", "")

        head = s3.head_object(Bucket=bucket, Key=key)

        message = {
            "bucket": bucket,
            "key": key,
            "size": size,
            "etag": etag,
            "content_type": head.get("ContentType", "unknown"),
            "last_modified": str(head.get("LastModified", "")),
        }

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message),
        )

        print(f"Sent job to SQS: bucket={bucket}, key={key}, size={size}")

    return {"statusCode": 200, "body": f"Processed {len(event['Records'])} records"}
