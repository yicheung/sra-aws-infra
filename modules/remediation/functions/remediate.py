"""Counter-defense remediation handler.

Invoked by EventBridge for GuardDuty / Security Hub / Config findings. Maps a
finding to a bounded, auditable remediation. Honors AUTO_REMEDIATE: when "false"
it logs the intended action without mutating anything (dry-run).

Supported remediations (extend as needed):
  * S3 bucket public access  -> apply full public-access block
  * Security group 0.0.0.0/0 on sensitive ports -> revoke the offending rule
"""
import json
import logging
import os

import boto3

log = logging.getLogger()
log.setLevel(logging.INFO)

AUTO = os.environ.get("AUTO_REMEDIATE", "false").lower() == "true"
SNS_TOPIC = os.environ.get("SNS_TOPIC_ARN", "")
SENSITIVE_PORTS = {22, 3389, 3306, 5432, 6379, 9200, 27017}

s3 = boto3.client("s3")
ec2 = boto3.client("ec2")
sns = boto3.client("sns") if SNS_TOPIC else None


def _notify(summary: str, detail: dict) -> None:
    log.info("%s | %s", summary, json.dumps(detail))
    if sns and SNS_TOPIC:
        sns.publish(TopicArn=SNS_TOPIC, Subject=summary[:100], Message=json.dumps(detail, indent=2))


def remediate_s3_public(bucket: str) -> dict:
    action = {"type": "s3_public_access_block", "bucket": bucket, "applied": False}
    if AUTO:
        s3.put_public_access_block(
            Bucket=bucket,
            PublicAccessBlockConfiguration={
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            },
        )
        action["applied"] = True
    return action


def remediate_open_sg(group_id: str) -> dict:
    action = {"type": "revoke_open_ingress", "group_id": group_id, "revoked": []}
    desc = ec2.describe_security_groups(GroupIds=[group_id])["SecurityGroups"][0]
    for perm in desc.get("IpPermissions", []):
        from_p = perm.get("FromPort", 0)
        to_p = perm.get("ToPort", 65535)
        hits = any(from_p <= p <= to_p for p in SENSITIVE_PORTS)
        open_v4 = any(r.get("CidrIp") == "0.0.0.0/0" for r in perm.get("IpRanges", []))
        if hits and open_v4:
            action["revoked"].append({"from": from_p, "to": to_p})
            if AUTO:
                ec2.revoke_security_group_ingress(GroupId=group_id, IpPermissions=[perm])
    return action


def handler(event, _context):
    log.info("event: %s", json.dumps(event)[:2000])
    detail = event.get("detail", {})
    results = []

    # Security Hub / Config shape detection (simplified; extend per source).
    findings = detail.get("findings", [])
    for f in findings:
        for res in f.get("Resources", []):
            rid = res.get("Id", "")
            rtype = res.get("Type", "")
            if rtype == "AwsS3Bucket":
                results.append(remediate_s3_public(rid.split(":")[-1]))
            elif rtype == "AwsEc2SecurityGroup":
                results.append(remediate_open_sg(rid.split("/")[-1]))

    summary = f"Remediation {'APPLIED' if AUTO else 'DRY-RUN'}: {len(results)} action(s)"
    _notify(summary, {"mode": "auto" if AUTO else "dry-run", "actions": results})
    return {"mode": "auto" if AUTO else "dry-run", "actions": results}
