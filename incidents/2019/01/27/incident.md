# MAJOR INCIDENT - 27 JAN 2019

## Root Cause

SaaS database ran out of transaction IDs

## Secondary Cause/Effect

SaaS database went into read-only mode, causing writes for incoming data
to fail, causing the job queue to rise.

After updating parameter group for SaaS database, it entered a reboot
loop, causing the Catcher listener to fail, in turn causing Catcher to
enter into CLBO, thus losing Syslog data from customers.

## Analysis

* AWS RDS logs and events
* hyperdark application logs
* database queries
  * `SELECT max(age(datfrozenxid)) FROM pg_database;`

## Remediations

* CloudWatch metric/alarm for `MaximumUsedTransactionIDs`
  * Would be nice to have access to this in Grafana too
    * Submitted a pull request
  * Query for this is `SELECT max(age(datfrozenxid)) FROM pg_database;`
* Increase `autovacuum_max_workers` in parameter group
* Increase `maintenance_work_mem` in parameter group
* Ensure vacuums are run before max transaction ID

## Restoration

* Run vacuums to lower max transaction ID
* If necessary, AWS support can run the vacuum in stand-alone user mode

## Logs

Database restart loop:

```
2019-01-27 17:23:54 UTC::@:[35857]:LOG:  database system is shut down
2019-01-27 17:23:57 UTC::@:[37024]:LOG:  database system was shut down at 2019-01-27 17:23:54 UTC
2019-01-27 17:23:57 UTC::@:[37024]:WARNING:  database with OID 23602 must be vacuumed within 1000000 transactions
2019-01-27 17:23:57 UTC::@:[37024]:HINT:  To avoid a database shutdown, execute a database-wide VACUUM in that database.
        You might also need to commit or roll back old prepared transactions.
2019-01-27 17:23:57 UTC::@:[37024]:LOG:  MultiXact member wraparound protections are now enabled
2019-01-27 17:23:57 UTC::@:[37029]:LOG:  autovacuum launcher started
2019-01-27 17:23:57 UTC::@:[37022]:LOG:  database system is ready to accept connections
2019-01-27 17:23:57 UTC:172.20.171.104(33698):dark3@dark3:[37025]:FATAL:  the database system is starting up
2019-01-27 17:24:55 UTC::@:[37022]:LOG:  received fast shutdown request
2019-01-27 17:24:55 UTC::@:[37022]:LOG:  aborting any active transactions
2019-01-27 17:24:55 UTC:172.20.171.104(53678):dark3@dark3:[37949]:FATAL:  terminating connection due to administrator command
```

## Response from AWS

```
Dear Amazon RDS customer,

The RDS instance 'saas-testing' has encountered transaction-wraparound
and was crashing during the reboot which you had requested on 2019-01-27
17:09:55 UTC. To fix this issue, we have initiated a standalone vacuum
to recover it. This instance will be unavailable until the standalone
vacuum has finished.

I hope that this information was helpful. If you have any related
questions or concerns you feel are not being addressed currently please
do let me know and I'll reply as soon as possible. If you need immediate
assistance please initiate a chat or a call and you will get routed to
the next available engineer.

Best regards,

Blake L.
Amazon Web Services
```
