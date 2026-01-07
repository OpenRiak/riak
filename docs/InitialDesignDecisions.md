---
title: Initial Design Decisions
nav_order: 1
layout : default
---

# Riak KV - Initial Design Decisions

There are six initial design decisions that need to be considered at the outset of a Riak KV  project.  The priority design choices are:

- [Database backend](#database-backend)
- [Ring size](#ring-size)
- [Intra-cluster data resilience](#intra-cluster-data-resilience)
- [Interconnecting multiple clusters](#interconnecting-multiple-clusters)
- [Deleting data](#deleting-data)
- [Mapping data to objects](#mapping-data-to-objects)

It is not always possible to get all decisions correct first-time in the design phase.  Within this page, as well as supporting information for making the choice, there is also guidance and how to transition to an alternative configuration.

{: .highlight }
> Riak clusters commonly run for decades, dealing with significant functional and non-functional changes in applications during their lifespan.  Making good decisions up-front is helpful, but not critical.

## Database backend

### Database backend - making a choice

A Riak database cluster is a collection of smaller databases (known as vnodes).  Each vnode has a backend which is responsible for storing, and providing access to the data.  What backends are to Riak, are what storage engines are to MySQL.  The choice of backend is important to the performance of the solution, but also critical to the features which are available to use.

The following choices exist:

- **leveled** (recommended for Riak 3.4)
- **bitcask** (default)
- eleveldb (deprecated as of Riak 3.4)
- in-memory (deprecated as of Riak 3.4)
- **multi-backend** (supported only in limited use cases, specifically as a multi-bitcask backend)

{: .note }
> In most common deployment scenarios, the best choice when the full functionality of Riak is required, is to use the leveled backend.

The bitcask backend may be used, especially if

- there is no potential future need for querying of data using the Query API, and;
- objects are largely immutable, and especially if also;
- read-repair is sufficient to meet the application anti-entropy requirements,
  - noting that anti-entropy is still supported with bitcask, just with additional overheads.

Sometimes, even in those situations, the leveled backend may be more efficient at present. There are ongoing plans within the OpenRiak community to continue to invest in bitcask improvements, and there are pending changes which have been shown to improve Riak/bitcask performance by 30% to 50% in some use cases.

{: .note }
> The bitcask backend is the preferred long-term solution for immutable, unsorted, data storage in Riak.

Use of multi-backend should generally be avoided, unless as a multi-bitcask backend (e.g. for tiered storage).  It may also be used to manage multiple expiry schedules across multiple bitcask backends through the backend TTL support; but not if anti-entropy requirements exist beyond read-repair or if inter-cluster reconciliation is required.  In these cases managing expiry [through the use of the eraser process is preferred](#deleting-data).

#### Leveled

The leveled backend has the following characteristics and features:

- Pure erlang log-structured-merge (LSM) tree backend, designed and developed specifically for use within Riak.
  - Implementation in Erlang simplifies resource management as CPU scheduling of all Riak activity is under the control of the Erlang virtual machine.  
- Differs from most other LSM implementations in that values are set-aside in a sequence-ordered journal, and only keys and metadata are placed in the key-ordered LSM-based ledger.  This provides for lower cost and more efficient reads when only keys and metadata are required (internally within Riak this is usually the case, even when the external user requires the value).  It also reduces the overhead of write amplification, supporting larger object sizes with greater efficiency.
- Internal optimisations to increase efficiency within Riak for the Tictac-based method of anti-entropy and inter-cluster reconciliation.
- Supports index entries as well as objects in the key-ordered ledger, to allow full use of the Riak Query API.
- Is the priority backend used within the OpenRiak community for both functional and non-functional testing of new releases.
- Generally requires significantly less memory than the total size of all the keys.
  - A fixed overhead (per vnode) of about 10K keys and metadata is kept in memory, plus 1% of the keys, plus 2-bytes per key.
- Guarding against out-of-memory errors is an operator responsibility.  The cluster should be expanded if the memory limit is close, the per-vnode memory overhead will not be proactively reduced.
  - Makes use of any spare memory of the system through proactive hints to the file-system page cache.

For further details on the design and implementation of the leveled backend refer to [the Riak Theory Guide](./RiakTheoryGuide.md#the-leveled-backend).

#### Bitcask

The bitcask backend has the following characteristics and features:

- A simple low-code, journal based key-value store, originally designed and developed by the founding Riak team at Basho; that has been used as a general implementation model for other such stores.
  - Although there have been minimal changes to the original version as of Riak 3.4, bitcask remains under active development within the OpenRiak community, with plans for future enhancements.
- Written primarily in Erlang, but including around 3K lines of C code to provide the in-memory database of keys.  Access to C-code is generally for short-lived functions, which limits the impact on the scheduling requirements of the BEAM.  The C-code is also extremely stable, and is low-risk in terms of overheads associated with platform evolution.
- Support for pure objects only, no support for index entries and any part of the Riak Query API.
- Requires an out-of-hours merge window to be available and configured, for compaction of mutated objects.  Merging under database load may lead to highly unpredictable performance.
- Requires a separate key-store backend if anti-entropy or inter-cluster reconciliation features are required.
- All keys are kept in-memory, and so sufficient memory is required as the number of keys expands.
  - Guarding against out-of-memory errors is an operator responsibility.  The cluster should be expanded as the memory limit is reached, the per-vnode memory overhead will not be proactively reduced.
- No current support for optimised HEAD requests, which can have significant impact on overall efficiency within Riak.
  - Implementations of bitcask have been produced with this optimisation, and may be open-sourced in the future. 

For further details on the design and implementation of the bitcask backend refer to [the Riak Theory Guide](./RiakTheoryGuide.md#the-bitcask-backend).

#### Eleveldb (deprecated)

The eleveldb backend has the following characteristics and features:

- A heavily-adapted version of the google leveldb store - a LSM tree backend written in C++.  The adapted version is now deprecated, and the original version is subject to only limited maintenance activity.
  - has specific optimisations when compared with google leveldb to: reduce stalling; share and schedule resources where multiple instances operate on the same server; recover disk space following deletion; support automated object expiry.
- Supports secondary index entries, but will not support the full Riak Query API.
- Potentially faster and more efficient than leveled when values are small.
- Moves the majority of CPU and memory management away from the BEAM, to be managed directly within the C++ code.
  - This provides some additional capabilities, in particular the ability to fix the percentage of memory used across all eleveldb-backed vnodes on a node.
  - This has some long-term maintenance overheads, which the OpenRiak community are not expecting to continue to support after the release of Riak 4.0.

#### In-memory (deprecated)

The in-memory backend has the following characteristics and features:

- Not persisted, all data on an individual node will be lost on restart.
  - Note that Riak clusters are resilient to the loss of data on a single node, but constraining the ability to perform [rolling restarts](./OperationsAndTroubleshootingGuide.md#rolling-restart) of Riak due to data loss, may cause operational overheads.
- Based on the erlang ETS tables.
- Has crude and imperfect handling of out-of-memory issues to help limit the size of each individual vnode store.
- Supports secondary index entries, but will not support the full Riak Query API.

#### Multi-backend

The multi-backend has the following characteristics and features:

- Allows different data buckets to be mapped to different backends, so that different buckets can use the different capabilities of those backends.
- Generally only recommended for production use when running multiple bitcask backends (e.g. with different TTL, or storage paths).

Testing of Riak is focused on single-backend solutions, but multi-backend (bitcask) is a combination well-tested within large-scale production deployments.

### Database backend - changing the choice

The database backend configuration is local to a node.  Migrating the database backend will require a [rolling replacement](./OperationsAndTroubleshootingGuide.md#rolling-replacement) of one or more nodes at a time.  For example, a multi-backend configuration with bitcask and in-memory backends and parallel-mode Tictac AAE, can be upgraded to a single leveled backend with native Tictac AAE (assuming the TTL capability requirement is not being utilised).

{: .note }
> A rolling replacement is a safe and reliable process even when a cluster is under application load; although it would be normal in a large-scale production Riak cluster for a complete rolling replacement to take days and not hours.

Where different backends support different cluster-wide features (e.g. support of the [Riak Query API](./QueryAPI.md)), then the feature will only be usable when all nodes have updated.

## Ring size

### Ring size - making a choice

A Riak cluster distributes data across individual databases (known as vnodes), and those databases are then distributed across the physical nodes and locations of the cluster.  The distribution of data within Riak is referred to as [the ring](./RiakTheoryGuide.md#the-ring---the-distribution-of-vnodes). The number of vnodes in the databases is required to be a factor of 2, and bigger than the total number of nodes in the database cluster.  This number is known as the ring size.

Starting with a large ring size is helpful as:

- It provides greater potential for future scalability of the cluster, as for efficient use of hardware there should always be at least one vnode per CPU core within the cluster (and preferably multiple vnodes per CPU core).
- It provides for more even distribution of load, as if `RingSize div NodeCount = K` each node will have either `K` or `K + 1` vnodes - and the relative delta between the size of `K` and `K + 1` decreases as the RingSize increases (e.g. with a node count of 6, there is a 10% difference between the resource required for a busy vs quiet node with a Ring Size of 64, but just a 2.3% difference with a Ring Size of 256).
- Background database activity is split by vnode, so increasing the number of vnodes has a smoothing impact on that load making it more predictable.

Starting with a smaller ring size is helpful as:

- Index queries, where a small number of results (i.e. < 10K) are returned are more efficient with a smaller ring size.  If 1% of the overall database throughput is such queries, then a shift up in ring size can reduce efficiency by up to 10% - but with less load of such queries, the impact is less.
- There is a lower per-node memory footprint (with the leveled backend) if the vnode count per node is lower - although that footprint can be addressed through other means (e.g. reducing the `penciller_cache_size`).
- Background database activity is split by vnode, so decreasing the number of vnodes reduces the overall volume of such activity.

{: .note }
> A ring size of `512` is a reasonable starting configuration for production clusters; unless there is a short-term goal to scale to much more than 1 billion objects.

A ring-size of `16` is a reasonable starting configuration for a single-node non-production Riak system; unless there is a short-term goal to scale-up the use of a high number of CPU cores on the node.

### Ring size - changing the choice

Once a Ring Size is set, there is no way of updating a cluster in-place.  However the ring-size can be updated using the [cluster migration process](./ReplicationGuide.md#migrating-a-cluster).

{: .note }
> In environments where the capital cost of hardware is low (e.g. cloud environments), then using cluster migrations to evolve cluster configuration is relatively common.  A cluster migration process requires significant elapsed time, potentially taking multiple days - but is a safe and reliable process, even when a cluster is under application load.

## Intra-cluster data resilience

### Intra-cluster data resilience - making a choice

There are two primary aspects to data resilience within a cluster:

- [Configuring data distribution guarantees](#data-distribution-guarantees);
- [Enabling proactive reconciliation](#proactive-reconciliation).

Further guidance on the infrastructure requirements for a cluster, and the planning of cluster changes, can be found within the [guide to building and scaling a cluster](./BuildAndScaleClusterGuide.md).

#### Data distribution guarantees

A Riak cluster is a set of nodes (e.g. physical servers or virtual cloud instances), and the nodes within a cluster can be divided into separate locations (e.g. to represent physical racks, cloud placement groups, cloud availability zones or operator-defined maintenance groups).  Guarantees about the safety of data within a cluster can be set for both the nodes and the locations.

There are three configurable elements that control the resilience of the data distribution within a cluster:

- `n_val`; the replication value for the data items within the cluster, i.e how many copies of each object should exist within the cluster.  The `n_val` should preferably be set to the same value across all buckets.  The default `n_val` setting is 3, but in some circumstances this may be changed to 1 (e.g. backup clusters, or development environments) or 5 (e.g. for larger clusters looking to guarantee quorum reads in the presence of triple failures) - although in theory any positive integer value may be supported.
- `target_n_val`; the target for the distribution guarantee.  The `target_n_val` should always be consistently defined across nodes within a cluster.  The default setting is 4.  If the target is equal to the n_val, then all copies of the data stored within Riak in a healthy cluster will be guaranteed to be on separate nodes. If the target is greater than the n_val, then the integer difference represents how many failures can be tolerated before the guarantee is put at risk.
- `target_location_n_val`; the target for the distribution guarantee from the perspective of locations not nodes.  The `target_location_n_val` should always be consistently defined across nodes. This is normally set to 3.  When a `target_location_n_val` and `target_n_val` are both configured then the cluster change process will attempt to uphold both guarantees.

{: .highlight }
> The use of locations is optional within Riak, but may be useful even when the infrastructure has no physical distinction between nodes; as locations can also be used as a method for defining maintenance groups.  Maintenance groups are collections of nodes within a cluster which can be stopped or changed concurrently, as the loss of the whole group will only lead to the loss of one copy of the data.

The target `n_val` settings are used by the cluster claim algorithm, which is invoked [whenever a cluster change is planned](./BuildAndScaleClusterGuide.md#join-process---plan-a-change) (e.g. joining or leaving a node), to redistribute the vnodes around the cluster where required.  There are three usable versions of the cluster claim algorithm - versions 2, 3 and 4.  To use both `target_location_n_val` and `target_n_val` the cluster claim algorithm should be changed from version 2 (the default) to version 4.  

To discover what combinations may be supported given a cluster (given a count of nodes and distribution of nodes around locations), then the [offline ring calculator](https://github.com/OpenRiak/ring_calculator) may be used, to test settings before planning them with version 4 of the algorithm.  The bigger the `target_n_val` and `target_location_n_val` chosen, the more efficient and resilient the eventual cluster setup will be.

{: .warning }
> Failure to meet targets during cluster claim will lead to visual warnings when cluster change operations are requested - but not to failures.  If visual warnings are returned the ring calculator can be used to determine a supportable combination of settings.

#### Proactive reconciliation

Riak has support for proactive reconciliation within a cluster; known as [active anti-entropy (AAE)](./RiakTheoryGuide.md#anti-entropy).  Configuring AAE will trigger a background process that will continually verify that the most recent version of each object is correctly stored in all required locations, and prompt repairs should the verification process highlight discrepancies.  This is in addition to reactive management which is always enabled within Riak: as part of every GET request a read repair process may be triggered if all vnodes are not up-to-date; as part of failure management a handoff process will merge data captured on temporary fallback vnodes back into primary vnodes.

{: .highlight }
Proactive reconciliation provides continuous assurance that data is correctly secured across multiple devices within a cluster: it is verification as well as correction.  It is of particular use where data may be stored for long periods without being read, nullifying the trigger for reactive management via read repair.

There are two forms of proactive intra-cluster reconciliation in Riak:

- Tictac AAE (recommended).
  - Uses the [configuration option `tictacaae_active`](./InstallAndStartGuide.md#configuration-of-riak---key-riakconf-changes).
  - A prerequisite for efficient inter-cluster reconciliation.
  - A prerequisite for the use of the [AAE Fold API](./OtherAPI.md#aae-fold-api).
  - Requires a secondary keystore if not using the leveled backend.
  - Limits the pace of repair activity when discrepancies are discovered.
- Legacy hashtree AAE (default).
  - Uses the configuration option `anti-entropy`.
  - Has a dependency on the deprecated `eleveldb` backend.
  - Requires a separate keystore for all backends.
  - More aggressive than Tictac AAE at resolving discovered discrepancies.

{: .warning }
> If Tictac AAE is not enabled, there is an increased risk of data loss when Riak is used to store _cold_ data that is very rarely read.

Enabling Tictac AAE also adds to the cluster support for the operator-functionality associated with [AAE Folds](./OtherAPI.md#aae-fold-api).

### Intra-cluster data resilience - changing the choice

The `n_val` is in theory configurable by bucket, which allows for multiple nvals to be used within the cluster.  However, each unique n_val will increase the overhead of running anti-entropy (anti-entropy comparisons are per n_val, and separate caches are required for each n_val), and the complexity of configuring inter-cluster reconciliation.  Once a `n_val` has been set on a bucket, there is no tested way of reducing it and converging on a clean state - other than replicating to a new cluster and transitioning between clusters.  Increasing the `n_val` should eventually converge into an expected state.

The `target_n_val` and `target_location_n_val` configuration is used each time a cluster change is planned (i.e. adding or removing a node).  So using a new value will take effect once the next change is made within a cluster.

Both anti-entropy mechanisms can be deployed in parallel to help with transition.  Enabling anti-entropy takes time to take effect (as caches are built).  Disabling it is immediate, although garbage collecting any legacy on-disk overhead is a manual operator task.

## Interconnecting multiple clusters

### Interconnecting multiple clusters - making a choice

Riak clusters can be configured to replicate to other clusters, and further it is possible to continuously reconcile that the replication is correct (and prompt activity to resolve any deltas caused by replication failures).  Multiple clusters are generally used to:

- replicate into different physical locations to provide for disaster protection (e.g. between cloud regions, cloud providers, cloud availability zones, physical data centres, on and off-premises).
- provide clusters that support off-line usage of the data (e.g. reporting or backup), potentially with lower replication values (e.g. `n_val` of 1).
- replicate to additional clusters to provide for scale, or more efficient read activity in alternative locations.

The process of replication and reconciliation between the clusters is identical regardless of how multiple clusters are to be used.  An application cluster may consider two Riak clusters to be Active/Active, Active/Ready-Standby or Active/Passive; but these configurations must be managed in the broader system architecture as Riak clusters are by default Active/Active. Riak is an eventually consistent database, and as such does not by default prevent concurrent writes.  Concurrent updates will lead to multiple-values being retained, with default settings, and merging those values should be managed within the application.

It is possible to manage the potential for consistency issues [using conditional PUT logic (with token-based consensus)](./ObjectAPI.md#conditional-requests) that will block all but one of a concurrent update when the cluster is in a non-exceptional state.  However this control is only possible within a single cluster, there are no controls possible to block the creation of multi-value siblings when concurrent updates are allowed by the application into different clusters.

There are different design options available between using locations for resilience, and using multiple clusters.  For instance, in a cloud environment, potentially valid configurations for resilience would be:

- to deploy two clusters (`n_val` 3), one each in two separate availability zones, and a backup (`n_val` 1) cluster in a third availability zone - with locations aligned to placement groups for the nodes in the data-resilient clusters.  This provides the ability to switch the application between availability zones on failure without loss of resilience, and provides a total of 7 copies of the data all guaranteed to be in separate physical zones.
- to deploy a single cluster (`n_val` 5) spread across three availability zones (with locations aligned with availability zones).  This means that one cluster can be used to manage consistency (e.g. using conditional PUTs with token-based consensus), whilst guaranteeing there will always be at least two copies of the data available even if an entire Availability Zone is lost.  It would also be likely in this scenario that object GETs would generally not require the object value to traverse across availability zones (when using the leveled backend).
- to add to the above an additional cluster in an alternative cloud provider or cloud region.

Topologies of clusters are possible, but topologies are constrained in that it is not possible to forward updates through clusters; each cluster must subscribe to updates from every other cluster, so a full mesh is generally preferred.  

When splitting a cluster across physical locations, it should be noted that the network latency between nodes will delay client response to both read and write requests.  The latency impact should not impact cluster throughput.  If there are network bandwidth costs between those physical locations, these costs will be minimised by running separate clusters in each location.  Using location definitions (for cluster claim) within a cluster will not be as optimal as separate clusters, but will reduce bandwidth costs for reads relative to configuring a multi-cluster without locations - as generally the local fetch will be preferred.

### Interconnecting multiple clusters - changing the choice

Riak NextGen replication approach is the preferred method for interconnecting multiple clusters, but the legacy `riak_repl` approach to replication continues to be supported in Riak 3.4.  Combining the two approaches is not recommended without an understanding of the underlying code.

The [cluster migration process](./ReplicationGuide.md#migrating-a-cluster), can be used to migrate from a single cluster environment into a multi-cluster environment.

## Deleting data

### Deleting data - making a choice

Reliable deletion of data within eventually consistent databases is non-trivial.  There are two aspects of deletion to be considered, dynamic deletion of individual objects, and the scheduled deletion of expired objects.

The complexity of deletion with eventual consistency is that it is an underlying requirement in a distributed system to compare potentially differing results between different locations for an object (i.e. between vnodes or between clusters).  If location A has an object, and location B doesn't; there is a need to differ between the situation where location B is correct (due to a deletion not being replicated), or location A is correct (due to an insertion not being replicated) - as these circumstances require opposing actions.  There are secondary consequences if keys are reused following deletion, whereby data could be potentially lost if an old deleted object is resurrected and appears to be more recent.

For deletion there are three modes with which a cluster can be run: `keep`, `immediate` and `time-interval`.  For protection against data loss, the safest mode to use is the `keep` based method, especially where the intention is to run multiple inter-connected clusters or where an application may reuse a previous key for a new object.  The `keep` method is a configuration whereby no object is directly deleted, it is replaced instead by a special `tombstone` object that has no value (and will appear as not found when fetched via the Object API).  The tombstone retains a reference to its change history, [the version vector](./RiakTheoryGuide.md#version-vectors), so that it can be correctly assessed for recency when comparing with an undeleted version of the object, and to allow for tracking of causal consistency when replacing tombstones.

Tombstones have no significant cost in terms of disk space, as they have no value, but they exist as a key; and this represents an overhead for background operations and the memory footprint of the store.  It is good practice therefore to periodically reap old tombstones, where the tombstones have existed for a long-enough period to be sure that no lingering problems of stale data exist for that key (e.g. reap tombstones > 1 month old).

[Clearing of old tombstones is a a semi-automated process](./OperationsAndTroubleshootingGuide.md#garbage-collection---reap-erase-and-scheduled-compaction), and so has some ongoing operational overheads.

The `time-interval` method of deletion essentially automates the job of having a delay between the deletion and the reap.  However, for every object between deletion states all nodes hosting a related vnode for the object have to maintain an in-memory timer process for each object awaiting reap.  This limits the practical scale of the time-interval - generally this is used for setting the time-interval in seconds, which is insufficient to fully handle the risks associated with deletion and false recovery of data.  When stopping a node any pending reap timers will be discarded.

The `immediate` configuration ignores the risk of deletion, and does not use tombstones.

It is also possible to manage deletion through the use of a Time To Live.  However, using TTL is impractical when also using anti-entropy, and so this is not recommended unless there is permanent intention never to use anti-entropy or the related services (e.g. inter-cluster reconciliation).

{: .note }
> TTL and anti-entropy will be partially supported as of Riak 3.4 on a per-bucket basis in-conjunction with the [`aae_tree_exclude` bucket property](./InstallAndStartGuide.md#property---aae_tree_exclude)  - so that the disadvantages of not having anti-entropy are limited to those buckets with TTLs.  It is expected that this will be used for buckets which are specifically expected to be short-lived, and not requiring full reliability against data loss i.e. it is expected to be used for exceptional cases within a database, not as a general answer to deletion.

Through operational scheduling of [AAE folds](./OtherAPI.md#aae-fold-api), erase and reap jobs can be combined to clear old data, per-bucket, based on the last modified date of the object.  This approach is recommended in preference to the use of TTL, to allow for garbage collection of expired objects.

### Deleting data - changing the choice

The delete mode is a per-node configuration which needs to be applied consistently across all nodes in a cluster, and across all connected clusters.

Changing the delete mode is possible, with a restart, but needs to be a coordinated change across the whole environment - a small time delta between changes is not an issue and can be handled by anti-entropy and reconciliation processes.

## Mapping data to objects

### Mapping data to objects - making a choice

The most important design decision is how to map the data requirements in an application into the format of objects in a Key-Value store.  Getting this correct tends to be specific to the application, and is inter-dependent on other initial design decisions; but there is some general guidance that tends to be helpful in most cases:

- Optimise the model for reading not writing, by storing information that is likely required to be fetched together in the same object.  It is normally easier to fetch a single object and strip unnecessary information, than it is to fetch multiple objects to fulfil a single data-demand from the application. Where possible, make the most common read requests fulfilled via a single object read request.
- By default when using mutable objects, always use `allow_mult = true`, and ensure all updates pass the context of a recent read.  The optimisation gains from using `allow_mult = false` or `lww = true` are small, and the actual behaviour in this mode is often misunderstood.  The setting `allow_mult = false` should be preferred to `lww = true`, unless immutability is guaranteed - i.e. all objects are create-once, update-never.
- Eventually parallel writes will occur, and siblings will exist.  Siblings can be minimised using conditional PUTs, if sibling resolution is complex or requires manual intervention.  Use aae_folds feeding operator dashboards to track the generation of siblings.  To auto-resolve siblings CRDTs (conflict-free replicated data types) can be used, and third-party client-side libraries are generally a better long-term option than using Riak's internal CRDTs.
- Values can be large, especially when using the leveled backend.  Individual objects significantly in excess of 1MB are not in themselves likely to cause a direct performance issue.  Values are compressed before being persisted to disk (unless compression is disabled), when using the leveled-backend, so pre-compression is not necessary unless network bandwidth is a significant factor.
- Specialist data-types (e.g. conflict-free replicated data types) do not scale well as the objects grow.  The values of CRDTs (e.g. set sizes) should be kept small.
- There are three aspects to the object key - bucket type, bucket and key.  Bucket types simply allow for bucket metadata to be reduced, as the properties of the bucket are stored once in the type, not multiple times for each bucket: however there is no flexibility in the relationship between types and buckets (i.e. a bucket cannot change its type in the future).  In general scaling the number of buckets and bucket-types adds cognitive load for the developer and operator, especially if bucket properties are used to vary behaviour between different objects.
- Avoid single hot keys that are more frequently accessed (either for read or write) than any other key.
- Plan index entries for future query needs.  Joining the results of multiple queries within an individual request, is possible across indexes as of Riak 3.4 [via the Query API](./QueryAPI.md), but best performance is generally met by pre-concatenating index terms and running range queries with filters on concatenated terms.
- For very frequently demanded queries, and where false negatives are not tolerable but false positives are - the use of inverted index objects managed by the application is preferred over the use of secondary indexes.

### Mapping data to objects - changing the choice

Riak is designed to be agnostic to the format of the data, the schema belongs to the application and not the database.  It is therefore necessary to plan for schema migration within the application - detecting the schema version for an object, finding objects within a given schema version, updating a schema version in parallel to other application activity.

{: .note }
> It is recommended to plan for a lazy migration strategy, whereby the application can roll forward each object to the latest version on GET, without necessarily updating the persisted version, and then only updating the schema for the object on update.  With a lazy migration strategy, at the point of change only freshly updated objects will change.  Eventually all objects may need to be changed, and planning for a batch process to touch all objects not updated since the migration point will be required.
