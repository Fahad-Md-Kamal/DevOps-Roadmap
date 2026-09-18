---
title: Databases (RDS)
---

# Databases: RDS, SQL & Data Management

## Overview

### 7.1 Multi-AZ & Read Replicas

Two different features that solve different problems:

| Feature | Multi-AZ | Read Replica |
|---|---|---|
| **Purpose** | High availability (failover) | Read scaling (performance) |
| **Replication** | Synchronous — standby always matches primary | Asynchronous — may lag seconds behind |
| **Can you read from it?** | No — standby is dormant until failover | Yes — send read queries to it |
| **Failover** | Automatic, ~60 seconds, same endpoint | Manual — must promote to standalone |
| **Cross-region?** | No (same region, different AZ) | Yes — can be in another region (for DR) |
| **Cost** | Double (two instances running) | Additive (each replica is an extra instance) |

!!! success "For the ramp plan"

    Enable Multi-AZ for production (automatic failover). Add read replicas only when you have read-heavy queries that overwhelm the primary. For learning, single-AZ is fine — Multi-AZ doubles the RDS cost.

#### CLI: Create an RDS instance

``` bash
# 1. Create a DB subnet group (tells RDS which subnets to use)
aws rds create-db-subnet-group \
  --db-subnet-group-name fahad-db-subnets \
  --db-subnet-group-description "Private DB subnets for ecommerce" \
  --subnet-ids subnet-0eee5555eeee55555 subnet-0fff6666ffff66666

# 2. Create the RDS instance (single-AZ for learning, saves cost)
aws rds create-db-instance \
  --db-instance-identifier fahad-ecommerce-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16 \
  --master-username ecomadmin \
  --master-user-password '<USE_A_STRONG_PASSWORD>' \
  --allocated-storage 20 \
  --db-subnet-group-name fahad-db-subnets \
  --vpc-security-group-ids <DB_SG_ID> \
  --backup-retention-period 7 \
  --no-publicly-accessible \
  --storage-encrypted \
  --tags Key=Name,Value=fahad-ecommerce-db \
         Key=Environment,Value=dev \
         Key=Owner,Value=fahad

# 3. Check status (takes 5-10 minutes to become "available")
aws rds describe-db-instances \
  --db-instance-identifier fahad-ecommerce-db \
  --query "DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port}" \
  --output table

# 4. Get the connection endpoint (once available)
aws rds describe-db-instances \
  --db-instance-identifier fahad-ecommerce-db \
  --query "DBInstances[0].Endpoint.Address" \
  --output text

# 5. Create a read replica (for read scaling later)
aws rds create-db-instance-read-replica \
  --db-instance-identifier fahad-ecommerce-db-read \
  --source-db-instance-identifier fahad-ecommerce-db

# 6. Force a Multi-AZ failover (for testing DR)
aws rds reboot-db-instance \
  --db-instance-identifier fahad-ecommerce-db \
  --force-failover

# Delete RDS (skip final snapshot for dev)
aws rds delete-db-instance \
  --db-instance-identifier fahad-ecommerce-db \
  --skip-final-snapshot
```

!!! danger "Cost"

    `db.t3.micro` is free tier (750 hrs/month). Multi-AZ doubles it. Don't forget to delete the RDS instance when done studying — unlike EC2, there's no "stop" for single-AZ RDS (Multi-AZ can be stopped for up to 7 days).

#### Splitting reads to the replica in Django

A read replica does nothing by itself — your app has to be told to send read queries there. Django's multi-database routing handles this:

``` python
# settings.py
DATABASES = {
    'default': {  # primary — all writes
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': 'fahad-ecommerce-db.xxxxx.ap-south-1.rds.amazonaws.com',
    },
    'replica': {  # read replica — reads only
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': 'fahad-ecommerce-db-read.xxxxx.ap-south-1.rds.amazonaws.com',
    },
}

# A router that sends reads to the replica, writes to the primary
class ReplicaRouter:
    def db_for_read(self, model, **hints):
        return 'replica'
    def db_for_write(self, model, **hints):
        return 'default'

DATABASE_ROUTERS = ['myapp.routers.ReplicaRouter']
```

!!! note "Replication lag is real"

    A read immediately after a write can hit the replica before the write has replicated — a user submits a form, gets redirected, and doesn't see their own data yet. Read-your-own-writes flows (checkout confirmation, profile update) should read from `default`, not `replica`.

#### Promoting a read replica

If the primary needs replacing permanently (not a failover — a deliberate migration), a replica can be promoted to a standalone, writable instance. This is one-way — you can't turn it back into a replica afterward.

``` bash
aws rds promote-read-replica \
  --db-instance-identifier fahad-ecommerce-db-read \
  --backup-retention-period 7 \
  --profile fahad
```

#### Watching replica lag

``` bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=fahad-ecommerce-db-read \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum \
  --profile fahad
```

Measured in seconds. A steadily growing number means the replica can't keep up with write volume — usually a sign to upsize the replica's instance class, not just tolerate the lag.

### 7.2 Backups & Point-in-Time Recovery

RDS automated backups give you two things:

