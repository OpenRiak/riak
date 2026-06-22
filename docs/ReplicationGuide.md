---
title: Replication and Reconciliation
nav_order: 7
layout : default
---

# Riak KV - Replication and Reconciliation

In the evolution of Riak, there have been two generations of solutions developed to support replication and reconciliation between clusters:

- The now legacy, [`riak_repl` replication](#legacy-replication---riak_repl) which was the recommended replication approach prior to Riak 3.0.10.
  - The `riak_repl` application has evolved through multiple versions of a real-time replication, that supported a push-based model to reliably deliver changes from a source cluster to a sink cluster;
  - The replication approach is backed-up by a reconciliation approach focused on time-consuming key-by-key comparisons, running in the background between clusters on a vnode-by-vnode basis.
- The NextGen replication solution which is the recommended approach in Riak 3.4.
  - The real-time replication approach is by comparison a pull-based model, to allow a sink cluster to fetch results from the source;
  - The replication approach is backed-up with reconciliation through rapid low-cost comparisons between the state of clusters using anti-entropy information, where the comparisons run reliably between clusters with different configurations (e.g. ring-size, node count or n_val).

This guide covers the NextGen replication solution, and further information on alternatives are linked from the [legacy replication section](#legacy-replication---riak_repl).

Replication is considered to have three stages:

- Seeding; populating data in one cluster from another cluster.
  - Not covered in this guide.
  - The recommended approach to seeding using `repl_keys_range` is explained as part of [the AAE Fold API guide](./OtherAPI.md#aae-fold-api).
- **Real-time replication**; the forwarding of changes between connected clusters as they occur.
- **Reconciliation**; determining if two clusters have the same data at the same version, and automatically resolving any deltas that exist.

Real-time replication is asynchronous in Riak, the availability and performance of one cluster should have no impact on the clusters replicating to it.  With asynchronous replication, under-pinning the system with reconciliation is important to reduce the need for operator intervention.  Simple replication failures should not need to prompt operator activity, as the failure will eventually be automatically resolved.

{: .highlight }
> The speed and efficiency of inter-cluster reconciliation is a key feature of Riak.  It is normal in production systems to verify clusters are reconciled every few minutes, with the process taking less than 10s, even when clusters contain more than 10 billion objects.

The guide is split into the following sections:

- [An overview of the concepts](#overview).
- [Configuration of real-time replication](#configuration-of-real-time-replication).
- [Configuration of all-cluster reconciliation](#configuration-of-all-cluster-reconciliation).
- [Configuration of per-bucket reconciliation](#configuration-of-per-bucket-reconciliation).
- [Managing a cluster migration](#migrating-a-cluster).
- [The external Replication API](#replication-api).
- [Operations and the troubleshooting of replication](#monitoring-and-runtime-changes).
- [Configuring `riak_repl`](#legacy-replication---riak_repl).
- [Replication scope](#replication-scope).

## Overview

The Riak replication and reconciliation (full-sync) system has the following features:

- Allows for replication between clusters with different ring sizes, `n_val`s and node counts.
- Uses a pull model for real-time replication with low-cost queueing;
  - Support for low-impact suspension and resumption of replication,
  - Prevents recipient clusters from being overwhelmed by replicated PUT volumes.
- Provides very efficient reconciliation to confirm whole clusters are synchronised;
  - i.e. Confirmation that across multiple clusters all objects are at the same version.
- Efficient and fast resolution of small deltas between clusters;
  - With a specific focus on accelerating the recovery of recently occurring deltas (e.g. following a failure or real-time replication).
- Uses an API which is reusable for replication to and reconciliation with non-Riak databases.

The replication and reconciliation system works with these caveats:

- Reconciliation checks alone are slow to resolve very large deltas between clusters;
  - Partial re-seeding may be prompted where deltas are large, to accelerate the process.
- No support for complex replication topologies with loop prevention;
  - Every peer relationship between clusters must be formed directly.
- When not used exclusively with a leveled backend, a parallel keystore is required (which is shared with internal anti-entropy).

In Riak, replication and reconciliation are designed to be complementary processes.  Although it is possible to configure replication without reconciliation, and vice versa, it is assumed that normally both replication and reconciliation will be active concurrently.

Within the replication system, for any replication event, there is a **source** and a **sink**.  The source is the cluster which has an update of interest to another cluster, and the sink is a system that attempts to fetch a replication event from that cluster.

Replication and reconciliation is built on the following support infrastructure:

- [Queues and workers](#concepts---queues-and-workers);
- [Replication references](#concepts---replication-references);
- [Replication triggers](#concepts---replication-triggers).

### Concepts - Queues and Workers

Replication queues use the [disk-backed queue framework](./RiakTheoryGuide.md#disk-backed-queues) common across multiple Riak services.

Replication references, which are primarily newly coordinated PUTs, are sent to the replication source queue process.  The real-time replication source then assesses which replication queues require that reference:

- Each node must be configured with a separate queue for each cluster or external service that is expected to receive replication events.
  - Each replication event will be duplicated to all queues relevant to that event, but only on one node within the cluster.
- Each queue is split by priority, so that real-time events are consumed prior to any events related to batch or reconciliation activity.
- Queues that grow beyond a configurable size are persisted to disk to manage the memory overhead of replication.
- The queues are all temporary (even when persisting to disk); replication references will be lost on node failure or on node restart.
  - Failures in real-time replication need to be recovered through reconciliation.

A Sink cluster, that is to receive replication events, must have sink workers configured to read from remote queues on Source clusters:

- Sink workers must be configured to point to at least one node in the Source cluster.
  - They may be configured to automatically discover other nodes within the cluster from that node.
- A sink worker can only be configured to read from one Source queue (by name) - but that name can exist on multiple nodes and/or clusters.  For a sink node to receive updates from multiple clusters, consistent queue names should be used across the source clusters.
  - Queue names are used to identify the entity interested in receiving the event.

The number of sink workers can be configured on the node:

- The sink workers will be distributed across the source peer nodes (either configured or discovered).
  - The number of workers will constrain the pace at which events can be pulled from a source cluster, and also the PUSH workload that a sink cluster can generate for itself.
- There is an overhead of a sink making requests on the source, so each sink worker will backoff if a request results in no replication events being discovered.
- The sink worker pool does not auto-expand.
  - Sufficient sink workers need to be configured to keep-up with real-time replication, though [this number can be adjusted at runtime](#making-runtime-changes-to-the-sink).
  - There is some protection from over-provisioning but not from under-provisioning.

In handling replication events, sink workers must apply the replicated change into the local cluster, and this uses a specific `PUSH` command.  The sink workers are constrained in that:

- A sink worker can fetch only one object at a time, and must `PUSH` that object into the sink cluster before returning to fetch the next available replication event.
  - Inter-cluster latency will be a factor in the replication throughput achievable by a group of sink workers.
- A sink-worker will never prompt re-replication, it will only `PUSH` that update into the local cluster;
  - The `PUSH` is configured to put an object `asis` and not to be a coordinated change, so that it will **not** be passed to the local replication source queue manager.

Configuring and enabling source queues and sink workers is sufficient to enable real-time replication.  Other replication features (such as full-sync reconciliation) depend on the queues and workers to operate, but require additional configuration to be triggered.

### Concepts - Replication References

A replication reference is an item queued to represent an event which has been prompted for replication.

The reference may be the actual object itself, or a link to fetch the object - the queue will automatically switch to using links not objects as the queue expands.  Where a reference is a proxy for a replicated object, when the object is fetched by the sink worker, the fetch API will automatically return the object from the database i.e. this conversion is managed behind the API on the source, and will be invisible to the sink worker.

### Concepts - Replication Triggers

There are four basic ways of creating replication references: real-time, reconciliation, seeding and garbage collection.

If a node is enabled as a replication source, each PUT that the node coordinates will be sent to the source queue manager to be checked against the source queue configuration, and it will be added to each queue for which there is a configuration match.  The coordinating nodes are normally spread evenly across the cluster; although if a node is in a degraded state, the vnodes on that node are less likely to be chosen as coordinators by the put process.

{: .note }
> PUTs on the deprecated write-once PUT path are not coordinated, and so are incompatible with replication.

If [reconciliation is enabled](#configuration-of-all-cluster-reconciliation), a reconciliation check may result in deltas being discovered.  The node running the check will be automatically configured to queue up replication references for any required object on the node replication queue, where the local version of the object was discovered to be more advanced than the object in the remote cluster.

It is also possible for reconciliation to be bidirectional, so that a check can prompt a remote peer to queue a replication reference where the remote cluster holds the more advanced version.

{: .highlight }
> Bidirectional reconciliation is at least twice as efficient as one-way reconciliation.

Reconciliation is throttled to repair slowly, so generally only a small number of references will be generated for each full-sync check, even when deltas between clusters are large.

Replication references may also be generated by [AAE folds](./OtherAPI.md#aae-fold-api) when seeding clusters with data, or repairing large deltas.

As AAE folds can prompt large volumes of references, using coverage queries and node_worker pools; the references may be unevenly distributed around the cluster, and also may be concentrated in batches from certain vnodes within sections of the queue.  Over-provisioned sink workers may lead to vnode mailbox overloading due to the unbalanced nature of fetching from AAE folds.

Clusters may also require garbage collection jobs to be enabled using AAE folds - to erase out-of-date keys, and reap tombstones.  These folds will also generate replication references in bulk, and so caution is again required with over-provisioned sink workers.  With garbage collection though, the `tombstone_pause` is applied on every delete or reap makes the problem of overload less probable.

{: .warning }
> Reap jobs should not be scheduled to overlap with cluster administration changes (e.g. joins, leaves or replaces) when replication and reconciliation are enabled.  It is possible that reaps that occur during transfers are not applied correctly, and this may then lead to resource expenditure on reconciliation effort that will ultimately only resurrect reaped tombstones.

Riak can be configured to operate in one of [three possible delete modes](./InstallAndStartGuide.md#configuration-of-riak---delete-mode).  Using a delete mode other than `keep`is tested with replication, but there will be an increased probability of false-negative reconciliation events that may consume resources on the cluster.

{: .note }
> When running replication, it is recommended to change from the default setting and use the delete mode of `keep`.  

It is theoretically possible to prompt replication events through other mechanisms (pre or post commit hooks, or map/reduce jobs).  However, these methods are not subject to any testing as part of the Riak development process.

## Configuration of Real-Time Replication

### Enable a Real-Time Source

There are two configuration items required to set up a source for real-time replication; `replrtq_enablesrc` and `replrtq_srcqueue`.  These are both set via `riak.conf`:

- `replrtq_enablesrc = enabled`;
  - This is the basic configuration required to inform PUT coordinators to pass changes to the replication source queue on the node.
- `replrtq_srcqueue = <sink_cluster_name>:<queue_filter>|<sink_cluster_name>:<queue_filter>` ...
  - The source queue configuration is a pipe-delimited set of queue/filter pairs, where the queue and the filter are split by a `:`.
  - The queue name is normally set as a reference to the sink cluster which is expected to consume from the queue.
  - The queue filter will be `any` to enable real-time replication;
    - The queue filter may be set to `block_rtrq` if the queue is not to support real-time replication, but is only to be used for either reconciliation or seeding.
    - The queue filter may be set to `buckettype.<name_of_type>` to only replicate buckets in a certain bucket type.
    - The queue filter may be set to `bucketname.<name_of_bucket>` or `bucketprefix.<prefix_for_bucket>` to only replicate buckets with a given name or a name with a given prefix.
      - Bucket name filters will work for typed and legacy buckets, with typed buckets the type will be ignored when using a name or prefix filter.

For replication, the real-time replication source must be enabled on every node in the cluster, as a PUT may be coordinated from any vnode (on any node), regardless of which node received the PUT request.

{: .note }
> By convention, the name of the queues are normally aligned with the names of the cluster that is to consume from the queue i.e. `<sink_cluster_name>`.  However, the name can be anything descriptive for the context in which the queue is to be used.

### Enable a Real-Time Sink

There are five configuration items required to set up a sink for real-time replication: enablement, queue definition, peers, workers and peer discovery.  All elements are set via `riak.conf`:

- `replrtq_enablesink = enabled`.
- `replrtq_sinkqueue = <sink_cluster_name>`;
  - The name of the queue, on any source node or cluster from which this sink may need to consume replication events.
  - The name of the queue does not need to be the cluster name, it can be any description that is helpful in context.
- `replrtq_sinkpeers = <ip_addr>:<port>:<protocol>|<ip_addr>:<port>:<protocol>` ...
  - A pipe delimited list of peers by IP, port and protocol (`pb` or `http`).
    - For efficiency, it is recommended to use the PB protocol.
    - If TLS enablement of the replication communication is required, then PB protocol must be used.
  - The peer node must have a listener enabled for that protocol on that port.
  - If `replrtq_peer_discovery` is enabled, then the list of peers will be used to discover other peer nodes on the clusters, and the discovered list will be the peers used by the sink.
  - The list may include nodes in different clusters.
  - For resilience, always connect sink nodes to a diverse set of source peers, even when peer discovery is enabled.
- `replrtq_sinkworkers = <worker_count>`
  - The count of sink workers which will be used on this node to fetch replicated objects from the source.
  - May be limited to control the impact of a sink cluster on the source cluster, in particular when fetching a backlog from the queue.
- <span>Available from Riak 3.0.10</span>{: .label .label-green }`replrtq_peer_discovery = enabled`
  - Enables a peer discovery process, which will use the configured peer to discover other peers in the cluster.
  - The cluster listeners on that protocol must be listening on reachable IP addresses and ports for peer discovery to work (i.e. binding a listener to `0.0.0.0` will not work).
  - If the application requires the standard Riak listener to be bound to an unreachable IP address, then the alternative protocol should be used for replication, with the alternative listener configured on a reachable address.

A backoff algorithm is used on the sink to reduce the frequency of requests to nodes returning error responses, and increase the frequency to nodes continuously having ready replication events on the queue.  This means that sink workers will automatically favour fetching from nodes with backlogs of replication activity.

### Security Configuration

The real-time connections may be secured, by [enabling security on the source cluster](./OperationsAndTroubleshootingGuide.md#enabling-riak-security).  The securing of communications for replication is supported only with the PB transport in Riak 3.4.

When communication is secured, then a security-source needs to be defined on the replication-source cluster.  For Riak 3.4, this has been tested only with a `certificate` requirement for authentication.  Authentication by certificate requires the following configuration on the sink nodes:

- `repl_cacert_filename`;
  - A filepath to a PEM file for the CA which has signed the source certificate, required by the sink node to validate the peer relationship.
- `repl_cert_filename`;
  - A filepath to a PEM file for a certificate to be used by this sink node.
  - This does not need to be unique within the cluster.
- `repl_key_filename`;
  - A filepath to a PEM file that has a private key associated with the certificate (i.e. `repl_cert_filename`) to be used.
- `repl_username`;
  - A valid username enabled on the source cluster.
  - The username should match the certificate name when `certificate` is defined as the security type in security-source setup on the (replication) source cluster.

The replication functions do not have associated `grant` actions within the security configuration.  However, it is possible to block replication connections from issuing other functions (e.g. access to the Query or Object API), by blocking the `grants` for those actions.

### Additional Configuration

Further configuration can be added for replication using `riak.conf`:

- `replrtq_compressonwire`;
  - To enable compression of replicated objects, with compression using the zlib compression library.
  - Compression should only be enabled if objects are known to be compressible, as zlib may be computationally expensive when only limited compression can be achieved.
- `replrtq_vnodecheck`;
  - The `r` value on the fetch of a replication object from the source (if it has not been queued), and the `w` value on the `PUSH` of the object into the sink.
  - The default is `one`, to ensure a minimal delay in real-time replication, but it is recommended to use the safer option of `quorum` instead.
  - Setting to a value other than `one` will reduce the risk of mailbox overloads related to replication backlogs.
  - A third option of `all` may be used;
    - This will ensure that workers move at the pace of the slowest vnode.
    - This is only to be used if there are repeated issues with replication-related load prompting vnode mailbox overload scenarios, where it is not possible to resolve those issues through reducing worker counts.
- `replrtq_prompt_max_seconds`;
  - The peer discovery is refreshed periodically based on this timer.
  - if a node is joined, downed or left; the change in peer availability will be detected at the next prompt.
- <span>Available from Riak 3.0.18</span>{: .label .label-green }`repl_reap`
  - Whether reap requests should be replicated like other changes.
  - The default is `disabled` for backwards compatibility, but this will require reap jobs to be coordinated across clusters.
  - When using a `delete_mode` of `keep`, then the default should be changed and `repl_reap` should be `enabled`.

{: .note }
> Note that for the options `replrtq_vnodecheck` and `repl_reap` non-default settings are recommended

## Configuration of All-Cluster Reconciliation

It is commonly most efficient to reconcile all data, rather than partial data.  If all data is not required, then [per-bucket reconciliation](#configuration-of-per-bucket-reconciliation) can be enabled.  All-cluster reconciliation is much more common than per-bucket reconciliation in production systems, as it commonly has lower overheads.

### Enable Tictac AAE

To use the inter-cluster reconciliation then Tictac AAE must be enabled in `riak.conf` - `tictacaae_active = active`.  Enabling `tictacaae_active` will place extra load on the cluster at write time, if the `leveled` backend is not used as a sole backend.  In this case there will be a need for a parallel key store (as opposed to a native leveled store), which will require keys and metadata to be written to a dedicated AAE store.

{: .note }
> The configuration option `tictacaae_storeheads` is not required to run all-cluster reconciliation, but is recommended to get the full operational feature set of AAE folds.

When enabling Tictac AAE for the first time, it will not be usable by reconciliation until all trees have been built.  Trees will periodically rebuild, and full-sync reconciliation checks should continue to operate as expected during rebuilds.

### Initial Configuration

Full-sync replication requires the existence of source queue definitions and sink worker configurations, in order for discovered deltas to be repaired.  The same configurations can be used as for real-time replication.  If there is a need to support reconciliation without allowing for real-time replication - then the `block_rtq` keyword can be used instead of `any` on the source queue definition.

{: .note }
> In configuration, reconciliation processes are commonly referred to by the initialism `ttaaefs` - TicTac AAE Full-Sync.

To enable reconciliation an initial configuration is required:

- `ttaaefs_scope = all`.
- `ttaaefs_queuename = <queue_name>`;
  - This is the queue name to be used by the remote cluster when fetching replication events.
  - When this node discovers a delta between the clusters, and the local cluster has the more up-to-date reference, the replication event will be added to the node's own replication queue under this queue name.
- `ttaaefs_queuename_peer = <queue_name>`;
  - This is the queue name to be used by the local cluster when fetching replication events from the remote cluster.
  - Adding a queue name makes full-sync reconciliation bidirectional.  If this node discovers the remote cluster has a more advanced version, it will send a request to the peer node to queue a replication event for the delta object on the configured queue.
  - If bidirectional reconciliation is not required, then the queue name should be set to `disabled`.
- `ttaaefs_localnval = <n_val>`;
  - The `n_val` to be used on this cluster when comparing to the opposing cluster.
  - The `n_val` may be different to the remote cluster, but it is preferred to avoid variance in `n_val` within a cluster.
- `ttaaefs_remotenval = <n_val>`;
  - The `n_val` to be used on the remote cluster.
- `ttaaefs_cluster_slice = 1`;
  - A number between 1 and 4.  All nodes on the same cluster should be given the same slice number.
  - Each time period has 4 slots, and clusters will schedule the activity in the slice associated with this number.
  - When configuring bidirectional replication between clusters, use 1 and 3, or 2 and 4 - as slice numbers for each cluster.
  - When multiple nodes are configured for reconciliation, time ranges are also sliced so that each node has its own time slice to run its reconciliation work.
    - Overlapping of reconciliation work is not managed through orchestration, but through allocation of slots based on node number (relative place in the list of nodes) and cluster slice.

Each node has a single manager for reconciliation - the `riak_kv_ttaaefs_manager`.  A manager can only have one configuration, it can manage reconciliation with one cluster for one `n_val` (and for one type, either all-cluster or per-bucket).  If the cluster needs to reconcile with other clusters, or with different settings, then other nodes should handle the alternate configurations.

{: .note }
> Reconciliation work is based on comparisons between clusters using AAE folds; so a single peer relationship between just two nodes is sufficient to reconcile the whole cluster.  However, for resilience and capacity reasons, ideally all nodes should be configured with different peer relationships.

To set up a peer relationship to another cluster, the following configuration is required:

- `ttaaefs_peerip = <ip_addr>`;
- `ttaaefs_peerport = <port>`;
- `ttaaefs_peerprotocol = pb|http`;
- For security the [settings for real-time replication](#configuration-of-real-time-replication) are used e.g. `repl_cacert_filename` etc.

### Enabling Checks

Reconciliation requires the scheduling of checks.  Each check will perform a full-cluster AAE exchange to compare between the clusters, which has three phases:

- `root_compare`;
- `branch_compare`;
- `clock_compare`.

The root to be compared is the root of [the merkle tree](./RiakTheoryGuide.md#anti-entropy) representing the state of the whole tree in 1,024 4-byte hashes.  The roots are merged across all partitions, to provide a representation of cluster state in a single 4KB integer.

If these roots match between the clusters, the clusters are considered to be reconciled - `in_sync = true` is the result of the exchange, and `{root_compare, 0}` is the final state of the exchange.  If not, the `root_compare` is repeated, and on the repeated check only deltas in the same 4-byte hash as the previous compare need to be considered a potential mismatch.  The `root_compare` will be repeated until the intersection of deltas is empty (all 1,024 hashes, have a some stage in the loop, matched between roots), or there exists a stable set of branches in the root, which differ on every comparison.  An empty set of deltas will be considered an `in_sync = true` result, otherwise the next phase is required.

The second phase is `branch_compare`.  Each branch is made up of 1,024 4-byte hash "leaves".  A subset of branches that have a consistent mismatch from the `root_compare` are chosen, and those branches are compared.  The same loop process used in the `root_compare` will be used to `branch_compare`, and discover either a stable delta - or potentially find that any delta is simply transient.

If all deltas are shown to be transient; then `in_sync = true` is the result of the exchange, and `{branch_compare, 0}` is the final state of the exchange.  Otherwise, a subset of tree leaves, also referred to as segment IDs, are chosen for the `clock_compare` stage.

In the final `clock_compare` stage, the keys and version vectors (clocks) are compared between the clusters.  The comparison behaviour will differ depending on the type of check that was requested.

All the keys that hash to those segment IDs need to be compared to be certain to find the delta, and this requires a full-scan of the keystore - and such a scan is a `ttaaefs_allcheck`.  This scan is accelerated by skipping over blocks of keys on disk that do not have any keys with a matching segment ID (using a hash-based filter cached with the block inside the leveled keystore).  Even with acceleration, the scan has a non-trivial cost in large stores.

If it can be determined from the results of previous checks, that all deltas are likely to be within a given time range (by object last_modified_date), or in a specific bucket; then this information can be used to narrow the scope of the scan in `clock_compare`.  A comparison reduced in scope this way is a `ttaaefs_rangecheck`, and can be substantially quicker than a `ttaaefs_allcheck`.

<span>Available from Riak 3.0.15</span>{: .label .label-green }The preferred check approach is to use `ttaaefs_autocheck`.  This is a check that uses context to select an appropriate `ttaaefs_rangecheck` when possible, and only fallback to `ttaaefs_allcheck` if necessary.  For example, if a cluster falls out of sync, it will assume first that the delta is a modified date range since the last successful check.

{: .highlight }
> The ability to set a schedule of specific checks (e.g. `ttaaefs_allcheck`, `ttaaefs_hourcheck` etc) has been maintained, but from Riak 3.0.15 it is recommended that the schedule of checks should only be configured to use `ttaaefs_autocheck`.

The schedule of reconciliation jobs is configured for each peer by setting:

- `ttaaefs_autocheck = <checks_per_day>`;
  - Sets the number of checks each day for this peer relationship, noting that each peer relationship will schedule checks independently (i.e. setting to 24 checks in an 8 node cluster with 8 peer relationships to another 8 node cluster using bidirectional reconciliation - will amount to a check every 3 minutes and 45 seconds, or 24 x 8 x 2 checks per day).
- `ttaaefs_allcheck.policy = always`.
  - Should be set to `always` unless a specific issue occurs which requires a window to be set.
- All other checks should normally set to 0;
  - `ttaaefs_allcheck`, `ttaaefs_hourcheck`, `ttaaefs_daycheck` - these are checks where the time range is hard-coded.  The `ttaaefs_nocheck` and `ttaaefs_rangecheck` are legacy settings that solved problems that existed prior to the introduction of `ttaaefs_autocheck`.

### Tuning checks - the maximum results limit

With o(10bn) keys in a cluster, there are 10K keys and clocks to be compared for every segment ID with a delta.  To reduce the cost of fetching and comparing keys in the `clock_compare` stage, the number of segments to be compared each loop is constrained by a maximum results limit.  This maximum results list is used at all phases of the exchange to reduce the scope of comparisons.  The maximum results limit is calculated from:

- `ttaaefs_maxresults = <max_results>`;
  - The number of segments to be compared each loop.
- `ttaaefs_rangeboost = <multiplier>`;
  - A multiplier applied to the `ttaaefs_maxresults` when a `ttaaefs_rangecheck` is used.
  - The product of `ttaaefs_maxresults` and `ttaaefs_rangeboost` should not exceed 1024.  Larger values will work, but not necessarily be efficient.

It is important that when a delta is being resolved, the comparison queries can complete in the time slot for the check.  If they do not complete, checks will begin to overlap and queue, and this will lead to checks being dropped and also the waste of compute resources; a timed out exchange will not be able to prompt repairs even though the fold operations may have continued through to completion.

The speed of checks are recorded in logs, and can be tested manually with different numbers of segment IDs using the [AAE fold `fetch_clocks_nval`](./OtherAPI.md#fetch_clocks_nval).  The speed of folds using segment IDs are improved if the segment IDs are in a smaller range (i.e. are numerically close together), and the AAE exchange will attempt to exploit this efficiency when selecting a subset of segment IDs.

## Configuration of Per-Bucket Reconciliation

The `ttaaefs_scope` can be set to a specific bucket, rather than `all`.

The non-functional characteristics of the solution change when using per-bucket full-sync.  There is no per-bucket caching of AAE trees, so the AAE trees will need to be re-calculated by scanning the whole bucket for every full-sync check (subject to other restrictions on check type).  So the cost of checking full-sync for an individual bucket in non-failure scenarios is considerably higher than using a scope of `all`.

When deltas are discovered in trees, the scanning required to compare keys and clocks will be limited to the bucket, and so this may be faster.

The rules of the `ttaaefs_<sync_type>check` configuration are followed with per-bucket synchronisation.  So using `ttaaefs_autocheck` when a previous check succeeded will scan only recently modified items to build the tree for comparison.  This does mean that non-recently modified variations within the bucket (such as resurrected objects or tombstones) will not be detected by `ttaaefs_autocheck` as when `ttaaefs_scope = all`.  When using per-bucket full-sync, it may be wise to occasionally schedule a `ttaaefs_allcheck` to cover this scenario.

{: .note }
> A scheduled run of `ttaaefs_allcheck` will occur regardless of whether the current time is within or outside of the `allcheck.window`.  The window is related only to the running of `ttaaefs_autocheck`, to prevent a `ttaaefs_autocheck` from being escalated to a `ttaaefs_allcheck` within the window.

When using per-bucket full-sync, and performing a rolling upgrade to Riak 3.2.3 or 3.4.0 (from earlier releases than Riak 3.2.3), there may be errors merging trees.  To prevent these errors during the rolling upgrade, then either disable full-sync for the period of the upgrade, or use the configuration option to force the new nodes to use legacy format trees:

- `legacyformat_tictacaae_tree = enabled`

There are significant memory improvements related to the Riak 3.2.3 tree format, so the configuration should be reversed after the rolling upgrade has completed.  There are no inter-cluster issues with tree versions, it is only an issue when merging trees within a cluster to provide a cluster-wide view of a tree.

## Migrating a cluster

Most operational processes in Riak are supported through simple configuration changes, in-place upgrades or a rolling replacement.  There may be some exceptional changes which require a full cluster migration e.g.: changing the default `n_val`, or resizing the ring.  In a cloud-like environment, where there are no capital costs of temporary infrastructure; this is a relatively simple and low-risk process with replication.

The following stages are required:

- [Initiate a new cluster](./BuildAndScaleClusterGuide.md) with the correct configuration (e.g. alternative ring-size).
- Configure a [new real-time source queue](#enable-a-real-time-source) on the current cluster for the replacement cluster.
- Enable [sink workers on the new cluster](#enable-a-real-time-sink) to begin to consume real-time changes.
- Use the [AAE folds](./OtherAPI.md#aae-fold-api) `list_buckets` and `repl_range_keys` to queue up data to seed the new cluster;
  - Ensure that the old cluster is configured with a sufficiently high `replrtq_overflow_limit` per-node, to have a large enough on-disk queue to avoid discarding replication events;
  - [Tune the sink workers](#making-runtime-changes-to-the-sink) on the replacement cluster to avoid overloading the new cluster.
- Enable [reconciliation](#configuration-of-all-cluster-reconciliation) on the replacement cluster.

Once the two clusters are in an `in_sync = true` state the migration is complete, and application traffic may be switched to the new cluster, and the old cluster can be decommissioned.  It is common for production systems with o(10TB) of data to manage this process in 24 to 72 hours.

{: .note }
> If possible, migrating a cluster should be a rehearsed process, just like any other [repair or replace operational change](./OperationsAndTroubleshootingGuide.md#replace-repair-and-recover).

## Replication API

All real-time and full-sync operations are available via the Riak API, and supported by the Riak erlang clients (both PB and HTTP).  They have been used in different systems for replicating and synchronising with third party databases, such as OpenSearch or DynamoDB.

It is recommended to use the PB API for both performance and security reasons (as TLS can be enabled via this API for replication).  The HTTP API is slower, but may be useful where it is easier to set up peer relationships with a HTTP-based load-balancer rather than an individual node.

The replication API consists of [the AAE fold API](./OtherAPI.md#aae-fold-api) and the [fetch API required to access replication queues](./OtherAPI.md#the-fetch-api).

## Monitoring and Runtime Changes

### Monitoring real-time replication via logs

The size of replication queue is logged as follows:

`@riak_kv_replrtq_src:handle_info:414 QueueName=replq has queue sizes p1=0 p2=0 p3=0`

There is a log on each sink node of the replication timings:

`Queue=~w success_count=~w error_count=~w mean_fetchtime_ms=~s mean_pushtime_ms=~s mean_repltime_ms=~s lmdin_s=~w lmdin_m=~w lmdin_h=~w lmdin_d=~w lmd_over=~w`

The `mean_repltime` is a measure of the delta between the last-modified-date on the replicated object and the time the replication was completed - so this may vary if prompting replication due to real-time changes, reconciliation or seeding.  The `lmdin_<x>` counts are the counts of replicated objects which were replicated within a second, minute, hour, day or over a day.

### Making runtime changes to the Source

There are four functions on the source that may be [called from the `remote_console`](./OperationsAndTroubleshootingGuide.md#remote-console).  To suspend and resume a queue:

```erlang
riak_kv_replrtq_src:suspend_rtq(QueueName).
```

```erlang
riak_kv_replrtq_src:resume_rtq(QueueName).
```

To check the length of the queue, and if necessary clear the queue (for example if a mistaken `repl_keys_range` fold has been prompted):

```erlang
riak_kv_replrtq_src:length_rtq(QueueName).
```

```erlang
riak_kv_replrtq_src:clear_rtq(QueueName).
```

> Clearing a queue will clear all entries from the queue, regardless of priority.

### Making runtime changes to the Sink

More workers and sink peers can be added at [runtime via the `remote_console`](./OperationsAndTroubleshootingGuide.md#remote-console), by resetting the worker counts.  This reset is a cluster-wide change, not just a change on the local node:

```erlang
riak_client:replrtq_reset_all_workercounts(WorkerCount, PerPeerLimit)
```

To force peer discovery to immediately update the list of peers on a sink node (this is a node-specific not cluster-wide change):

```erlang
riak_client:replrtq_reset_all_peers(QueueName)
```

When introducing a new node to a sink cluster, if the new node is configured as a sink node it will begin to consume changes from the source as soon as the node has started - which may be prior to joining the cluster.  This will cause a temporary loss of in-sync state for inter-cluster reconciliation.  It is possible to suspend and resume a node from acting as a sink using:

```erlang
riak_kv_replrtq_snk:suspend_snkqueue(QueueName)
```

```erlang
riak_kv_replrtq_snk:resume_snkqueue(QueueName)
```

{: .note }
> Riak will always be eventually consistent, any changes consumed by a sink node prior to joining will be transferred as part of the join; otherwise the reconciliation process will repair any deltas.

### Monitoring reconciliation exchanges via logs

When a cluster relationship has been seeded, and real-time replication has been enabled - reconciliation will generally be fast, and consistently return a result of `in_sync = true`.

Should a delta occur, there will be logs not just of the sync status, but with information about the deltas discovered. Following a `clock_compare`, a log will be generated for each bucket where repairs were required, with the low and high modification dates associated with the repairs:

{% raw %}
```console
riak_kv_ttaaefs_manager:report_repairs:1071 AAE exchange=122471781 work_item=all_check type=full repaired key_count=18 for bucket=<<"domainDocument_T9P3">> with low date {{2020,11,30},{21,17,40}} high date {{2020,11,30},{21,19,42}}
riak_kv_ttaaefs_manager:report_repairs:1071 AAE exchange=122471781 work_item=all_check type=full repaired key_count=2 for bucket=<<"domainDocument_T9P9">> with low date {{2020,11,30},{22,11,39}} high date {{2020,11,30},{22,15,11}}
```
{% endraw %}

If there is a need to investigate further what keys are the cause of the mismatch, all repairing keys can be logged by setting via `remote_console`:

```erlang
application:set_env(riak_kv, ttaaefs_logrepairs, true).
```

This will produce logs for each individual key:

{% raw %}
```console
@riak_kv_ttaaefs_manager:generate_repairfun:973 Repair B=<<"domainDocument_T9P3">> K=<<"000154901001742561">> SrcVC=[{<<170,167,80,233,12,35,181,35,0,49,73,147>>,{1,63773035994}},{<<170,167,80,233,12,35,181,35,0,97,246,69>>,{1,63773990260}}] SnkVC=[{<<170,167,80,233,12,35,181,35,0,49,73,147>>,{1,63773035994}}]

@riak_kv_ttaaefs_manager:generate_repairfun:973 Repair B=<<"domainDocument_T9P3">> K=<<"000154850002055021">> SrcVC=[{<<170,167,80,233,12,35,181,35,0,49,67,85>>,{1,63773035957}},{<<170,167,80,233,12,35,181,35,0,97,246,68>>,{1,63773990260}}] SnkVC=[{<<170,167,80,233,12,35,181,35,0,49,67,85>>,{1,63773035957}}]
 
@riak_kv_ttaaefs_manager:generate_repairfun:973 Repair B=<<"domainDocument_T9P3">> K=<<"000154817001656137">> SrcVC=[{<<170,167,80,233,12,35,181,35,0,49,71,90>>,{1,63773035982}},{<<170,167,80,233,12,35,181,35,0,97,246,112>>,{1,63773990382}}] SnkVC=[{<<170,167,80,233,12,35,181,35,0,49,71,90>>,{1,63773035982}}]
 
@riak_kv_ttaaefs_manager:generate_repairfun:973 Repair B=<<"domainDocument_T9P3">> K=<<"000154801000955371">> SrcVC=[{<<170,167,80,233,12,35,181,35,0,49,70,176>>,{1,63773035978}},{<<170,167,80,233,12,35,181,35,0,97,246,70>>,{1,63773990260}}] SnkVC=[{<<170,167,80,233,12,35,181,35,0,49,70,176>>,{1,63773035978}}]
```
{% endraw %}

At the end of each stage of a an exchange a log EX003 is produced which explains the outcome of the exchange:

```console
log_level=info log_ref=EX003 pid=<0.30710.6> Normal exit for full exchange purpose=day_check in_sync=true  pending_state=root_compare for exchange id=8c11ffa2-13a6-4aca-9c94-0a81c38b4b7a scope of mismatched_segments=0 root_compare_loops=2  branch_compare_loops=0  keys_passed_for_repair=0

log_level=info log_ref=EX003 pid=<0.13013.1264> Normal exit for full exchange purpose=range_check in_sync=false  pending_state=clock_compare for exchange id=921764ea-01ba-4bef-bf5d-5712f4d81ae4 scope of mismatched_segments=1 root_compare_loops=3  branch_compare_loops=2  keys_passed_for_repair=15
```

The mismatched_segments is an estimate of the scope of damage to the tree.  Even if `clock_compare` shows no deltas, clusters are not considered `in_sync` until deltas are not shown with tree comparisons (e.g. `root_compare` or `branch_compare` return 0).

### Statistics available via Riak stats

The [Riak status statistics](./OperationsAndTroubleshootingGuide.md#riak-stats) set includes stats relevant to monitoring replication:

The following counters track activity on real-time replication sources:

- `ngrfetch_nofetch`;
  - the count of sink requests resulting in nofetch.
- `ngrfetch_prefetch`;
  - the count of sink requests resulting in a queued object.
- `ngrfetch_tofetch`;
  - the count of sink requests resulting in a queued reference, where a fetch of the object was required.
- `ngrrepl_srcdiscard`;
  - the count of objects that were not queued as the queue had exceeded the configured overflow limit.

The following counters track activity on real-time replication sinks:

- `ngrrepl_object`;
  - the count of sink fetch requests that returned an object.
- `ngrrepl_empty`;
  - the count of sink fetch requests where the fetch returned no object as the queue was empty.
- `ngrrepl_error`;
  - the count of sink fetch requests that returned an error.

for full-sync reconciliation, the following statistics can be used to track activity:

- `ttaaefs_src_ahead_total`;
  - the total number of objects discovered in clock comparison where the remote source cluster had the more advanced version.
- `ttaaefs_snk_ahead_total`;
  - the total number of objects discovered in clock comparison where the local sink cluster had the more advanced version.
- `ttaaefs_nosync_total`/`ttaaefs_nosync_time_100`;
  - the number of full-sync reconciliation jobs on this node that have resulted in the clusters being found to be out-of-sync, and the maximum time seen for such a job.
- `ttaaefs_sync_total`/`ttaaefs_sync_time_100`;
  - the number of full-sync reconciliation jobs on this node that have resulted in the clusters being found to be in-sync, and the maximum time seen for such a job.
- `ttaaefs_fail_total`/`ttaaefs_fail_time_100`;
  - the number of full-sync reconciliation jobs that resulted in an error, normally a timeout, and the maximum time seen for such a job.
- `ttaaefs_rangecheck_total`/`ttaaefs_allcheck_total`;
  - the number of reconciliation jobs which were range checks and all checks.

### Prompting a reconciliation check

Individual full-syncs between clusters can be triggered outside the standard schedule:

```erlang
riak_client:ttaaefs_fullsync(all_check).
```

The `all_check` can be replaced with `hour_check`, `day_check` or `range_check` as required.  The request will use the standard max_results and range_boost for the node.

### Configure and monitor work queues

The node worker pool configuration is [detailed further in the AAE fold API documentation](./OtherAPI.md#node-worker-pools).

There are two per-node worker pool sizes which have particular relevance to full-sync: `af1_worker_pool_size = <size>`; `af3_worker_pool_size = <size>`.

The AF1 pool is used for rebuilds of the AAE tree cache, and the AF3 pool is used for key/clock fetches when using cluster-wide reconciliation.

If the full-sync processes are taking too long (perhaps as max_results or range_boost are set too aggressively) then the worker pools may backup.  At some stage there may develop a situation where all full-sync queries will time out as the queries will take too long to reach the front of the queue, and hence all the effort associated with the queries will be wasted.

By default there is a log prompted for every aae_fold on completion (all full-sync activity depends on aae_folds prompted on both the source and sink).  For more information on monitoring node worker pools [refer to the Operations guide](./OperationsAndTroubleshootingGuide.md#monitoring-node-worker-pools).

### Update the request limits

If there is sufficient capacity to resolve a delta between clusters, but the current schedule is taking too long to resolve - the max_results and range_boost settings on a given node can be overridden.

```erlang
application:set_env(riak_kv, ttaaefs_maxresults, 64).
application:set_env(riak_kv, ttaaefs_rangeboost, 16).
```

Individual repair queries will do more work as these numbers are increased, but will repair more keys per cycle.  This can be used along with prompted checks (especially range checks) to rapidly resolve a delta.

{: .note }
> If the number of segment IDs being checked goes significantly over one thousand, then the number of blocks that can be skipped will tend towards zero.  So the combined value of `maxresults * rangeboost` should be kept to a value less than or equal to 1024.

### Overriding the range

When a query successfully repairs a significant number of keys, it will set the range property to guide any future range queries on that node.  This range can be temporarily overridden, if for example, there exists more specific knowledge of what the range should be.  It may also be necessary to override the range when an event erroneously wipes the range (e.g. falling behind in the schedule will remove the range to force range_checks to throttle back their activity).

To override the range (for the duration of one request):

```erlang
riak_kv_ttaaefs_manager:set_range({Bucket, KeyRange, ModifiedRange}).
```

Bucket can be a specific bucket (e.g. `{<<"Type">>, <<"Bucket">>}` or `<<"Bucket">>`) or the keyword `all` to check all buckets (if n_val full-sync is configured for this node). The KeyRange may also be `all` or a tuple of StartKey and EndKey.

To remove the range:

```erlang
riak_kv_ttaaefs_manager:clear_range().
```

Remember the `range_check` queries will only run if either: the last check on the node found the clusters in sync, or; a range has been defined.  Clearing the range may prevent future range_check queries from running until another check re-assigns a range.

### Re-replicating keys for a given time period

The aae_fold `repl_keys_range` will replicate any key within the defined range to the clusters consuming from a defined queue.  See the [AAE fold API documentation](./OtherAPI.md#aae-fold-api) for more information on using `repl_key_range`.

### Re-Sync a Bucket

Full-sync reconciliation is designed to be fast and efficient for confirming that clusters are in sync, but is relatively slow to resolve deltas between clusters.  The common case, when the delta is associated with a recent window of last-modified-dates (e.g. due to a recent temporary failure of replication or nodes) is optimised through the `auto_check` process; and also [re-replication](#re-replicating-keys-for-a-given-time-period) may be used to accelerate this.  However, if the delta is not restricted to a given time range of modified dates, and the delta is large, there is a need for alternative intervention to close the delta in a timely manner.

For small buckets (in terms of object count), simply re-replicating the bucket could be the easiest solution, especially where it is clear the replication failure is uni-directional.  For larger buckets, and for handling bi-directional deltas, then it is possible to manually intervene to re-sync a bucket.

The re-sync can be triggered from any node, from either cluster - assuming that bi-directional replication is configured.  The re-sync is cluster-wide, it is not a re-sync of data local to the node. The re-sync can handle, as with other nextgenrepl features, clusters with different configurations (e.g. `n_val` settings).

A bucket re-sync will suspend the local full-sync process on the node from which it is triggered, and roll through segment slices of the bucket performing bucket-specific `range_check` operations.  As each loop covers only a single slice of the segment space, this is much quicker to repair than the standard full-sync per-bucket check, which needs to read the whole bucket space to build AAE trees for comparison.

The re-sync bucket can be called via [remote_console](./OperationsAndTroubleshootingGuide.md#remote-console):

```console
riak_client:resync_bucket({<<"BucketType">>, <<"BucketName">>}).
```

Or, for untyped buckets:

```console
riak_client:resync_bucket(<<"BucketName">>).
```

{ .highlight }
> In small buckets, of o(10m) keys, it would be normal to have a bucket resync operation repair deltas at a rate exceeding 1,000 per second.  

As well as the helper function in `riak_client`, there is a configurable `riak_kv_ttaaefs_manager:resync_bucket/6` function exported.  For much larger buckets, this configurable version can be used to optimise the process e.g. use a smaller width (the size of the slice of the segment space), fix a specific key range or within a modified date range.

{ .note }
> It is possible to have multiple nodes running resync_bucket concurrently - to sync different buckets, or different key ranges within a bucket.  The limiting factor to horizontal scaling of resync_bucket is usually the size of [AF3 worker pool](./OtherAPI.md#node-worker-pools).  Once all workers in the pool are continuously busy, no further scaling can be achieved, without running larger pools (on all clusters).

#### Participate in Coverage

The full-sync comparisons between clusters are based on coverage plans - a plan which returns a set of vnode to give r=1 coverage of the whole cluster.  When a node is known not to be in a good state (perhaps following a crash), it can be rejoined to the cluster, but made ineligible for coverage plans by using the `participate_in_coverage` configuration option.

This can be useful when tree caches have not been rebuilt after a crash. The `participate_in_coverage` option can also be controlled without a restart via the `riak remote_console`:

```erlang
riak_client:remove_node_from_coverage()
```

```erlang
riak_client:reset_node_for_coverage()
```

The `remove_node_from_coverage` function will drop the local node out of any coverage plans being generated within the cluster (the equivalent of setting participate_in_coverage to false).  The `reset_node_for_coverage` will return the node to its configured setting (in the riak.conf file loaded at start up).

#### Suspend full-sync

If there are issues with full-sync and its resource consumption, it maybe suspended:

```erlang
riak_kv_ttaaefs_manager:pause()
```

when full-sync is ready to be resumed on a node:

```erlang
riak_kv_ttaaefs_manager:resume()
```

These run-time changes are relevant to the local node only and its peer relationships.  The node may still participate in full-sync operations prompted by a remote cluster even when full-sync is paused locally.

When using auto-checks it is also possible to suppress a fixed number of checks.  By default if there are timeouts on queries, the full-sync manager will assume there is excess pressure in the system and enable auto_check_suppress automatically.  This will disable the next two auto-checks.

This can be triggered manually from remote_console `riak_kv_ttaaefs_manager:autocheck_suppress()`.

To change the count of checks for which the suppression is enabled, either alter then environment variable `application:set_env(riak_kv, ttaaefs_autocheck_suppress_count, 4)` or when manually using suppression the count can be specified i.e. `riak_kv_ttaaefs_manager:autocheck_suppress(4)`.

#### Trigger Tree Repairs

When an `all_check` is prompted due to a `{clock_compare, 0}` result, there are two scenarios:

- the cached trees differ but the differences lie outside the previous range;
- the cached trees differ due to a bad tree cache, and there are no actual differences.

For the second case, it is necessary to repair the trees, so when an `all_check` is triggered it will also prompt for trees to be repaired on this node (for the identified mismatched segments only) the next time there is a fetch for keys and clocks.  The triggering should have a log of:

`Setting node to repair trees as unsync'd all_check had no repairs - count of triggered repairs for this node is ~w`

The triggering of tree repairs increases the cost of the fetching of keys and clocks.  Each trigger is coordinated so that it is only fired once and once only (per trigger event) on each vnode.  Usually there is a single vnode with a bad tree cache, but it may take a full cycle of checks for the trigger to be enabled and enacted on the correct node.  This assumes that full-sync reconciliation is bidirectional and configured across all nodes, so eventually each node will see the bad state and trigger the repair mode.  If this isn't the case, manual intervention may be required.  

To force a node to enter into the tree repair state, then the following functions can be called via `remote_console`.

```erlang
riak_kv_ttaaefs_manager:trigger_tree_repairs() % Trigger tree repairs on this node
riak_kv_ttaaefs_manager:disable_tree_repairs() % Reverse
```

{: .highlight }
> The common root cause of bad tree caches, and hence the prompting of tree repairs, is resolved in Riak 3.2.5.  Workarounds to prompt repair remain in place, should other triggers exist.

## Legacy Replication - riak_repl

The previous replication solution in Riak, `riak_repl`, is still available to configure.  The `riak_repl` solution is stable, and has not been modified since Riak 2.2.3 (other than the conversion to be fully open-source in Riak 2.2.5).

The [legacy documentation](https://docs.riak.com/riak/kv/2.2.3/configuring/v3-multi-datacenter/index.html) can be used to set up `riak_repl`.  The v3 of riak_repl should always be used in preference to previous versions.

Some notes on `riak_repl` and the comparison to NextGen replication in Riak:

- `riak_repl` is not under active development, but remains functional.
- `riak-repl` has no support for replication and reconciliation between clusters with different ring sizes, so cannot be used to reliably transition between clusters of different ring sizes.
- `riak_repl` uses a PUSH model to replicate real-time changes.
- `riak_repl` will attempt to migrate queues between nodes when nodes go down.
  - Despite the additional resilience, anecdotal evidence indicates that real-time replication is generally less reliable than NextGen replication (i.e. it is more likely to drop replication events).
- `riak_repl` has an anti-entropy based method of full-sync reconciliation, using the legacy active anti-entropy service.
  - The AAE-based full-sync in `riak_repl` is faster at resolving deltas, but will fail to complete during tree rebuilds;
  - Users of full-sync have needed to use manually prompted rebuild windows to address this problem (i.e. a period where full-sync is suspended, and rebuilds are completed in parallel).
  - As clusters scale, the AAE rebuild windows will be an ongoing management overhead, and clusters may scale to the point that rebuilds cannot complete in the available window.
- `riak_repl` has a keylisting form of full-sync which will do a full key and clock comparison on a vnode-by-vnode basis.
  - A keylisting full-sync can be resource intensive and will take a significant amount of time to complete on clusters of non-trivial scale.

The use of `riak_repl` is deprecated, and when a retirement schedule is agreed it will be advertised via [OpenRiak discussions](https://github.com/orgs/OpenRiak/discussions).

## Replication scope

Replication in Riak between clusters is limited in scope to objects only.  Cluster metadata, including bucket type configurations, bucket properties and authentication credentials are not replicated.  When enabling bucket types, the enablement must be triggered on each and every cluster that may receive an object for that bucket type.
