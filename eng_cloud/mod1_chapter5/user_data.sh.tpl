#!/bin/bash
set -euo pipefail

yum install -y python3 python3-pip jq
pip3 install boto3

cat <<'WORKER' > /opt/worker.py
import boto3
import json
import time
import os

sqs = boto3.client("sqs", region_name="${aws_region}")
QUEUE_URL = "${queue_url}"

def process_message(message):
    body = json.loads(message["Body"])
    print(f"Processing: bucket={body['bucket']}, key={body['key']}, size={body['size']}")
    # Add your data processing logic here
    time.sleep(2)
    print(f"Done processing: {body['key']}")

def main():
    print("Worker started, polling SQS...")
    while True:
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20,
        )
        messages = response.get("Messages", [])
        for msg in messages:
            try:
                process_message(msg)
                sqs.delete_message(
                    QueueUrl=QUEUE_URL,
                    ReceiptHandle=msg["ReceiptHandle"],
                )
            except Exception as e:
                print(f"Error processing message: {e}")

if __name__ == "__main__":
    main()
WORKER

nohup python3 /opt/worker.py > /var/log/worker.log 2>&1 &
