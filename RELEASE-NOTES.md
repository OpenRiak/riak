# Riak KV 3.2.3 Release Notes

Some minor fixes and enhancements:

- Fix an issue with [the `riak admin services` command](https://github.com/OpenRiak/riak/issues/8).
- Fix [a potential cause of stalling in leveled](https://github.com/martinsumner/leveled/issues/459); this is of particular relevance for larger stores (by key count) i.e. >> 1m object keys per vnode.
- Add the ability to [change compression method in parallel-mode Tictac AAE stores](https://github.com/martinsumner/kv_index_tictactree/issues/120), which adds [extra configuration controls to AAE in general](https://github.com/OpenRiak/riak_kv/pull/48).

The preferred OTP version for this release is OTP 24, and the current plan is to increment 2 major OTP versions every minor version release (so Riak KV 3.4.0 will prefer OTP 26).

# Riak KV 3.2.2p1-nhse Release Notes

This minor patch release updates 3.2.2 to resolve an issue with binary memory management when using nextgenrepl to replicate objects with keys bigger than 64 bytes to clusters using the leveled backend.  Some utility functions have been added to riak_kv_utils, that were helpful in investigating this issue.

# Riak KV 3.2.2-nhse Release Notes

This release updates 3.2.1 to resolve an issue with handling of spaces in Riak commands (e.g. within JSON-based definitions of bucket properties, or `riak eval` statements).

# Riak KV 3.2.1-nhse Release Notes

This brings the Riak 3.2 branch in-line with the latest Riak KV 3.0 NHS release [3.0.18-nhse](https://github.com/nhs-riak/riak/releases/tag/riak-3.0.18-nhse), and also includes a number of uplifts to the Tictac AAE replication ecosystem.

The primary changes are:

- Support for both [zstd compression](https://github.com/martinsumner/leveled/pull/430) and [no compression](https://github.com/martinsumner/leveled/pull/417) in the leveled backend.
- Tidy up the [closing of processes within leveled](https://github.com/nhs-riak/leveled/pull/4).
- [Improvements to the CPU efficiency](https://github.com/martinsumner/leveled/pull/428) of leveled, specificaly when handling secondary index queries and aae folds.
- Upgrade the [json library used in producing 2i query results](https://github.com/nhs-riak/riak_kv/pull/20) to the [library scheduled for inclusion in OTP 27](https://github.com/erlang/otp/pull/8111).
- Add [data size estimation to the riak_kv_leveled_backend](https://github.com/nhs-riak/riak_kv/pull/18) to allow for progress reporting on transfers.
- Prevent the [start of replication processes before riak_kv startup has completed](https://github.com/nhs-riak/riak_kv/pull/23).
- [Improve repair-mode efficiency](https://github.com/nhs-riak/riak_kv/pull/26), so that each vnode is only repaired once, significantly reducing the cluster-wide overhead of entering repair mode (for AAE based full-sync).
- Prevent a [potential race condition whereby a queued tree rebuild may lead to an incorrect segment](https://github.com/nhs-riak/riak_kv/pull/27) in a cached tree.
- Revert to [a version of eleveldb based on the 3.0 path](https://github.com/nhs-riak/riak_core/pull/9), whereby the version of snappy is specifically referenced rather than depending on the OS-supported version.
- Improve the [monitoring of the node worker pools](https://github.com/nhs-riak/riak_core/pull/7).
- Minor fixes to [build and packaging](https://github.com/nhs-riak/riak/pull/2), as well as addition of [further VM configuration options](https://github.com/nhs-riak/riak/pull/4).

# Riak KV 3.2.0 Release Notes

This release is an OTP uplift release.  Whereas release 3.0.1 supports OTP 22; the intention is for Release 3.2.n to support OTP 22, OTP 24, and OTP 25.  There are potential throughput benefits of up to 10% when using OTP 24/25 rather than OTP 22 where load is CPU bound.  OTP 25 is currently the preferred platform for this release.

There are specific risks associated with OTP uplift releases due to the large volume of underlying changes inherited.  It is advised that Riak users should take specific care to test this release in a pre-production environment.  Please raise any issues discovered via Github.

As part of this change, the [lager](https://github.com/erlang-lager/lager) dependancy has been removed, with OTP's internal [logger](https://www.erlang.org/doc/apps/kernel/logger_chapter.html) used instead.  Any logging configuration should be updated as a part of the migration, using the new options made available via [riak.conf](https://github.com/basho/riak/blob/812ded6d64b080beeb068ba92f508556e6916d97/priv/riak.schema#L1-L35).  Support for logging using syslog has been removed.  The leveled backend will still write directly to erlang.log files, but this will be addressed in [a future release](https://github.com/martinsumner/leveled/issues/388).

There has been a significant overhaul of the release and packaging scripts in order to adopt changes within [relx](https://github.com/erlware/relx).  Note that due to the updates in relx, `riak daemon` should be used instead of `riak start`.  Some riak and riak-admin commands may also now return an additional `ok` output.  Going forward, both `riak admin` and `riak-admin` should work for admin commands.  Packaging suport has now been added for Alpine Linux and FreeBSD.

Note that this release of Riak is packaged with a bespoke build of [rebar3](https://github.com/martinsumner/rebar3/tree/mas-alternative_deprecation_warning), this alters mainstream rebar3/relx to allow us control over deprecation warnings in relx.

When building from source, the `snappy` dependancy is now made rather than fetched using a cached package, so support for `cmake` is required to build.  Note that on older versions of OSX the current version of snappy will not compile.  This will be resolved when their is a formal release version of snappy containing [this fix](https://github.com/google/snappy/commit/8dd58a519f79f0742d4c68fbccb2aed2ddb651e8).

In this release, tagging of individual dependencies has not been used.  Building consistently with the correct versions of dependencies is therefore dependent on the commit references being used from within the rebar.lock file.

# Riak KV 3.0.18-nhse Release Notes

This internal release helps with the operation of a Riak cluster with `delete_mode` set to `keep`:

- The nextgenrepl solution is enhanced with [a configurable option](https://github.com/nhs-riak/riak_kv/blob/ca26ab26f03535eeb18bf88845782a4de226690f/priv/riak_kv.schema#L1347-L1352) to [replicate reap requests from the riak_kv_reaper](https://github.com/nhs-riak/riak_kv/pull/6) so that reap queries can be made whilst keeping clusters in full-sync.
- The `$key` query feature [may now be configured](https://github.com/nhs-riak/riak_kv/blob/ca26ab26f03535eeb18bf88845782a4de226690f/priv/riak_kv.schema#L1520-L1527) to [ignore tombstones when the backend is leveled](https://github.com/nhs-riak/riak_kv/pull/8) to mimic the behaviour normally seen by queries when running other delete modes.

# Riak KV 3.0.17-nhse Release Notes

This internal release is to resolve a number of issues related to full-sync and aae_folds:

- A fix to allow for [changes to be made safely](https://github.com/basho/riak_kv/pull/1868) at run-time to sink workers, without sink workers being unexpectedly over-provisioned.
- A fix to ensure that [the startup of Riak is not delayed by connection timeouts and connection timeouts do not cause peer or sink crashes](https://github.com/nhs-riak/riak_kv/pull/1).
- A fix to ensure that use of the `local` change_method in reap/erase aae_folds do lead to the [erase and reap work being distributed across the cluster](https://github.com/nhs-riak/riak_kv/pull/4).

# Riak KV 3.0.16 Release Notes

This release includes the following updates:

- A significant new [riak_core cluster claim algorithm](https://github.com/basho/riak_core/pull/1008) has been added - `choose_claim_v4`.  The default cluster claim algorithm (`choose_claim_v2`) is unchanged, but the `choose_claim_fun` configuration option in riak.conf can be used to enable the new algorithm.  The new algorithm offers significant improvements in the claim process, especially when location awareness is enabled, with the algorithm now more likely to find valid solutions and with fewer required transfers.  The trade-off when compared to `choose_claim_v2` is that in some situations computational overhead of claim may increase by multiple orders of magnitude, leading to long cluster plan times.

- The leveled backend has been updated to reduce the memory required for stores with a large number of keys, and also reduce volatility in the memory demanded, by [optimising the memory footprint of the SST process working heap](https://github.com/martinsumner/leveled/pull/403).

- A collection of fixes have been added.  A fix to timeouts in [leveled hot backups](https://github.com/martinsumner/leveled/pull/406).  A fix to reap and erase queries to [prevent a backlog from overloading riak_kv_eraser or riak_kv_reaper mailboxes](https://github.com/basho/riak_kv/pull/1862) (creating rapidly increasing memory footprint).  A fix to an issue with [nextgen replication when node_confirms is enabled](https://github.com/basho/riak_kv/pull/1858).  The [R/W value used by nextgen replication is now configurable](https://github.com/basho/riak_kv/pull/1860), and this may be useful for preventing a backlog of replication events from overloading a cluster.

As a result of the memory management improvements made in 3.0.16, the recommendation to consider altering the eheap single-block carrier threshold made in [Riak 3.0.12](#riak-kv-3012-release-notes) has been deprecated.  With the leveled backend, memory management should now be efficient on default settings, although with a small overhead on the latency of HEAD operations in that backend.

# Riak KV 3.0.15 Release Notes

Fix to an issue introduced with the `auto_check` feature for TictacAAE full-sync in [Riak KV 3.0.10](#riak-kv-3010-release-notes).

# Riak KV 3.0.14 Release Notes

This release [fixes an issue](https://github.com/martinsumner/leveled/issues/393) whereby a failure to signal and handle back-pressure correctly by the leveled backend can cause a backlog within the store.  In particular this can be triggered by handoffs (e.g. due to cluster admin operations), and lead to partition transfers stalling almost completely.  The issue existed in previous releases, by may have been exacerbated by refactoring in [Riak KV 3.0.13](#riak-kv-3013-release-notes).

An additional [minor improvement has been made to handoffs](https://github.com/basho/riak_kv/pull/1851). Previously requests to reap tombstones after deletions (where the delete_mode is not `keep`), would not be forwarded during handoffs.  These tombstones would then need to be corrected by AAE (which may result in a permanent tombstone).  There is now a configuration option `handoff_deletes` which can be enabled to ensure these reap requests are forwarded, reducing the AAE work required on handoff completion.

Desipite the handoff improvements in [Riak KV 3.0.13](#riak-kv-3013-release-notes), handoff timeouts are still possible.  If handoff timeouts do occur, then the first stage should be to reduce the [handoff batch threshold count](https://github.com/basho/riak_core/blob/riak_kv-3.0.14/priv/riak_core.schema#L47-L55) to a lower number than that of [the item_count in the handoff sender log](https://github.com/basho/riak_core/blob/riak_kv-3.0.14/src/riak_core_handoff_sender.erl#L474-L486).

# Riak KV 3.0.13 Release Notes

This release is focused on improving the reliability of handoffs.  The speed of handoffs is critical to the recovery times of nodes following failure, and also to the time necessary to expand or contract the cluster.  Controlling the speed can be managed by increasing concurrency (using `riak admin transfer-limit <limit>`), but this can often lead to handoff unreliability due to timeouts.

- The main [handoff process has been refactored](https://github.com/basho/riak_core/pull/995) to remove some deprecated messages, simplify the naming of configuration items, improve the logging of handoffs and increase the frequency of handoff sync messages.  More frequent sync messages should make the flow of handoffs from the sender more responsive to pressure at the receiver.

-  On joining a node to a cluster, there will now be an attempt to exchange metadata with the joining node before the join is staged.  This should reduce the probability of events failing immediately after join, as bucket types had not yet been replicated to the joining node.

- A [new configuration option has been added](https://github.com/basho/riak_kv/blob/fbb53630645e53af053228d526caa3c86f304066/priv/riak_kv.schema#L1469-L1487) to change Riak to only commit read repair on primary (not fallback) vnodes.  In short-term failures, enabling this option will reduce the time taken for hinted handoff to complete following recovery of a failed node - as now the handoff will contain only objects changed for that partition during the outage.  With the default setting of `disabled`; fallback nodes will also contain each object fetched during the outage, in-line with the behaviour in previous releases.

- A [fix has been implemented in leveled](https://github.com/martinsumner/leveled/pull/390) to reduce failures and inefficiencies when re-building the ledger key store from the object Journal, in situations where there has been a high volume of object churn.

- Some [helper functions have been added to riak_client](https://github.com/basho/riak_kv/blob/fbb53630645e53af053228d526caa3c86f304066/src/riak_client.erl#L949-L993), to simplify some operational tasks.  These functions can be called from `riak remote_console`, e.g. `riak_client:repair_node().` - which replaces the series of commands previously required to run partition repair across all partitions on a node. `riak_client:tictacaae_suspend_node().` may be used to suspend Tictacaae AAE exchanges on a node following a failure, so that they can be re-enabled using `riak_client:tictacaae_resume_node().` once handoffs have been completed.

There are still [outstanding](https://github.com/basho/riak_kv/issues/1846) [issues](https://github.com/basho/riak_core/issues/996) related to handoffs.

The release also includes a [significant change to the HTTP API](https://github.com/basho/riak_kv/issues/1849).  In previous releases PUT, POST and DELETE requests would all GET the object prior to starting the PUT process.  This is in contrast to the Protocol Buffers API which would only GET the object in case where conditions were passed in the put (e.g. `if_none_match` or `if_not_modified`).  These two APIs now have the same non-functional behaviour, the HTTP API will no longer request a GET before the PUT if the request does not contain a condition (e.g. using `If-None-Match`, `If-Match`, `If-Modified-Since` as well as a new bespoke condition `X-Riak-If-Not-Modified`).

A vector clock being passed on a PUT using the `X-Riak-If-Not-Modified` header, will return a `409:Conflict` should the passed vector clock not match the clock found prior to updating the object.  This will work as the PB API `if_not_modified` option.  This is still an eventually consistent condition, parallel updates may still lead to siblings when `{allow_mult, true}`.

# Riak KV 3.0.12 Release Notes

This is a general release of changes and fixes:

- A [fix to a critical issue with the use of PR variables](https://github.com/basho/riak_kv/pull/1836) in Riak KV (when the PR value is set via bucket properties).

- Changes to the leveled backend with the aim of further improving memory management, by simplifying the [summary tree within each leveled_sst file](https://github.com/martinsumner/leveled/pull/383).

- An [update to leveldb snappy compression](https://github.com/basho/eleveldb/pull/267), to make Riak compatible with a broader set of platforms (including AWS Graviton).  Because of this change, anyone building from source will now require `cmake` to be installed.

- A [new `reip_manual` console command](https://github.com/basho/riak/pull/1122) has been added to use as an alternative to `reip`, which does not currently work in the 3.0 release stream.  Use `riak admin reip_manual` in place of `riak admin reip` when performing the reip operation on a node.  This now requires that the path to the ring file, and the cluster name, to be known by the operator.

- Some [improvements to logging within the leveled backend](https://github.com/martinsumner/leveled/pull/385) have been made to allow for better statistics monitoring of low-level operations, and reduce the cost of writing a log within leveled.

- A fix for a deadlock issue in [riak_repl AAE fullsync](https://github.com/basho/riak_repl/pull/818) to help when clusters with high object counts have large deltas.

- [Two](https://github.com/basho/riak_kv/pull/1839) [other](https://github.com/basho/riak_kv/pull/1837) fixes within Riak KV.

As part of this release, further testing of the new memory configuration options added in Riak 3.0.10 has been undertaken.  It is now recommended when using the leveled backend, that if memory growth in the Riak process is a signifcant concern, then the following configuration option may be tested: `erlang.eheap_memory.sbct = 128`.  This has been shown to reduce the memory footprint of Riak, with a small performance overhead.

# Riak KV 3.0.11 Release Notes

A simple change to [release a bottleneck](https://github.com/martinsumner/leveled/issues/379) in 2i queries with the leveled backend.  Should only be relevant to those using leveled, and attempting o(1000) 2i queries per second.

# Riak KV 3.0.10 Release Notes

This release is focused on improving memory management, especially with the leveled backend, and improving the efficiency and ease of configuration of tictacaae full-sync.

- Improved [memory management of leveled](https://github.com/martinsumner/leveled/pull/371) SST files that contain [rarely accessed data](https://github.com/martinsumner/leveled/pull/371)

- Fix a bug whereby leveled_sst files could spend an [extended time in the delete_pending state](https://github.com/martinsumner/leveled/pull/377), causing significant short-term increases in memory usage when there are work backlogs in the penciller.

- Change the queue for reapers and erasers so that [they overflow to disk](https://github.com/basho/riak_kv/issues/1807), rather than simply consuming more and more memory.

- Change the replrtq (nextgenrepl) queue to use the same [overflow queue mechanism](https://github.com/basho/riak_kv/issues/1817) as used by the reaper and erasers.

- Change the default full-sync mechanism for tictacaae (nextgenrepl) full-sync to `auto_check`, which attempts to [automatically learn and use information about modified date-ranges](https://github.com/basho/riak_kv/issues/1815) in full-sync checks. The related changes also make full-sync by default bi-directional, reducing the amount of wasted effort in full-sync queries.

- Add [a peer discovery feature](https://github.com/basho/riak_kv/issues/1804) for replrtq (nextgenrepl) so that new nodes added to the cluster can be automatically recognised without configuration changes.  By default this is disabled, and should only be enabled once both clusters have been upgraded to at least 3.0.10.

- Allow for underlying beam memory management and scheduler configuration to be exposed via riak.conf to allow for further performance tests on these settings.  Note initial tests indicate the potential for [significant improvements when using the leveled backend](https://github.com/basho/riak_kv/issues/1826).

- Fix a potential issue whereby corrupted objects would prevent AAE (either legacy or nextgenrepl) [tree rebuilds](https://github.com/basho/riak_kv/issues/1824) from completing.

- Improved [handling of key amnesia](https://github.com/basho/riak_kv/issues/1813), to prevent rebounding of objects, and also introduce a reader process (like reaper and eraser) to which read repairs can be queued with overflow to disk.

Some caveats for this release exist:

- The release does not support OTP 20, only OTP 22 is supported.  Updating some long out-of-date components have led to a requirement for the OTP version to be lifted.

- Volume and performance testing with the leveled backend now uses the following non-default settings:

```
erlang.schedulers_busywait = none
erlang.schedulers_busywait_dirtycpu = none
erlang.schedulers_busywait_dirtyio = none
erlang.async_threads = 4
erlang.schedulers.force_wakeup_interval = 0
erlang.schedulers.compaction_of_load = true
leveled_reload_recalc = enabled
```

- To maintain backwards compatibility with older linux versions, the [latest version of basho's leveldb](https://github.com/basho/leveldb/releases/tag/2.0.37) is not yet supported.  This is likely to change in the next release, where support for older linux versions will be dropped.

- The release process has [exposed an issue](https://github.com/basho/riak_kv/issues/1831) via a recently extended test.  This issue is pre-existing, and not specific to this release.

# Riak KV 3.0.9 Release Notes

This release contains stability, monitoring and performance improvements.

- Fix to the [riak_core coverage planner](https://github.com/basho/riak_kv/issues/1801) to significantly reduce the CPU time required to produce a coverage plan, especially with larger ring sizes.  This improves both the mean and tail-latency of secondary index queries.  As a result of this change, it is recommended that larger ring sizes should be used by default, even when running relatively small clusters - for example in standard volume tests a ring size of 512 is outperforming lower ring sizes even on small (8-node) clusters.

- Further monitoring stats have been added to track the performance of coverage queries, in particular secondary index queries.  For each worker queue (e.g. vnode_worker_pool, af1_pool etc) the queue_time and work_time is now monitored with results available via riak stats.  The result counts, and overall query time for secondary index queries are now also monitored via riak stats. See the [PR](https://github.com/basho/riak_kv/pull/1802#issuecomment-966160925) for a full list of stats added in this release.

- Change to some default settings to be better adapted to running with higher concentrations of vnodes per nodes.  The per-vnode cache sizes in leveled are reduced, and the [default size of the vnode_worker_pool has been reduced from 10 to 5](https://github.com/basho/riak_kv/blob/0af857d57d0206b100db59043a926df2ada8f7db/priv/riak_kv.schema#L1210-L1233) and is now configurable via riak.conf.  Exceptionally heavy users of secondary index queries (i.e. > 1% of transactions), should consider monitoring the [new queue_time and work_time statistics](https://github.com/basho/riak_kv/pull/1802#issuecomment-966160925) before accepting this new default.

- Fix to an issue in the leveled backend when a key and (internal) sequence number would [hash to 0](https://github.com/martinsumner/leveled/issues/361).  It is recommended that users of leveled uplift to this version as soon as possible to resolve this issue.  The risk is mitigated in Riak as it can generally be expected that most keys will have different sequence numbers in different vnodes, and will always have different sequence numbers when re-written - so normal anti-entropy process will recover from any localised data loss.

- More time is now given to the legacy AAE `kv_index_hashtree` process to [shut down](https://github.com/basho/riak_kv/pull/1803), to handle delays as multiple vnodes are shutdown concurrently and contend for disk and CPU resources.

# Riak KV 3.0.8 Release Notes

This release contains a number of stability  improvements.

- Fix to critical issue in leveled when using (non-default, but recommended, option): [leveled_reload_recalc = enabled](https://github.com/basho/riak_kv/blob/33add2a29b6880b680a407dc91828736f54c7911/priv/riak_kv.schema#L1156-L1174).  If using this option, it is recommended to rebuild the ledger on each vnode at some stage after updating.

- [Fix to an issue with cluster leave](https://github.com/basho/riak_core/issues/970) operations that could leave clusters unnecessarily unbalanced after Stage 1 of leave, and also cause unexpected safety violations in Stage 1 (with either a simple transfer or a rebalance).  An option to force a rebalance in Stage 1 is also now supported.

- The ability to [set an environment variable](https://github.com/basho/riak/pull/1079) to remove the risk of atom table exhaustion due to repeated calls to `riak status` (and other) command-line functions.

- The default setting of the object_hash_version environment variable to reduce the opportunity for the [riak_core_capability system to falsely request downgrading to legacy](https://github.com/basho/riak_kv/issues/1656), especially when concurrently restarting many nodes.

- An update to the versions of `recon` and `redbug` used in Riak.

- The fixing of an issue with [connection close handling](https://github.com/basho/riak-erlang-client/pull/402) in the Riak erlang client.

This release also contains two new features:

- A [new aae_fold operation](https://github.com/basho/riak_kv/issues/1793) has been added which will support the prompting of read-repair for a range of keys e.g. all the keys in a bucket after a given last modified date.  This is intended to allow an operator to accelerate full recovery of data following a known node outage.

- The addition of the [`sync_on_write` property for write operations](https://github.com/basho/riak_kv/blob/develop-3.0/docs/Sync-On-Write.md).  Some Riak users require flushing of writes to disk to protect against data loss in disaster scenarios, such as mass loss of power across a DC.  This can have a significant impact on throughput even with hardware acceleration (e.g. flash-backed write caches).  The decision to flush was previously all or nothing.  It can now be set as a bucket property (and even determined on individual writes), and can be set to flush on `all` vnodes or just `one` (the coordinator), or to simply respect the `backend` configuration.  If `one` is used the single flush will occur only on client-initiated writes - writes due to handoffs or replication will not be flushed.

# Riak KV 3.0.7 Release Notes

The primary change in 3.0.7 is that Riak will now run the [erlang runtime system in interactive mode, not embedded mode](http://erlang.org/doc/man/code.html).  This returns Riak to the default behaviour prior to Riak KV 3.0, in order to resolve a number of problems which occurred post 3.0 when trying to dynamically load code.

The mode used is controlled in a [pre-start script](https://github.com/basho/riak/blob/develop-3.0/rel/files/erl_codeloadingmode), changing this script or overriding the referenced environment variable for the riak user should allow the runtime to be reverted to using `embedded` mode, should this be required.

This release also extends a prototype API to support for the use of the `nextgenrepl` API by external applications, for example to reconcile replication to an external non-riak database.  The existing `fetch` api function has been extended to allow for a new response format that includes the Active Anti-Entropy Segment ID and Segment Hash for the object (e.g. to be used when recreating the Riak merkle tree in external databases).  A new `push` function has been added to the api, this will push a list of object references to be queued for replication.

# Riak KV 3.0.6 Release Notes

Release 3.0.5 adds [location-awareness to Riak cluster management](https://github.com/basho/riak_core/blob/riak_kv-3.0.5/docs/rack-awareness.md).  The broad aim is to improve data diversity across locations (e.g. racks) to reduce the probability of data-loss should a set of nodes fail concurrently within a location.  The location-awareness does not provide firm guarantees of data diversity that will always be maintained across all cluster changes - but [testing](https://github.com/basho/riak_test/pull/1353) has indicated it will generally find a cluster arrangement which is close to optimal in terms of data protection.

If location information is not added to the cluster, there will be no change in behaviour from previous releases.

There may be some performance advantages when using the location-awareness feature in conjunction with the leveled backend when handling GET requests.  With location awareness, when responding to a GET request, a cluster is more likely to be able to fetch an object from a vnode within the location that received the GET request, without having to fetch that object from another location (only HEAD request/response will commonly travel between locations).

This release is tested with OTP 20 and OTP 22; but optimal performance is likely to be achieved when using OTP 22.

# Riak KV 3.0.5 Release Notes

Release version skipped due to tagging error

# Riak KV 3.0.4 Release Notes

There are two fixes provided in Release 3.0.4:

- An issue with [leveled application dependencies](https://github.com/basho/riak/issues/1059) has been resolved, and so lz4 can now again be used as the compression method.

- The [riak clients are now compatible with systems that require semantic versioning](https://github.com/basho/riak-erlang-client/issues/400).

This release is tested with OTP 20, OTP 21 and OTP 22; but optimal performance is likely to be achieved when using OTP 22.


# Riak KV 3.0.3 Release Notes

There are two fixes provided in Release 3.0.3:

- A [performance issue with OTP 22 and leveled](https://github.com/martinsumner/leveled/issues/326) has been corrected.  This generally did not have a significant impact when running Riak, but there were some potential cases with Tictac AAE and AAE Folds where there could have been a noticeable slowdown.

- An [issue with console commands for bucket types](https://github.com/basho/riak/issues/1043) has now been fully corrected, having been partially mitigated in 3.0.2.

This release is tested with OTP 20, OTP 21 and OTP 22; but optimal performance is likely to be achieved when using OTP 22.


# Riak KV 3.0.2 Release Notes

There are four changes made in Release 3.0.2:

- Inclusion of backend fixes introduced in [2.9.8](#riak-kv-298-release-notes).

- The addition of the [`range_check` in the Tictac AAE based full-sync replication](https://github.com/basho/riak_kv/blob/riak_kv-3.0.2/docs/NextGenREPL-GettingStarted.md#configure-full-sync-replication), when replicating between entire clusters.  This, along with the backend performance improvements delivered in 2.9.8, can significantly improve the stability of Riak clusters when resolving large deltas.

- A number of issues with command-line functions and packaging related to the switch from `node_package` to `relx` have now been resolved.

- Riak tombstones, [empty objects used by Riak to replace deleted objects](https://riak.com/posts/technical/riaks-config-behaviors-part-3/index.html), will now have a last_modified_date added to the metadata, although this will not be visible externally via the API.

This release is tested with OTP 20, OTP 21 and OTP 22; but optimal performance is likely to be achieved when using OTP 22.


# Riak KV 3.0.1 Release Notes

This major release allows Riak to run on OTP versions 20, 21 and 22 - but is not fully backwards-compatible with previous releases.  Some limitations and key changes should be noted:

- It is not possible to run this release on any OTP version prior to OTP 20.  Testing of node-by-node upgrades is the responsibility of Riak customers, there has been no comprehensive testing of this upgrade managed centrally.  Most customer testing of upgrades has been spent on testing an uplift from 2.2.x and OTP R16 to 3.0 and OTP 20, so this is likely to be the safest transition.

- This release will not by default include Yokozuna support, but Yokozuna can be added in by reverting the commented lines in rebar.config.  There are a number of riak_test failures with Yokozuna, and these have not been resolved prior to release.  More information on broken tests can be found [here](https://github.com/basho/yokozuna/pull/767).  Upgrading with yokozuna will be a breaking change, and data my be lost due to the uplift in solr version.  Any migration will require bespoke management of any data within yokozuna.

- Packaging support is not currently proven for any platform other than CentOS, Debian or Ubuntu.  Riak will build from source on other platforms - e.g. `make locked-deps; make rel`.

- As part of the release there has been a comprehensive review of all tests across the dependencies (riak_test, eunit, eqc and pulse), as well as removal of all dialyzer and xref warnings and addition where possible of travis tests.  The intention is to continue to raise the bar on test stability before accepting Pull Requests going forward.

- If using riak_client directly (e.g. `{ok, C} = riak:local_client()`), then please use `riak_client:F(*Args, C)` not `C:F(*Args)` when calling functions within riak_client - the latter mechanism now has issues within OTP 20+.

- Instead of `riak-admin` `riak admin` should now be used for admin CLI commands.

Other than the limitations listed above, the release should be functionally identical to Riak KV 2.9.7.  Throughput improvements may be seen as a result of the OTP 20 upgrade on some CPU-bound workloads.  For disk-bound workloads, additional benefit may be achieved by upgrading further to OTP 22.

# Riak KV 2.9.10 Release Notes

Fix to critical issue in leveled when using (non-default, but recommended, option): [leveled_reload_recalc = enabled](https://github.com/basho/riak_kv/blob/33add2a29b6880b680a407dc91828736f54c7911/priv/riak_kv.schema#L1156-L1174).

If using this option, it is recommended to rebuild the ledger on each vnode at some stage after updating.

# Riak KV 2.9.9 Release Notes

Minor stability improvements to leveled backend - [see leveled release notes](https://github.com/martinsumner/leveled/releases/tag/0.9.24) for further details.

# Riak KV 2.9.8 Release Notes

This release improves the performance and stability of the leveled backend and of AAE folds.  These performance improvements are based on feedback from deployments with > 1bn keys per cluster.

The particular improvements are:

- In leveled, caching of individual file scores so not all files are required to be scored each journal compaction run.

- In leveled, a change to the default journal compaction scoring percentages to make longer runs more likely (i.e. achieve more compaction per scoring run).

- In leveled, a change to the caching of SST file block-index in the ledger, that makes repeated folds with a last modified date range an order of magnitude faster through improved computational efficiency.

- In leveled, a fix to prevent very long list-buckets queries when buckets have just been deleted (by erasing all keys).

- In kv_index_tictcatree, improved logging and exchange controls to make exchanges easier to monitor and less likely to prompt unnecessary work.

- In kv_index_tictcatree, a change to speed-up the necessary rebuilds of aae tree-caches following a node crash, by only testing journal presence in scheduled rebuilds.

- In riak_kv_ttaaefs_manager, some essential fixes to prevent excessive CPU load when comparing large volumes of keys and clocks, due to a failure to decode clocks correctly before passing to the exchange.

Further significant improvements have been made to Tictac AAE full-sync, to greatly improve the efficiency of operation when there exists relatively large deltas between relatively large clusters (in terms of key counts).  Those changes, which introduce the use of 'day_check', 'hour_check' and 'range_check' options to nval-based full-sync will be available in a future 3.0.2 release of Riak.  For those wishing to use Tictac AAE full-sync at a non-trivial scale, it is recommended moving straight to 3.0.2 when it is available.


# Riak KV 2.9.7 Release Notes

This release improves the stability of Riak when running with Tictac AAE in parallel mode:

- The aae_exchange schedule will back-off when exchanges begin to timeout due to pressure in the system.

- The aae_runner now has a size-limited queue of snapshots for handling exchange fetch_clock queries.

- The aae tree rebuilds now take a snapshot at the point the rebuild is de-queued for work, not at the point the rebuild is added to the queue.

- The loading process will yield when applying the backlog of changes to allow for other messages to interleave (that may otherwise timeout).

- The aae sub-system will listen to back-pressure signals from the aae_keystore, and ripple a response to slow-down upstream services (and ultimately the riak_kv_vnode).

- It is possible to accelerate and decelerate AAE repairs by setting riak_kv application variables during running (e.g `tictacaae_exchangetick`, `tictacaae_maxresults`), and also log AAE-prompted repairs using `log_readrepair`.

The system is now stable under specific load tests designed to trigger AAE failure.  However, parallel mode should still not be used in production systems unless it has been subject to environment-specific load testing.


# Riak KV 2.9.6 Release Notes

Withdrawn.


# Riak KV 2.9.5 Release Notes

Withdrawn.


# Riak KV 2.9.4 Release Notes

This release replaces the Riak KV 2.9.3 release, extending the issue resolution in kv_index_tictactree to detect other files where file truncation means the CRC is not present.

This release has a key [outstanding issue](https://github.com/basho/riak_kv/issues/1765) when Tictac AAE is used in parallel mode.  On larger clusters, this has been seen to cause significant issues, and so this feature should not be used other than in native mode.   


# Riak KV 2.9.3 Release Notes - NOT TO BE RELEASED

This release is focused on fixing a number of non-critical issues:

- [An issue with Tictac AAE](https://github.com/basho/riak_kv/issues/1759) failing to clean-up state correctly on node leaves, which may lead to false repairs on re-joining a node (until tree rebuilds occur).

- [An issue with using the leveled backend in Riak CS](https://github.com/basho/riak_kv/issues/1758) releated to the ordered object fold not respecting the passed in range and crashing on hitting an out of range value.

- [An issue with duplicate PUTs](https://github.com/basho/riak_kv/issues/1754) related to retries of PUT coordinater forward requests due to lost ACKs.

- [An issue with Tictac AAE startup](https://github.com/martinsumner/kv_index_tictactree/issues/74) caused by a failure of the corrupt file detection to handle a situation where file truncation means the CRC is not present.


# Riak KV 2.9.2 Release Notes

This release includes:

- An extension to the `node_confirms` feature so that `node_confirms` can be [tracked on GETs as well as PUTs](https://github.com/basho/riak_kv/issues/1750).  This is provided so that if an attempt to PUT with a `node_confirms` value failed, a read can be made which will only succeed if repsonses from sufficient nodes are received.  This does not confirm absolutely that the actual returned response is on sufficient nodes, but does confirm nodes are now up so that anti-entropy mechanisms will soon resolve any missing data.  

- Support for building [leveldb on 32bit platforms](https://github.com/basho/leveldb/commit/14c57fe018402b3271cc8ac070fbd620b6ff7798).

- Improvements to reduce the cost of journal compaction in leveled when there are large numbers of files containing mainly skeleton key-changes objects.  The cost of scoring all of these files could have a notable impact on read loads when spinning HDDs are used (although this could be mitigated by running the journal compaction less frequently, or out of hours).  Now an attempt is made to reduce this scoring cost by reading the keys to be scored in order, and scoring keys relatively close together.  This will reduce the size of the disk head movements required to complete the scoring process.

- The abilty to switch the configuration of leveled [journal compaction to using `recalc` mode](https://github.com/martinsumner/leveled/issues/306), and hence avoid using skeleton key changes objects altogether.  The default remains `retain` mode, the switch from `retain` mode to enabling `recalc` is supported without any data modification (just a restart required).  There is though, no safe way other than leaving the node from the cluster (and rejoining) to revert from `recalc` back to `retain`.  The use of the `recalc` strategy [can be enabled via configuration](https://github.com/basho/riak_kv/blob/riak_kv-2.9.2/priv/riak_kv.schema#L1120-L1138).  The use of `recalc` mode has outperformed `retain` in tests, when both running journal compaction jobs, and recovering empty ledgers via journal reloads.

- An improvement to the efficiency of [compaction in the leveled LSM-tree based ledger](https://github.com/martinsumner/leveled/issues/311) with large numbers of tombstones (or modified index entries), by using a `grooming` selection strategy 50% of the time when selecting files to merge rather than selecting files at random each time.  The `grooming` selection, will take a sample of files and merge the one with the most tombstones.  The use of the grooming strategy is not configurable, and will have no impact until the vast majority of SST files have been re-written under this release.


# Riak KV 2.9.1 Release Notes

This release adds a number of features built on top of the Tictac AAE feature made available in 2.9.0.  The new features depend on Tictac AAE being enabled, but are backend independent. The primary features of the release are:

- A new combined full-sync and real-time replication system `nextgenrepl`, that is much faster and more efficient at reconciling overall state of clusters (e.g. full-sync).  This feature is explained further [here](https://github.com/basho/riak_kv/blob/riak_kv-2.9.1.1/docs/NextGenREPL.md).

- A mechanism for requesting mass deletion of objects on expiry, and mass reaping of tombstones after a time to live.  This is not yet an automated, scheduled, set of garbage collection processes, it is required to be triggered by an operational process.  This feature is explained further [here](https://github.com/basho/riak_kv/blob/riak_kv-2.9.1.1/docs/ReapErase.md).

- A safe method of listing buckets regardless of backend chosen.  Listing buckets had previously not been production safe, but can still be required in production environments - it can now be managed safely via an aae_fold.  For more information on using the HTTP API for all aae_folds see [here](https://github.com/basho/riak_kv/blob/develop-2.9/src/riak_kv_wm_aaefold.erl#L19-L91).  Or to use via the riak erlang client see [here](https://github.com/basho/riak-erlang-client/blob/riak_kv-2.9.1/src/riakc_pb_socket.erl#L1344-L1932).

- A version uplift of the internal `ibrowse` client, a minor `riak_dt` fix to resolve issues of unit test reliability, a fix to help build (the now deprecated) erlang_js in some environments, and the removal of `hamcrest` as a dependency.

Detail of volume testing related to the replication uplift can be found [here](https://github.com/martinsumner/riak_testing_notes/blob/master/Release%202.9.1%20-%20Volume%20Tests.md).


# Riak KV 2.9.0 Release Notes - Patch 5

This patch release is primarily required to improve two scenarios where leveled's handling of file-system corruption was unsatisfactory.  One scenario related to [corrupted blocks that fail CRC checks](https://github.com/martinsumner/leveled/issues/298), another related to failing to consistently check that [a file write had been flushed to disk](https://github.com/martinsumner/leveled/issues/301).

The patch also removes `eper` as a dependency, instead having direct dependencies on `recon` and `redbug`.  This as a side effect, resolves the background noise of CI failures related to eper eunit test inconsistency.

The patch resurrects Fred Dushin's work to [improve the isolation between Yokozuna and Riak KV](https://github.com/basho/riak_kv/pull/1721).  This, in the future will make it easier for those not wishing to carry Yokozuna as a dependency to deploy Riak without it.  Any Yokozuna users should take extra care in pre-production testing of this patch.  Testing time for Yokozuna within the Riak release cycle is currently very limited.

The patch changes the handling by bitcask and eleveldb backends when file-systems are switched [into a read-only state](https://github.com/basho/riak_kv/issues/1714).  This previously might lead to zombie nodes, nodes that are unusable never actually close due to failures, and so continue to participate in the ring.

The patch changes the capability request for `HEAD` to be bucket-dependent, so that [HEAD requests are supported correctly in a multi-backend configuration](https://github.com/basho/riak_kv/issues/1719).

Finally, the aae_fold features of 2.9.0 were previously only available via the HTTP API.  Such folds can now also be [requested via the PB API](https://github.com/basho/riak_kv/pull/1732).


# Riak KV 2.9.0 Release Notes - Patch 4

There are a number of fixes in this patch:

- Mitigation, and further monitoring, to assist in [an issue](https://github.com/basho/riak_kv/issues/1707) where a riak_kv_vnode may attempt to PUT an object with empty contents.  This will now check for this case regardless of the allow_mult setting, and prompt a PUT failure without crashing the vnode.  

- Tictac AAE will now, as with standard AAE, exchange between primary vnodes only for a partition (and not backfill fallbacks).  This change [can be reversed by configuration](https://github.com/basho/riak_kv/blob/riak_kv-2.9.0p5/priv/riak_kv.schema#L102-L109), and this also helps with an issue with [delayed handoff due to Tictac AAE](https://github.com/basho/riak_kv/issues/1706).

- A [change](https://github.com/basho/riak_kv/pull/1712) to allow the management via `riak attach` of the tokens used to ensure that the AAE database is not flooded due to relative under-performance of this store when compared to the vnode store.  This allows for admin activities (like coordinated rebuilds) to be managed free of lock issues related to token depletion.  This is partial mitigation for a broader [issue](https://github.com/basho/riak/issues/981), and the change also includes improved monitoring of the time it takes to clear trees during the rebuild process to help further investigate the underlying cause of these issues.

- A [refactoring of the code](https://github.com/basho/riak_kv/pull/1710) used when managing a GET request with HEAD and GET responses interspersed. This is a refactor to improve readability, dialyzer support and also enhance the predictability of behaviour under certain race conditions.  There is no known issue resolved by this change.

- An uplift to the leveled version to add in an extra log (on cache effectiveness) and resolve an intermittent test failure.

It is recommended that any 2.9.0 installations be upgraded to include this path, although if Tictac AAE is not used there is no immediate urgency to making the change.


# Riak KV 2.9.0 Release Notes - Patch 3

An [issue](https://github.com/martinsumner/leveled/issues/287) was discovered in leveled, whereby following a restart of Riak and a workload of fetch requests, the backend demanded excess amounts of binary heap references.  Underlying was an issue with the use of sub-binary references during the lazy load of slot header information after a SST file process restart.  This has been resolved, and with [greater control added](https://github.com/martinsumner/leveled/blob/0.9.18/priv/leveled.schema#L86-L93) to force the ledger contents into the page cache at startup.

A further [issue](https://github.com/martinsumner/leveled/issues/289) was discovered in long-running pre-production tests whereby leveled journal compaction could enter into a loop where it would perform compaction work, that failed to release space.  This has been resolved, and some further safety checks added to ensure that memory usage does not grow excessively during the comapction process.  As part of this change, an additional [configurable limit](https://github.com/martinsumner/leveled/blob/0.9.18/priv/leveled.schema#L75-L84) has been added on the number of objects in a leveled journal (CDB) file - now a file will be considered full when it hits either the space limit (previous behaviour) or the object limit.

The issues resolved in this patch impact only the use of leveled backend, either directly or via the use of Tictac AAE.


# Riak KV 2.9.0 Release Notes - Patch 2

An [issue](https://github.com/martinsumner/leveled/issues/285) with leveled holding references to binaries what could cause severe memory depletion, when a consecutive series of very large objects are received by a vnode.


# Riak KV 2.9.0 Release Notes - Patch 1

An [issue](https://github.com/basho/riak_kv/issues/1699) was discovered whereby leveled would leak file descriptors under heavy write pressure (e.g. handoffs).


# Riak KV 2.9.0 Release Notes

See [here for notes on 2.9.0](doc/Release%202.9%20Series%20-%20Overview.md)


# Riak KV 2.2.5 Release Notes

> This release is dedicated to the memory of Andy Gross. Thank you and RIP.

## Overview

This is the first full community release of Riak, post-Basho's
collapse into bankruptcy. A lot has happened, in particular [bet365](https://twitter.com/bet365Tech) bought Basho's
assets and donated the code to the community. They kept the Basho
website running, the documents site, the mailing list (after [TI Tokyo](https://www.tiot.jp/)
had helpfully mirrored the docs in the interim), and have done a huge amount to
provide continuity to the community.

The development work on this release of Riak has received significant
funding from [NHS Digital](https://twitter.com/NHSDigital), who depend on Riak for Spine II, and other
critical services. Thanks also to [ESL](https://twitter.com/ErlangSolutions), [TI Tokyo](https://www.tiot.jp/), and all the other
individuals and organisations involved.

This release of Riak is based on the last known-good release of Riak,
riak-2.2.3. There is good work in the `develop` branches of many Basho
repos, but since much of it was unfinished, unreleased, untested, or
just status-unknown, we decided as a community to go forward based on
riak-2.2.3.

This is the first release with open source multi-data-centre
replication. The rest of the changes are fixes ([riak-core claim](#core-claim-fixes),
repl), new features ([gsets](#gsets), [participate in coverage](#participate-in-2i), [node-confirms](#node-confirms)),
and [fixes to tests](#developer-improvements) and the build/development process.

[Improvements](#improvements)

[Known Issues](#known-issues) - please read **before upgrading** from a previous Riak release

[Log of Changes](#change-log-for-this-release)

[Previous Release Notes](RELEASE-NOTES-2_2_4.md)

## Improvements

#### Multi Datacentre Replication

Previously a paid for enterprise addition to Riak as part of the Riak
EE product, this release includes Multi-Datacentre Replication
(MDC). There is no longer a Riak EE product. All is now Open
Source. Please consult the existing documentation for
[MDC](http://docs.basho.com/riak/kv/2.2.3/configuring/v3-multi-datacenter/). Again,
many thanks to bet365 Technology for this addition. See also
[Known Issues](#known-issues) below.

#### Core Claim Fixes

Prior to this release, in some scenarios, multiple partitions from the
same preflist could be stored on the same node, potentially leading to
data loss. [This write up](https://github.com/basho/riak_core/blob/c9c924ef006af1121b7eec04c7e1eefe54f4cf26/docs/claim-fixes.md)
explains the fixes in detail, and links to
[another post](https://github.com/infinityworks/riak_core/blob/ada7030a2b2c3463d6584f1d8b20e2c4bc5ac3d8/docs/ring_claim.md)
that gives a deep examination of riak-core-ring and the issues fixed
in this release.

#### Node Confirms

This feature adds a new bucket property, and write-option of
`node_confirms`. Unlike `w` and `pw` that are tunables for
consistency, `node_confirms` is a tunable for durability. When
operating in a failure state, Riak will store replicas in fallback
vnodes, and in some case multiple fallbacks may be on the same
physical node. `node_confirms` is an option that specifies how many
distinct physical nodes must acknowledge a write for it to be
considered successful. There is a
[detailed write up here](https://github.com/ramensen/riak_kv/blob/30b0e50374196d9a8cfef37871955a5f5b2bb472/docs/Node-Diversity.md),
and more in the documentation.

#### Participate In 2i

This feature was added to bring greater consistency to 2i query
results. When a node has just been joined to a riak cluster it may not
have any, or at least up-to-date, data. However the joined node is
immediately in the ring and able to take part in coverage queries,
which can lead to incomplete results. This change adds an operator
flag to a node's configuration that will exclude it from coverage
plans. When all transfers are complete, the operator can remove the
flag. See documentation for more details.

#### GSets

This release adds another Riak Data Type, the GSet CRDT. The GSet is a
grow only set, and has simpler semantics and better merge performance
than the existing Riak Set. See documentation for details.

#### Developer Improvements

The tests didn't pass. Now they do. More details
[here](https://github.com/russelldb/russelldb.github.io/blob/b228eacd4fd3246b4eb7f8d0b98c6bed747e2514/make_test.md)

## Known Issues

#### Advanced.config changes

With the inclusion of Multi-Datacentre Replication in riak-2.2.5 there
are additional `advanced.config` parameters. If you have an existing
`advanced.config` you must merge it with the new one from the install
of riak-2.2.5. Some package installs will simply replace the old with
new (e.g. .deb), others may leave the old file unchanged. YOU MUST
make sure that the `advanced.config` contains valid `riak_repl`
entries.

Example default entries to add to your existing advanced.config:

```
{riak_core,
  [
   {cluster_mgr, {"0.0.0.0", 9080 } }
  ]},
 {riak_repl,
  [
   {data_root, "/var/lib/riak/riak_repl/"},
   {max_fssource_cluster, 5},
   {max_fssource_node, 1},
   {max_fssink_node, 1},
   {fullsync_on_connect, true},
   {fullsync_interval, 30},
   {rtq_max_bytes, 104857600},
   {proxy_get, disabled},
   {rt_heartbeat_interval, 15},
   {rt_heartbeat_timeout, 15},
   {fullsync_use_background_manager, true}
  ]},
```

Read more about configuring
[MDC](http://docs.basho.com/riak/kv/2.2.3/configuring/v3-multi-datacenter/)
replication.

More details about the issue can be found in riak\_repl/782: [2.2.5 - \[enoent\] - riak_repl couldn't create log dir
"data/riak_repl/logs"](https://github.com/basho/riak/issues/940)

## Change Log for This Release

* riak_pipe/113: [Some flappy test failure fixes](https://github.com/basho/riak_pipe/pull/113)
* riak_kv/1657: [Intermittent test failure fixes](https://github.com/basho/riak_kv/pull/1657)
* riak_kv/1658: [ Move schedule_timeout to execute in put_fsm](https://github.com/basho/riak_kv/pull/1658)
* riak_kv/1663: [Add bucket property `node_confirms` for physical diversity](https://github.com/basho/riak_kv/pull/1663)
* riak_kv/1664: [Add  option 'participate_in_2i_coverage' with default 'enabled'](https://github.com/basho/riak_kv/pull/1664)
* riak_kv/1665: [enable gset support](https://github.com/basho/riak_kv/pull/1665)
* riak_kv/1666: [Fix schema paths for make test](https://github.com/basho/riak_kv/pull/1666)
* eleveldb/243: [Add a 10% fuzz factor to the resident memory calc (intermittent test failure "fixes")](https://github.com/basho/eleveldb/pull/243)
* riak_core/911: [Fix brops intermittent test failures](https://github.com/basho/riak_core/pull/911)
* riak_core/913: [ Fix claim tail violations and unbalanced rings](https://github.com/basho/riak_core/pull/913)
* riak_core/915: [Add `node_confirms` default bucket props](https://github.com/basho/riak_core/pull/915)
* riak_core/917: [Add participate_in_2i_coverage riak option](https://github.com/basho/riak_core/pull/917)
* sidejob/18: [Address some intermittent test failures](https://github.com/basho/sidejob/pull/18)
* riak_pb/228: [Add `node_confirms` option to write messages](https://github.com/basho/riak_pb/pull/228)
* riak_pb/229: [add gsets support](https://github.com/basho/riak_pb/pull/229)
* basho_stats/13: [Non-deterministic test needs a little ?SOMETIMES](https://github.com/basho/basho_stats/pull/13)
* basho_stats/4: [Add Makefile](https://github.com/basho/basho_stats/pull/4)
* exometer_core/17: [Fix failing test with correct tuple entry](https://github.com/basho/exometer_core/pull/17)
* yokozuna/741: [Fix broken eqc test](https://github.com/basho/yokozuna/pull/741)
* yokozuna/746: [remove -XX:+UseStringCache](https://github.com/basho/yokozuna/pull/746)
* yokozuna/747: [Remove jvm directive from test too](https://github.com/basho/yokozuna/pull/747)
* clique/81: [Fix failing test on some environments](https://github.com/basho/clique/pull/81)
* riak_dt/121: [doc related fix & explanation](https://github.com/basho/riak_dt/pull/121)
* riak_dt/127: [bring develop-2.2 up-to-date with develop](https://github.com/basho/riak_dt/pull/127)
* riak_dt/129: [Add gset support](https://github.com/basho/riak_dt/pull/129)
* riak_dt/135: [Fix `equal/2` bug around unordered dict usage](https://github.com/basho/riak_dt/pull/135)
* riak_repl/776: [Fix bug when passing utc timestamps into httpd_util:rfc1123/1.](https://github.com/basho/riak_repl/pull/776)
* riak_repl/777: [Fix badarg in binary construction for args to ebloom](https://github.com/basho/riak_repl/pull/777)
* riak_repl/779: [Sticking plaster fix for basho/riak_repl#772](https://github.com/basho/riak_repl/pull/779)
* riak_repl/780: [Fix sometime failing test](https://github.com/basho/riak_repl/pull/780)
* riak_repl/782: [Change ETS queue table permissions to protected](https://github.com/basho/riak_repl/pull/782)

## Previous Release NOTES

[Full history of Riak 2.0+ release notes](RELEASE-NOTES-2_2_4.md)
