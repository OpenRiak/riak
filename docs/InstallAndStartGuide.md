---
title: Install and Start
nav_order: 2
layout : default
---

# Riak KV - Install and Start

## Installation

Riak is built on the Erlang/OTP platform.  Only the even numbered major versions of Erlang/OTP are fully tested for operating Riak.  For each major version of Riak, the major version is initially released supporting two major OTP versions, where the lower version is common with the previous Riak major release.  Once a Riak major release has been in production for 12 months, future minor releases may only support the higher of the two Erlang/OTP versions.

The mappings for current and planned releases are:

|Riak Release| Supported OTP Version
|:------------|:------------:|
| Riak KV 3.0.16 | OTP 22.3 |
| Riak KV 3.2.6 | OTP 24.3 |
| Riak KV 3.4.0 | OTP 24.3 or OTP 26.2 (recommended) |
| Riak KV 4.0 (planned) | OTP 26.2 or OTP 28.3 |

Any updates to this mappings will be announced on the [Riak discussion forum](https://github.com/orgs/OpenRiak/discussions).

Riak can be potentially built on most Unix-flavour systems, including OSX for development machines; but is primarily run in production on up-to-date versions of CentOS or Ubuntu.

### Install Erlang/OTP

Installation guides for different OTP versions are available via erlang.org:

- [OTP 24 Installation Guide](https://www.erlang.org/docs/24/installation_guide/install);
- [OTP 26 Installation Guide](https://www.erlang.org/docs/26/installation_guide/install).

For convenience [`kerl` may be used to simplify the installation of Erlang/OTP](https://github.com/kerl/kerl).

Some points to note when installing Erlang:

- If using OTP 24 take note of [CVE-2022-37026](https://nvd.nist.gov/vuln/detail/CVE-2022-37026).
- Of the optional dependencies for OTP, only OpenSSL is required for Riak.
- The OpenSSL 3.0 integration in OTP 24 is not currently considered to be production-ready and stable.
- If using Riak KV 3.0.16 and OTP 22.3, Riak does not support Erlang/OTP running in [HIPE mode](https://www.erlang.org/docs/22/man/hipe_app).  HIPE is retired as of OTP 24.
- There are significant performance advantages in running Riak on OTP 26, when compared with OTP 24.3.
- The Erlang/OTP team are only committed to fixing issues in the three most recent major versions of Erlang.  Although Erlang 24.3 is mature and very stable, migrating forward to a Riak release running on a presently supported Erlang version is recommended.
- It is not possible to [migrate directly using a rolling restart](./OperationsAndTroubleshootingGuide.md#upgrading-a-node) from Riak KV 3.0 to Riak KV 3.4 due to breaking changes in the Erlang distribution protocol.  Migrating directly between these versions with zero down-time can only be managed using [the cluster migration strategy](./ReplicationGuide.md#migrating-a-cluster).

### Download Riak

Riak is [available to clone on GitHub](https://github.com/OpenRiak/riak).

Each major release has an associated branch which represents current development activity.  For Riak 3.2 this is `openriak-3.2`, For Riak 3.4 this is `openriak-3.4`.  Building from these branches may contain unreleased changes.

[Tagged versions for recent releases are available](https://github.com/OpenRiak/riak/releases), and described in the [release notes](https://github.com/OpenRiak/riak/blob/openriak-3.4/RELEASE-NOTES.md).  [Earlier releases are also available](https://github.com/OpenRiak/riak-forked/releases); and for the pre-OpenRiak era, [releases can be found on the basho github site](https://github.com/basho/riak/releases).

{: .note }
> Tagged releases contain a `rebar.lock` file which ensures all major dependencies are fetched from the precise commit made at the point of release.

### Make Riak

There are three basic approaches to building Riak once the repository has been cloned, a tag or branch has been selected, and the dependencies have been installed: a local release, a local cluster or generating a package.

#### Local release

To create a local release, run `make rel`.  This will build a release of Riak in the `rel/riak` folder within the repository clone.  This can be configured, started and joined into a cluster as with any Riak node.

#### Local cluster

To create a local development cluster, which is ideal for experimenting with Riak, run `make devclean; make devrel`.  This will clean and rebuild a group of 8 Riak instances in the `dev/dev<n>` folder within the repository clone.

#### Generating a package

To generate a package, running `make package` will build a package for the current local platform.  This can then be deployed to another server of that type using the standard package management tool (e.g. `dpkg` on debian systems).

- Running `make package` will require the local machine to have appropriate build tools installed;
- The `make package` process will output WARNING level errors during the `make package` process;
- The underlying information used as part of `make package` can be in the [`pkg` section](https://github.com/OpenRiak/riak/tree/openriak-3.4/rel/pkg) of the Riak repository.

### Using pre-built packages

{: .note }
> The OpenRiak community currently provides Riak as **source-only**, and does not directly provide pre-built packages of Riak.

Organisations within the OpenRiak community do offer pre-built packages as part of their service offering, and these are [freely available](https://files.tiot.jp/riak/).  The use of pre-built packages is _not_ recommended by the OpenRiak community where end-to-end assurance of the software supply-chain is required.  The building of packages in a customer-specific secure environment is the preferred approach.

## Starting Riak

### Starting Riak by Make Method

Starting Riak changes depending on how Riak was made - a [local release](#local-release) or [local development cluster](#local-cluster), or through [package deployment](#package-deployment).  In all cases Riak is released using [the relx release generator](https://rebar3.org/docs/deployment/releases/), and inherits the control commands from the `relx` extended start script; but the location and method for accessing that script will vary.

#### Local Release or Cluster

For locally deployed instances (i.e. via `make rel` for a single node or `make devrel` for a development cluster), nodes can be controlled using the `bin/riak` script:

```console
bin/riak daemon
bin/riak ping
bin/riak stop
``` 

The location of the `bin` directory will depend on whether `make rel` or `make devrel` has been used to create the Riak release.  By default `make rel` will copy the release into the `rel/riak` folder in the base folder to which Riak was cloned - so the control script can be found at `rel/riak/bin/riak`.  For clusters generated with `make devrel`, the make process will create `n` multiple nodes under `dev/dev{n}/riak` in the base folder.  Those nodes are independent until [they are joined into a cluster](./BuildAndScaleClusterGuide.md#forming-and-expanding-a-riak-cluster).

{: .note }
> Under `riak`, there should be `bin`, `data`, `log` and `etc` folders.  The location of the `data` and `log` folders can be changed using the `platform.data_dir` and `platform.log_dir` in `etc/riak.conf`.

{: .warning }
> The `bin/riak start` command which was used in Riak 3.0 and earlier releases is now deprecated.
>
> From Riak 3.2.0 use `daemon` to start Riak, or `foreground` to start with output redirected to `stdout`.

Help for further console activities can be found via:

```console
bin/riak --help
bin/riak admin --help
bin/riak admin cluster --help
``` 

#### Package Deployment

For instances deployed through packages, startup and shutdown should be controlled using `systemd` e.g.:

```console
service riak start
service riak ping
service riak stop
```

Help for further console activities can be found by using the standard `riak` script e.g. `sudo riak admin --help`.

{: .note }
> The default location of `bin`, `data`, `log` and `etc` folders following package deployment, should follow standard conventions for that operating system.  For example, on Ubuntu the configuration can be found in `/etc/riak/riak.conf`, and other paths are described within that file.

#### Setting ulimit

{: .warning }
> Running Riak may require a much higher `ulimit` than the default set by the Operating System.

A `ulimit` of 100000 will be acceptable for small-scale non-production systems, but larger limits will be needed for full-scale production systems.  When Riak is installed as a package, then the default limit is increased using the `LimitNOFILE` file option within the systemd service definition.  For local deployments, the ulimit should be modified for the user starting the riak application.

### Configuration of Riak - key riak.conf changes

Almost all configuration of Riak can be done through the `etc/riak.conf` file.  Each public configuration option should be described in that file, but there are additional `hidden` options supported for expert-advised changes.  The `riak.conf` file is built from individual schema files, and the repositories which contribute towards those schema files are listed in [the `cuttlefish` section of the `riak/rebar.config` file](https://github.com/OpenRiak/riak/blob/fd27c6933391ece65b31760cccb87b671a80f310/rebar.config#L23-L37).

Each individual schema component can be found in the `priv` folder for that repository, e.g [priv/riak_kv.schema for the riak_kv schema](https://github.com/OpenRiak/riak_kv/blob/openriak-3.4/priv/riak_kv.schema).

When starting a first cluster to experiment, the following configuration items are of particular importance:

- `ring_size`; refer to the [ring size selection in the design decisions document](./InitialDesignDecisions.md#ring-size), should be set smaller than the default for test/dev environments and larger than the default for production systems.
- `tictacaae_active`; refer to the [intra-cluster resilience in the design decisions document](./InitialDesignDecisions.md#intra-cluster-data-resilience).  Should be set to active if the active repair of deltas between vnodes is required, otherwise repair will be reactive (i.e. only once a delta has been detected on read).
- `tictacaae_storeheads`; should be enabled when using `tictacaae_active` on a leveled backend if the full scope of AAE Folds are to be used.
- `anti_entropy`; this is a deprecated anti-entropy system, and should be set to `passive` if using `tictacaae_active`.  It may be set to `active` in parallel to `tictacaae_active` to transition between the services.  The legacy anti-entropy system is quicker and more aggressive at repairing deltas, but offers less functionality and runs at a higher cost when in sync.
- `storage_backend`; refer to the [backend selection in the design decisions document](./InitialDesignDecisions.md#database-backend), but for full Riak functionality must be set to leveled.
- `read_repair_primaryonly`; will impact the behaviour in failure, by default when a standby vnode replaces a failed vnode, read repair will be triggered on every GET to populate the standby with old writes, but this will have a negative impact performance during both failure and recovery.
- `buckets.default.merge_strategy`; should always be set to `2`, and `2` will be the only supported option from Riak 4.0.
- `nodename`; a unique name for the node within the cluster.
- `platform_data_dir`; where the actual data will be stored, must be a space with sufficient capacity and throughput.
- `listener.http.internal` or `listener.pb.internal`; the IP address and port for accessing the API. It is recommended to bind this IP address to a specific interface address.  [The Query API](./QueryAPI.md) requires use of the `http` listener, and performance will differ between the `pb` and `http` transports when using [the Object API](./ObjectAPI.md).

In a `riak.conf` file, the last setting of any configuration item is the actual value used in the configuration.  Edits to the riak.conf file don't have to change the configuration in place, defaults may be overwritten by concatenating changes to the end of the file.

### Configuration of Riak - leveled backend

Compression, decompression and compaction have a potentially significant impact on performance within leveled,  and so configuration items of notable importance are:

- <span>Available from Riak 3.2.3</span>{: .label .label-green }`leveled.compression_method`; should be set to `zstd`, unless objects are sent to Riak compressed, in which case the compression method should be configured as `none`.
  - in testing `zstd` has been demonstrated to be the most efficient available option (when compared to `native` which uses zlib compression, or `lz4`).
- `leveled.ledger_compression`; if `compression_method` is set to `none`, then compression should still be enabled here e.g. set to `zstd`.
  - the ledger does not store object values, but stores the object keys and metadata in blocks by key order.
  - it is recommended to use some form of compression on the ledger, even when all values are pre-compressed.  The ledger blocks are generally highly compressible, even when the values are not. 
- `leveled.compaction_runs_perday`; refer to the [operations guide](./OperationsAndTroubleshootingGuide.md#leveled-compaction-highlow-hour) for more on leveled compaction.

There are further configurable options within the leveled backend, that can be changed within `riak.conf`.  For a comprehensive view, [refer to the leveled schema file](https://github.com/OpenRiak/leveled/blob/openriak-3.4/priv/leveled.schema).

The leveled logs are relatively verbose, when compared to log activity across Riak as a whole.  These logs can be tuned using:

- `leveled.log_level`; the info-level logs are useful for monitoring as well as troubleshooting, so careful consideration is required before moving to an alternate log level.

### Configuration of Riak - bitcask backend

For the bitcask backend, the configuration items of notable importance are:

- `bitcask.merge_policy`; refer to the [operations guide](./OperationsAndTroubleshootingGuide.md#bitcask-merge-window) for more on bitcask compaction.
- `bitcask.io_mode`; should be set to `erlang`, careful consideration is required before moving to `nif`.

There are further configurable options within the bitcask backend, that can be changed within `riak.conf`.  For a comprehensive view, [refer to the bitcask schema file](https://github.com/OpenRiak/bitcask/blob/openriak-3.4/priv/bitcask.schema).

### Configuration of Riak - Delete Mode

There are three supported [delete modes in Riak](./InitialDesignDecisions.md#deleting-data): `keep`, an interval or `immediate`.

If delete_mode is set to `keep`, every delete will be an update to a permanent tombstone that will need to be reaped at a later date (i.e. once tombstones have been securely replicated around connected clusters).  This will minimise the chance that values are resurrected through anti-entropy processes.  An interval will automate the reap process, and can be set to the number of milliseconds after the writing of the tombstone; which should be kept to less than 5 minutes.  Setting the delete mode to `immediate` will bypass the tombstone process, and delete directly without first writing a tombstone.

### Configuration of Riak - Bucket Properties

Riak objects are placed into buckets.  The configuration of the handling of buckets is managed using bucket properties.  There are two types of Buckets in Riak - non-typed buckets, and typed buckets.  Typed buckets were introduced to make it easier to expand the number of buckets that can be supported with non-default properties.  Other than for maintenance of legacy data added prior to typed buckets, typed buckets should always be used.

For help in enabling properties on typed buckets see:

```console
rel/riak/bin/riak admin bucket-type --help
```

The majority of defaults for bucket properties are configurable via `riak.conf`, for example:

- `buckets.default.n_val = 3`
- `buckets.default.merge_strategy = 2`
- `buckets.default.pw = 1`
- `buckets.default.allow_mult = true`

Configuring these defaults will impact only non-typed buckets.  So any bucket name used where no type is specified will inherit these defaults, but any typed bucket created will NOT inherit these configured defaults - typed buckets instead have fixed, pre-defined defaults.

Two pre-defined defaults changed with the introduction of typed buckets (the merge strategy aka `dvv_enabled`, and the `allow_mult` configuration).  Having this delta in behaviour is a common cause of confusion in application developers using Riak, and so it is recommended to configure your clusters to have the same default properties for non-typed buckets as with typed buckets.  This can be achieved by adding to your `riak.conf`:

- `buckets.default.merge_strategy = 2`
- `buckets.default.allow_mult = true`

As any change made to `buckets.default.*` configuration in `riak.conf` is not inherited for typed buckets, there is no way of changing the defaults for typed buckets, so the operator is required to ensure that all default properties are manually set on every type.  For example if you wish to change the default n_val to 5 - this needs to be changed in riak.conf `buckets.default.n_val = 5` but ALSO the property `{n_val, 5}` has to be added on every single bucket type created.

{: .warning }
> In general, setting bespoke bucket properties should be done using typed buckets due to the relative efficiency of the implementation with types, but changes to defaults should be considered very carefully.  Bespoke properties allow for bespoke behaviours, but bespoke behaviours add to the cognitive load of future operators.

Default changes made via riak.conf need to be set consistently across a cluster.  No bucket properties are gossipped between clusters, so properties are cluster-specific.  In general any cluster setting related to vector clocks MUST be configured consistently across replicating clusters e.g. `dvv_enabled`, `old_vclock`, `young_vclock`, `big_vclock` and `small_vclock`.  Other properties can be different between clusters. 

Some changes can be applied using GET/PUT specific parameters, which will override the default bucket property i.e. a bucket could be configured to use `{sync_on_write, one}`, but a specific PUT can override this by setting `{sync_on_write, all}`.

{: .warning }
> Although the use of GET/PUT specific parameters is supported on individual requests, it is not recommended.  Operation-specific parameters that override defaults are not logged, and can increase the operator-challenges associated with troubleshooting intermittent problems.

#### Property - dvv_enabled

In Riak 2.0 the handling of siblings was improved by the enabling of dotted [version vectors](./RiakTheoryGuide.md#version-vectors).  All buckets should use `{dvv_enabled, true}`.  The introduction of DVV did not force non-typed buckets to use DVV, and by default non-typed buckets will continue to use legacy vector clocks.

To correct this the following configuration should be added to the `riak.conf`:  `buckets.default.merge_strategy = 2`.

{: .warning }
> If vector clock sizes are approaching the `small_vclock` limit, then it is important that `{dvv_enabled, true}` before pruning is applied, or pruning may lead to unexpected siblings.

#### Property - allow_mult

The `allow_mult` bucket property has a default value of `true`, for any typed bucket, but a default value of `false` for any untyped bucket.  It is recommended to use the value of `true`.

The internal workings of Riak are identical for the two `allow_mult` settings, with the exception of the case when an unresolvable conflict is discovered in the object change history.  If `{allow_mult, true}`, all unresolvable conflicting versions are returned to the client to determine the correct version, potentially by merging the conflicting versions.  The client will then resolve existing conflicts on the next PUT. If `{allow_mult, false}` only the object with the most recent last_modified_date is returned, and conflicting versions will be discarded by Riak.

The last_modified_date is a timestamp that depends on the accuracy of the clock on the node that processed the update request.  The timestamp is recorded to a microsecond level, although it is only visible to an accuracy of one second when read via the HTTP Object API.  If conflicting versions of the same object have matching timestamps, then an arbitrary choice is made, although there is a preference for changes with values over deletions.

{: .note }
> Due to the potential use of timestamps to make comparisons when using `{allow_mult, false}`, the use of reliable time sources to co-ordinate time within and across clusters is recommended.

When using [conflict-free replicated data types](./OtherAPI.md#the-data-type-api), `{allow_mult, true}` must always be used.

Unless the non-existence of an object can be guaranteed by the application using Riak, it is recommended that applications always read before writing, and include the vector clock from the read in the write.  This ensures that even when using `{allow_mult, false}`, fallback to time comparison is kept to a minimum.

#### Property - last_write_wins

The `last_write_wins` bucket property has a default value of `false`.  It should only ever be changed when the `allow_mult` bucket property is set to `false`.

In general, the default of `false` should be used, even when `{allow_mult, false}` is set.  Setting `{last_write_wins, true}` changes the vnode-level behaviour on PUT so that an incoming write is assumed to be superior to an existing write, without checking the change history of the existing object.  Internally within Riak, the actual order with which PUTs are applied is non-deterministic, and there are many situations (replication, anti-entropy, handoffs) where old PUTs may be received after new PUTs.  In these cases setting `{last_write_wins, true}` may have unexpected consequences

There is a small performance advantage from setting `{last_write_wins, true}` if, and only if: the bitcask backend is used, and objects are being updated and not simply inserted, and there is no use of TicTac AAE.

{: .note }
> It is recommended that `{last_write_wins, true}` only be used for once-only PUTs (of immutable objects) into the bitcask backend, if and only if, the consequences of out-of-order writes have been fully considered.

#### Property - n_val

The `n_val` bucket property has a default value of `3`, and can be set to any positive integer: though only values of `1`, `3` and `5` are commonly used.

Setting distinct `n_val`s on a per-bucket basis is not recommended, it is preferable to have a consistent `n_val` across a cluster.  This is because:

- related configuration settings `target_n_val` and `target_location_n_val` are cluster-wide and not bucket-specific;
- the scope of the anti-entropy system grows with every unique n_val;
- nextgenrepl full-sync configuration is specific to each n_val, having multiple nvals requires different nodes in the cluster to reconcile for different nvals.

The value of `1` is sometimes used in read-only clusters, to reduce storage costs in clusters used only for backups or offline-reporting.  The value of `5` may sometimes be used in very large clusters in terms of node count; either as the probability of concurrent failures requires higher redundancy, or because there is a need to improve the efficiency of secondary index queries.

{: .warning }
> Changing an n_val on a bucket which already contains data will have unexpected and untested consequences, especially when contracting the n_val.

#### Property - node_confirms

The `node_confirms` bucket property has a default value of `0`, and may be set to any non-negative integer less than or equal to the `n_val`.  The purpose of `node_confirms` is to offer a guarantee that the data is available on multiple machines, for example setting node_confirms to 2 will guarantee that at least two machines have the data - and the risk of the data being lost can be considered accordingly.

{: .highlight }
> By default, a request will be confirmed when the data is in a quorum of vnodes.  However, if multiple nodes have failed in the cluster, the data may still only be on one node. With `node_confirms` the request is only confirmed once the required physical diversity is supported, not just the logical diversity.

The `node_confirms` property is applied on both reads and writes.  The parameter is also applied on reads so that an application can understand on read that a previous put has indeed reached the required level of diversity.  If a `PUT` request fails due to `node_confirms`, a successful `GET` is sufficient to confirm that through eventual consistency the required diversity has been achieved.

#### Property - sync_on_write
{: .d-inline-block }

Available from Riak 3.0.8
{: .label .label-green }

The `sync_on_write` bucket property has a default value of `backend`, and allows for more flexible guarantees about data being flushed to disk.  By default, Riak backends will confirm a PUT once a file write has been completed, but that write may only be resident in memory in the file-system page cache; so at this stage the data is not safe (for example if a power failure simultaneously killed multiple nodes).  Riak backends can be configured to flush all writes to disk, but this has a significant impact on throughput, both in normal operation (each PUT prompts n_val flushes per cluster) and also when managing transfers between nodes.

The `sync_on_write` bucket property can be configured to `backend` (default - revert back to original behaviour, and use only the backend setting), `one` or `all`.  It is assumed when using `sync_on_write` the backend will be configured not to flush to disk on every write.  In this case a write to a bucket with `backend` may be resident in memory on all nodes after the PUT is confirmed to the application client.  If `all` is set, all writes that have been confirmed will also have been flushed (by default 2 of 3 writes must be confirmed before the client receives a positive response).  If `one` is used, the first location to process the PUT will flush to disk, where other locations are allowed to hold it in memory in the file system page cache.

The `sync_on_write` property is used only for PUTs via the API.  Internal PUTs (e.g. for transfers) will ignore the property and use the backend configuration, and so will not carry the overhead of flushing.

It is recommended not to use backend sync configuration, and instead control flushing only through use of this bucket property.

If replicating between clusters and `one` is used as the `sync_on_write` bucket property, then the cluster that receives the PUT from the application will flush to disk on one node - but all clusters receiving the PUT via replication will not be required to flush to disk on any node.  The properties of `backend` or `all` are treated equally in source and sink clusters.

#### Property - aae_tree_exclude
{: .d-inline-block }

Available from Riak 3.4.0
{: .label .label-purple }

The `aae_tree_exclude` bucket property has a default value of `false` and allows for flexibility when reconciling between clusters using nextgenrepl full-sync.  In general with Riak nextgenrepl it is assumed that clusters aim to contain the same data.  It is possible to replicate specific buckets between specific sources, and also possible to reconcile only individual buckets between clusters - but per-bucket reconciliation is not as efficient as full-cluster reconciliation.  The efficiency of full cluster reconciliation is based on the use of cached and mergeable [AAE (active anti-entropy) merkle trees](./RiakTheoryGuide.md#anti-entropy) that represent all the data in the store.

The purpose of `aae_tree_exclude` is to not include the bucket in the cached tree, so that the bucket isn't considered in any all-data reconciliation jobs.  For example, this may help when:

- a subset of buckets are not replicated between clusters;
- a bucket is using a backend TTL within one of the clusters (a cached tree cannot coordinate changes with backend stores which implement auto-expiry - so cached trees may prompt false AAE workloads when a backend TTL is used).

If a bucket is configured to `{aae_tree_exclude, true}`, the keys are still visible to aae_folds.  If using parallel-mode Tictac AAE, modification will still impact the parallel keystore.

The preferred long-term strategy for temporary objects is to use the eraser and reaper processes to garbage collect objects, rather than relying on backend TTL.  However when migrating from a multi-backend store with TTL-based backends, the migration should be easier if: those temporary buckets are excluded from aae trees, are replicated separately using range_repl, and reconciled using bucket-specific aae full-sync jobs.

The `aae_tree_exclude` bucket property may be cached by processes within a cluster, so changing the property will not have immediate effect.  A change to the `aae_tree_exclude` property should be coordinated with a [rolling restart](./OperationsAndTroubleshootingGuide.md#rolling-restart).

#### Property - small_vclock

The `small_vclock` bucket property has a default value of `50`, and that sets the size of version vectors before pruning will take place. Version vectors will initially tend to be the size of the total of all nvals in all clusters accepting writes for that value (two clusters with n_val of 3 will lead to version vectors of size 6 if objects are subject to sufficient updates).  However, when nodes are replaced, and when clusters are expanded or contracted, new potential vnodes are generated which may lead to the version vector expanding.

It is not recommended to change the `small_vclock`, unless specific problems are seen with objects reaching the pruning limit - and in this case increasing the size may be used as a workaround to those issues.  Any change must be reflected in all connected clusters.

Other vclock settings - `old_vclock`, `young_vclock`, `big_vclock` - should not be changed from defaults without careful analysis of the vclock pruning code. 

#### Property - notfound_ok

The `notfound_ok` bucket property has a default value of `true`, and this means when calculating the `r` value of a read, a response from an individual vnode of `not_found` will count as a valid read, and so will count towards quorum being reached.

It is recommended to set `notfound_ok` to `false`, so that a vnode with a missing value will not count towards quorum, especially when the application never expects to read keys that are not present, and so `not_found` is definitively a failure.

#### Property - pr and pw

The `pr` and `pw` bucket properties default to `0`, and are used to require primary vnodes to be involved in reads and writes.  Setting higher values may prevent writing to minority partitions, however when `{n_val, 3}` this will probably lead to intermittent failures when only two nodes fail in a cluster.  As clusters grow the probability of two concurrent failures will increase significantly.

Although configuring `pr`/`pw` to values greater than 1 may be used to indirectly set stronger data reliability guarantees, or to adjust consistency guarantees - there are better ways of achieving this in Riak, which have fewer negative side effects.  Consider using [`node_confirms`](#property---node_confirms) or [`sync_on_write`](#property---sync_on_write) to manage data reliability.  The use of [token-based conditional PUTs](./ObjectAPI.md#conditional-requests) is the preferred approach, rather than `pr`/`pw` adjustments for tuning consistency.

{: .note }
> It is normally best practice to configure either `{pr, 1}` or `{notfound_ok, false}`, rather than rely on defaults.

If both `pr` and `notfound_ok` are left at defaults, there is a potential issue when at least two nodes have failed and for some objects 2 of the 3 vnodes are unpopulated fallbacks.  In this case, without changing defaults, the two unpopulated fallback vnodes can return `not_found` and the GET request can achieve quorum and return a false `not_found` to the client.  By configuring either `{pr, 1}` or `{notfound_ok, false}`, when there is only one populated/primary vnode, the GET request must wait for this vnode to respond.

As a consequence though, in the case where there are at least three node failures, and for an unfortunate preflist all three primaries are down - this will then lead to failing requests, though this may be preferable to false `not_found` responses.

#### Property - backend

If using the multi-backend, the bucket property `backend` can be used to map bucket types to different backends.

#### Property - General read/write parameters

There are read and write parameters that can be used to control the balance between consistency, performance and availability - `r`, `w`, `dw`, `rw`, `basic_quorum`, `sloppy_quorum`.  Read and write parameters default to quorum, and maintaining this default is preferred.  Any attempt to re-configure to improve speed of response to clients, will increase the risk of overloading vnode mailboxes and causing unnecessary failures.

There may be rare circumstances where a cluster is repeatedly suffering `vnode mailbox overload` error responses, because individual vnodes are developing backlog queues larger than their peers in the preflist.  Setting `r` and `w` values to the configured `n_val` can be used as a workaround to temporarily alleviate these scenarios, by slowing the application down to the pace of the slowest vnode.  However, in the long term, the preferred solution to overload scenarios is to address the root cause of these deltas between vnode busyness.