- **Daily snapshots:** full backup taken during your backup window
- **Transaction logs:** captured every 5 minutes, stored in S3

Together, these let you restore to **any second** within your retention window (up to 35 days).

``` bash
# Restore to a specific point in time — creates a NEW instance
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier my-prod-db \
  --target-db-instance-identifier my-prod-db-restored \
  --restore-time "2026-09-03T10:30:00Z"
```

!!! danger "Critical"

    Point-in-time recovery creates a **new** RDS instance — it does NOT overwrite the existing one. You must update your app's connection string to point to the new instance. Plan for this in your runbook.

#### Manual snapshots vs automated backups

Automated backups
:   Run inside your configured backup window, deleted automatically when the instance is deleted (unless you keep a final snapshot). Feed the point-in-time recovery window.

Manual snapshots
:   You trigger these yourself, they persist forever until you delete them — even after the source instance is gone. This is what you take before a risky migration, and what you copy to another region for disaster recovery.

``` bash
# Set the automated backup window and retention
aws rds modify-db-instance \
  --db-instance-identifier fahad-ecommerce-db \
  --backup-retention-period 7 \
  --preferred-backup-window "17:00-17:30" \
  --apply-immediately \
  --profile fahad

# Take a manual snapshot before a risky change
aws rds create-db-snapshot \
  --db-instance-identifier fahad-ecommerce-db \
  --db-snapshot-identifier fahad-ecommerce-db-pre-migration-$(date +%Y%m%d) \
  --profile fahad

# Copy a snapshot to another region (DR)
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:ap-south-1:111122223333:snapshot:fahad-ecommerce-db-pre-migration-20260903 \
  --target-db-snapshot-identifier fahad-ecommerce-db-pre-migration-20260903-eu \
  --source-region ap-south-1 \
  --region eu-west-1 \
  --profile fahad

# Restore an instance FROM a snapshot (different from point-in-time restore)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier fahad-ecommerce-db-restored \
  --db-snapshot-identifier fahad-ecommerce-db-pre-migration-20260903 \
  --profile fahad
```

!!! note "Backup window vs maintenance window"

    The backup window and the maintenance window (for engine patches) must not overlap — RDS won't let a patch and a backup fight for the same I/O at once. Pick windows in your lowest-traffic hours, offset by a few hours from each other.

### 7.3 Parameter Groups

Database engine configuration — PostgreSQL settings like `max_connections`, `shared_buffers`, `work_mem`. Applied to an instance or cluster.

The default parameter group is read-only. Create a custom one to tune settings:

``` bash
aws rds create-db-parameter-group \
  --db-parameter-group-name ecommerce-pg16 \
  --db-parameter-group-family postgres16 \
  --description "Tuned for ecommerce workload"
```

!!! note "Reboot required"

    Some parameter changes (like `shared_buffers`) require a reboot to take effect. Others (like `work_mem`) apply immediately. The console shows "pending-reboot" for the ones that need it.

#### Attach it, tune a value, apply it

``` bash
# Attach the custom parameter group to the instance
aws rds modify-db-instance \
  --db-instance-identifier fahad-ecommerce-db \
  --db-parameter-group-name ecommerce-pg16 \
  --apply-immediately \
  --profile fahad

# Change a dynamic parameter — takes effect without a reboot
aws rds modify-db-parameter-group \
  --db-parameter-group-name ecommerce-pg16 \
  --parameters "ParameterName=work_mem,ParameterValue=16384,ApplyMethod=immediate" \
  --profile fahad

# Change a static parameter — queued until the next reboot
aws rds modify-db-parameter-group \
  --db-parameter-group-name ecommerce-pg16 \
  --parameters "ParameterName=shared_buffers,ParameterValue={DBInstanceClassMemory/32768},ApplyMethod=pending-reboot" \
  --profile fahad

# Check what's pending vs applied
aws rds describe-db-instances \
  --db-instance-identifier fahad-ecommerce-db \
  --query "DBInstances[0].DBParameterGroups[0].ParameterApplyStatus" \
  --output text \
  --profile fahad
```

!!! danger "Parameter groups aren't per-instance"

    The same parameter group can be attached to multiple instances. Changing it changes the config for every instance using it — don't tune "just for one database" without first checking `describe-db-instances` for who else is attached to that group.

### 7.4 Safe SQL Operations

#### Transaction-safe destructive queries

Never run UPDATE or DELETE without a transaction wrapper. This pattern saves you from accidental data destruction:

``` sql
BEGIN;

-- See what will be affected FIRST
SELECT count(*) FROM orders WHERE status = 'cancelled' AND created_at < '2026-01-01';

-- If the count looks right, proceed
DELETE FROM orders WHERE status = 'cancelled' AND created_at < '2026-01-01';

-- Verify the result
SELECT count(*) FROM orders WHERE status = 'cancelled' AND created_at < '2026-01-01';
-- Should be 0

-- Only then commit — or ROLLBACK if something looks wrong
COMMIT;
```

#### Reverse-out scripts

Before running any migration or data change, write the script that undoes it. Store it alongside the change:

