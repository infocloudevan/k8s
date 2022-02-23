# MAJOR INCIDENT - 05 MAY 2019

## Summary
During the planned upgrade process to the production kubernetes cluster from 1.10 to 1.12, the cluster experienced a period of unavailability, resulting in a full service outage starting at approximately 1425 hours (Eastern), and extending to approximately 1614 hours.

## Description
The kubernetes clusters supporting test and production were running an older, soon-to-be unsupported, version of kubernetes (1.10).  A plan to upgrade both clusters to 1.12, via 1.11, was put into place by the Darkcubed infrastructure team, with the process to be performed initially on test, and then later, if successful, in production during a lesser-usage timeframe.

The upgrade to the test cluster was performed in a two-stage process on Friday, 3 May, using kops to perform the actual upgrades to AWS and kubernetes.  During the first stage, the team upgraded the cluster from 1.10 to 1.11, and in the second to 1.12.  The test cluster is comprised of three separate instance groups, or groups of nodes, designated master, nodes, and syslog.  All three groups reside within the same AWS availablity zone, and the upgrade processes were rolled across each instance group individually, beginning with master, and concluding with syslog.  At the conclusion of the upgrade an additional manual process was identified to reassign public IP addresses to the syslog instances; otherwise, no issues were encountered during the process.

Based on the success and ease of the upgrade to test, the upgrade to production was scheduled to begin at 1900 hours on Saturday, 4 May.  No outages were anticipated, and the process was expected to complete in six hours or less.  In contrast to the test cluster, the production cluster is deployed in a high-availability configuration, spanning three availability zones, with multiple instancegroups representing the master nodes, worker nodes, and syslog nodes.  The process used in test was performed in production, isolating each instance group and performing the upgrade individually, beginning with the masters, and ending with the syslog groups.  Aside from a pod for the mascot application which experienced a memory segmentation fault but failed to terminate automatically, the upgrade from 1.10 to 1.11 progressed without issue and was concluded around 2240 hours.

After the upgrade to 1.11 ran longer than anticipated, the team initiated the first upgrade to 1.12 on one of the three master instance groups as the final act for the evening.  Throughout the course of the night it appeared that the upgrade was not completing successfully, with the instances failing to re-join the cluster, and the calico and coredns services not starting back up successfully.  At about 0818 hours on Sunday, 5 May, the team downgraded the instance group back to 1.11, resulting in a semi-operational state around 0955 hours, with persistent issues related to calico networking services.

Research into the possible problems being experienced revealed a [kops product document](https://github.com/kubernetes/kops/blob/1.12.0-beta.2/docs/etcd3-migration.md), embedded within the sub-component tree, related to the upgrade from etcd2 to etcd3 as part of the upgrade process to 1.12.  This document identifies the upgrade as a _higher risk_ upgrade, specifically with regards to high-availability scenarios.  The document further details how the migration to etcd3 will be disruptive to the masters, and, in conjunction with the upgrade to the calico services, will result in a network partition which will likely be disruptive to the worker nodes as well.  The overall recommendation is to _"quickly roll your masters"_, and then _"rolling your nodes as fast as possible also"_.  Included with the recommendation are the commands to perform the upgrade across all master instance groups effectively at the same time, without requiring the standard validation to confirm the health of the cluster before continuing.

At this time the team attempted to deploy velero backup services for kubernetes, but failed due to the ongoing calico networking issues.  The team performed a scripted export of all kubernetes resource definitions as a potential source for backup materials, prior to any further upgrade activities being performed.

The team initiated the upgrade to 1.12 across all master instance groups as per the recommendation at 1254 hours, with a failure to resume normal operations noted at 1330 hours due to the failure of the api services to start properly.  With no information documented regarding the specific service failures, the team attempted to execute several follow-up processes to recovery an operational state:

* Rolling the upgrade to a worker node without validation at 1358 hours
* Attempting to force the now upgraded masters back to etcd2 at 1425 hours

Ultimately these attempts resulted in a full outage, at which time the team made the decision to delete the master instance groups completely and reconstitue them directly at 1.12.  The team started the creation of new master instance groups around 1528 hours, resulting in the same scenario in which the api services failed to start.  As a last attempt to save the worker nodes, the team performed the upgrade to 1.12 on the remainder of the cluster, at once, without validation.  After about ten minutes, when the new node instances had been created and kubernetes upgrade deployed, the api services on the master nodes started normally, and  services were restored at about 1606 hours.  Once the public IP addresses had been reattached manually, full service was restored at about 1614 hours.

The worker node that had been upgraded prior to the reconstitution of the master nodes failed to join the cluster and was likewise reconstituted without issue.

## Root Cause

Inadequate planning and testing.  Lack of community documentation providing specific and detailed description of the disruptive nature of the upgrade process.

## Responsible Party/Parties

Internal (Infrastructure) - Justin Gluchowski, Bryan Richardson

## Analysis

* kops cluster validation
* docker logs within individual kubernetes master pods
* journald entries within individual kubernetes master pods

## Recommendations

* Establish formal outage/maintenance window
* Communicate planned maintenance activities via established channels
* Perform backups
* Research upgrades
* Identify potential issues and solutions
* Formalize maintenance plan
* Require approval of maintenance plan
* Perform testing in a representative environment
* Utilize cluster migrations vs. upgrades for disruptive updates to prevent outages
* Plan for the worst, hope for the best
* Offer profuse thanks to Bryan and his spousal other

```