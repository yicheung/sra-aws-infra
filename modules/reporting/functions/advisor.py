"""AI remediation advisor.

Triggered by EventBridge on Security Hub findings. For each finding it asks a
Bedrock model for a concise, reviewable remediation plan (root cause, least-priv
fix, and a Terraform/Config-rule sketch), then records the finding + the drafted
guidance in the remediation-tracking DynamoDB table with status OPEN.

The model only ADVISES. Nothing here mutates infrastructure; a human promotes
accepted guidance into the IaC repo.
"""
import json
import logging
import os
import time

import boto3

log = logging.getLogger()
log.setLevel(logging.INFO)

TABLE = os.environ["TRACKER_TABLE"]
MODEL = os.environ.get("BEDROCK_MODEL_ID", "")
ENABLE_AI = os.environ.get("ENABLE_AI", "true").lower() == "true"

ddb = boto3.resource("dynamodb").Table(TABLE)
bedrock = boto3.client("bedrock-runtime") if ENABLE_AI else None

PROMPT = """You are a cloud security remediation assistant. Given this AWS \
Security Hub finding, respond with:
1. Root cause (one sentence).
2. Least-privilege remediation steps.
3. A short Terraform or AWS Config rule sketch to prevent recurrence.
Be concise and do not invent resource names. Finding:
{finding}"""


def _advise(finding: dict) -> str:
    if not (ENABLE_AI and bedrock and MODEL):
        return "AI advisor disabled; manual review required."
    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 700,
        "messages": [{"role": "user", "content": PROMPT.format(finding=json.dumps(finding)[:4000])}],
    }
    resp = bedrock.invoke_model(modelId=MODEL, body=json.dumps(body))
    payload = json.loads(resp["body"].read())
    return "".join(b.get("text", "") for b in payload.get("content", []))


def handler(event, _context):
    findings = event.get("detail", {}).get("findings", [])
    written = 0
    for f in findings:
        fid = f.get("Id", f"unknown-{int(time.time())}")
        guidance = _advise(f)
        ddb.put_item(Item={
            "finding_id": fid,
            "title": f.get("Title", "")[:500],
            "severity": f.get("Severity", {}).get("Label", "UNKNOWN"),
            "account": f.get("AwsAccountId", ""),
            "resource": json.dumps(f.get("Resources", []))[:2000],
            "status": "OPEN",
            "ai_guidance": guidance[:8000],
            "updated_at": int(time.time()),
        })
        written += 1
    log.info("recorded %d finding(s)", written)
    return {"recorded": written}