```
migrations/
├── 042_add_full_name_column.sql         ← the forward migration
├── 042_add_full_name_column_REVERSE.sql ← the undo script
└── 042_add_full_name_column_README.md   ← what it does and when it was run
```

Test the reverse script **before** you run the forward migration. If you can't undo it cleanly, that changes your deployment plan (you need a longer bake time before committing).

#### Connecting to a private RDS instance

Your database has no public IP — `psql` from your laptop can't reach it directly. Tunnel through an instance inside the VPC using Session Manager, no bastion or open SSH port needed:

``` bash
aws ssm start-session \
  --target <INSTANCE_ID_IN_VPC> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["fahad-ecommerce-db.xxxxx.ap-south-1.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["5433"]}' \
  --profile fahad

# In another terminal, connect through the tunnel
psql -h localhost -p 5433 -U ecomadmin -d postgres
```

#### Batching destructive changes on large tables

A single `UPDATE` or `DELETE` touching millions of rows holds locks for the whole duration and can bloat the transaction log. Batch it instead:

``` sql
-- Instead of one giant UPDATE, loop in batches
DO $$
DECLARE
  rows_affected INT;
BEGIN
  LOOP
    UPDATE orders SET archived = true
    WHERE id IN (
      SELECT id FROM orders WHERE archived = false AND created_at < '2024-01-01' LIMIT 1000
    );
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    EXIT WHEN rows_affected = 0;
    COMMIT;
  END LOOP;
END $$;
```

!!! note "Maintenance window awareness"

    Schedule large batch operations outside RDS's maintenance window and outside your backup window (7.2) — a patch, a backup, and a million-row batch job all competing for I/O at once is how a routine migration turns into an incident.

### 7.5 EXPLAIN Plans

When a query is slow, `EXPLAIN ANALYZE` shows you exactly what PostgreSQL is doing:

``` sql
EXPLAIN ANALYZE
SELECT o.id, o.total, u.email
FROM orders o
JOIN users u ON u.id = o.user_id
WHERE o.status = 'pending'
AND o.created_at > '2026-08-01';
```

What to look for in the output:

- **Seq Scan on a large table:** missing index. Add one on the filtered columns.
- **Nested Loop with high row count:** bad join order or missing index on the join column.
- **Sort with high cost:** consider adding an index that matches the ORDER BY.
- **Actual rows ≫ estimated rows:** stale statistics. Run `ANALYZE tablename;`

!!! success "Your Django context"

    Django's ORM generates SQL you don't always see. Use `django-debug-toolbar` or `queryset.query` to inspect the SQL, then run EXPLAIN on the slow ones directly in psql.

#### Reading the plan tree

Plans nest — the innermost (most indented) lines run first, feeding rows up to the operations above them. Two costs matter per node:

```
Nested Loop  (cost=0.43..8.45 rows=1 width=40) (actual time=0.03..0.05 rows=1 loops=1)
  ->  Index Scan using orders_status_idx on orders o  (cost=0.29..4.30 ...)
  ->  Index Scan using users_pkey on users u  (cost=0.14..4.15 ...)

cost=START..TOTAL   — PostgreSQL's own estimate, in arbitrary units, before running
actual time=START..TOTAL rows=N loops=M — what really happened when EXPLAIN ANALYZE ran it
                                          (multiply time by loops for the real total)
```

The gap between the estimated `rows=` and the actual `rows=` is the single most useful number on the page — a huge gap means the planner is choosing a bad strategy because its statistics are wrong, not because the query itself is bad.

#### `BUFFERS` — is it even hitting disk?

``` sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.id, o.total, u.email
FROM orders o
JOIN users u ON u.id = o.user_id
WHERE o.status = 'pending';
```

`shared hit` = read from cache (fast). `shared read` = read from disk (slow). A query that's fast in your test but slow in production is often the same query hitting a cold cache instead of a warm one — `BUFFERS` is how you tell the difference from the plan alone, without guessing.

#### Adding the index this query is missing

``` sql
-- Matches the WHERE clause from the query above
CREATE INDEX CONCURRENTLY idx_orders_status_created
  ON orders (status, created_at)
  WHERE status = 'pending';

-- Confirm the planner picked it up
EXPLAIN ANALYZE
SELECT o.id, o.total, u.email
FROM orders o JOIN users u ON u.id = o.user_id
WHERE o.status = 'pending' AND o.created_at > '2026-08-01';
-- Seq Scan should now read Index Scan (or Bitmap Index Scan)
```

!!! danger "Always CONCURRENTLY in production"

    A plain `CREATE INDEX` takes a lock that blocks writes to the table for the whole build — on a large table that can be minutes of a frozen app. `CREATE INDEX CONCURRENTLY` takes longer and can't run inside a transaction block, but never blocks writes.

#### Finding what to EXPLAIN in the first place

``` sql
-- Requires the pg_stat_statements extension (enable via parameter group: shared_preload_libraries)
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

Sort by `total_exec_time` to find what's costing the most aggregate time (a cheap query called 100,000 times can outweigh a slow query called twice) — that's usually a better place to start than guessing from user complaints.
