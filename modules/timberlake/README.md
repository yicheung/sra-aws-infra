# TimberLake module (offensive emulation runner)

> **Safety:** TimberLake executes adversary-emulation test cases. Point it only
> at a dedicated **non-production** account. This module refuses to build unless
> `target_account_id` is in `allowed_target_account_ids` and differs from the
> account the runner is deployed in.

## What this provisions
- A Fargate cluster + task definition for the runner (no public ingress).
- A task role that may **only** assume the scoped role in the target account and
  read the VECTR API key secret — it holds no attack permissions itself.
- A Secrets Manager entry for the VECTR GraphQL API key.

## What you provide
1. **Target role** — in the non-prod account, create `target_role_name` trusting
   this runner's `task_role_arn`, scoped to exactly what your test cases touch.
2. **Runner image** — build a container that installs
   `timberlake` + `py-attire-schema`, clones your `testcases_repo`, assumes the
   target role, and runs `timberlake -c config.yml`. Push to ECR and set it as
   the task image.
3. **Test cases** — authored in your own repo (not bundled here). See SRA's
   `timberlake/examples` for the YAML schema (`name`, `mitre`, `permissions`,
   `steps[].block{phase,type,content}`).
4. **VECTR API key** — create in VECTR, store in `vectr_api_secret_arn`.

## Config (config.yml, baked into your image or mounted)
```yaml
profiles: ["default"]
testcases: { directory: "/testcases", recurse: "yes" }
vectr:
  use_vectr: true
  host: "<vectr_host>"
  api_credentials: { access_key: "...", secret_key: "..." }  # from the secret
  assessment: "AWS Emulation"
  database: "default"
  attire_log: "/tmp/attire.json"
```

## Run
```bash
aws ecs run-task --cluster <cluster_arn> --launch-type FARGATE \
  --task-definition <task_definition_arn> \
  --network-configuration "awsvpcConfiguration={subnets=[<subnet_ids>],securityGroups=[<sg>]}"
```
Results land in VECTR tagged `timberlake`.
