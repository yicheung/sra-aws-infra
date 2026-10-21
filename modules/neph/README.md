# Neph module

Attack-path graphing host. Steampipe collects AWS state (read-only via the
instance profile), Neo4j stores the graph, the simulator computes paths.

## Access (SSM port-forward, no public ingress)
```bash
# Neo4j browser
aws ssm start-session --target <instance_id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters 'portNumber=7474,localPortNumber=7474'
```

## Collection workflow (on the host)
```bash
cd /opt/neph
docker compose up -d simulator steampipe neo4j
pip install .                       # install the neph CLI
neph ingest sql --mode bulk --create-fixtures
# Org / IdentityCenter data:
#   run scripts in ingest_scripts/ then: neph ingest jsonl <output>
neph path leads --all               # compute attack-path leads
```

## Permissions
The instance profile attaches **SecurityAudit** + **ViewOnlyAccess** only. For
Organization-wide graphing set `load_aws_org = true` (grants Organizations/SSO
*list/describe* read actions) and run from the management account.

## Finalize before first run
The user-data clones the repo and writes `.env` + `config/aws.spc`. Review
`docker-compose.example.yml` and mount `config/aws.spc` into the steampipe
container and set the neo4j auth password to the generated value before
`docker compose up`.
