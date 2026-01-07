---
title: Other APIs
nav_order: 6
layout : default
---

# Riak KV - Other APIs

The majority of work within Riak KV can be done using the [Object API](./ObjectAPI.md), and the [Query API](./QueryAPI.md).  There are though additional APIs, with specific purposes:

- [The AAE Fold API](#aae-fold-api)
- [The Fetch API used to access replication queues](#the-fetch-api)
- [The Data Type API](#the-data-type-api)
- [The Map/Reduce API](#the-mapreduce-api)
- [The List API](#the-list-api)
- [The Strong Consistency API](#strong-consistency-api)
- [The Write Once Path API](#write-once-path-api)

## AAE Fold API

The AAE Fold API requires the configuration of `tictacaae_active = active`, otherwise folds will fail.  When using a single leveled backend, this should use the native keystore within leveled.

When using any other backend or multi-backend this will require an additional parallel keystore, which may have an impact on the achievable PUT throughput, and the memory used by Riak.  The use of a parallel backend also requires periodic keystore rebuilds, to ensure that the keystore correctly represents the content in the backend store.

{: .note }
> When using parallel mode, the parallel store must be configured with `tictacaae_storeheads = enabled` to use the full functionality of AAE Folds.

The AAE Fold API:

- Supports [more than ten different fold types](#supported-fold-types);
- [Are throttled to minimise the impact on other cluster operations, and have query options that may improve efficiency](#performance-and-efficiency).

The AAE Fold API has four potential interfaces:

- [AAE Folds via the Command Line](#aae-folds-via-the-command-line);
- [AAE Folds via remote_console](#aae-folds-via-the-remote-console); 
- [AAE Folds via HTTP](#aae-folds-via-http);
- [AAE Folds via protocol buffers](#aae-folds-via-pb).

### Supported fold types

All APIs support the following types of fold:

#### merge_root_nval

For a given n_val merge the root of a the merkle tree across all partitions, given a cluster-wide view of the tree root:

- Relatively fast, as uses cached trees;
- Intended for internal use within inter-cluster reconciliation.

#### merge_branch_nval

For a given `n_val` and list of `branch_id`'s (normally deltas discovered after comparing tree roots), merge the branches across all partitions, to give a cluster wide view of those branches within the merkle tree:

- Relatively fast, as uses cached trees;
- intended for internal use within inter_cluster reconciliation.

#### fetch_clocks_nval

For a given set of segment IDs return all the keys and clocks within those segments, potentially constrained by a modified date range.

- If a full-sync manager process detects a false delta, it will temporarily set enable the `aae_fetchclocks_repair` option, and this will cause this query to repair the cached tree for the given segment IDs, as well as collect the results to return.
  - It is possible to force this repair option via configuration or environment variable change.
- Uses the AF3 queue when running node worker pools in `dscp` mode.
  - These queries will bypass the pool, running immediately, when repair is required.

#### merge_tree_range

Outputs a full merkle tree representing the overall cluster state for a given bucket.

- Relatively slow compared to `_nval` equivalent queries, as no cached trees can be used; requiring a fold over the actual keys to calculate the tree.
- Setting filters is recommended to speed up the query (unless buckets are small).

#### fetch_clocks_range

Equivalent to fetch_clocks_nval but with Bucket and KeyRange constraints.

- Unlike fetch_clocks_nval, this will never result in a repair of cached trees.
- Uses the AF3 queue when running node worker pools in `dscp` mode.

#### repl_keys_range

Used to replicate a range of keys to another cluster (or indeed any consumer of a given replication queue).  To be used when seeding new clusters, or if there is a known delta that can be expressed and resolved more quickly by this mechanism rather than by waiting for inter-cluster reconciliation to auto-heal.

- When adding to the replication queue, will be added with a lower priority when compared to real-time replication.
- Each replication queue has a small in-memory part but a large on-disk part.  The size of the on-disk component is controlled in `riak.conf` via `replrtq_overflow_limit`.
- Uses the AF4 queue when running node worker pools in `dscp` mode.

#### repair_keys_range
{: .d-inline-block }

Available from Riak 3.0.8
{: .label .label-green }

Used to prompt read repair in a bucket, to fix an entropy problem within the cluster, potentially limited by key range or modified date range.

- Uses the `riak_kv_reader` queue, and consumption from that queue is constrained by having a single process per node handling queued repairs.
- The reader queue has a small in-memory part but a large on-disk part.  The `reader_overflow_limit` is not configurable via `riak.conf`.
- Uses the AF4 queue when running node worker pools in `dscp` mode.

#### find_keys

Outputs a list of keys in the bucket where the object has either a sibling_count or a size (in bytes) that exceeds a certain threshold, potentially limited by key range or modified date range.

- Commonly used as an operational query (e.g. "find all objects modified in the past 24 hours with more than one sibling").
- May also be used to list keys, where using a `$key` query is not supported.  It is much slower (but potentially safer) than `$key` query due to the constraints of the [node_worker_pools](#node-worker-pools).
- Uses the AF4 queue when running node worker pools in `dscp` mode.

#### find_tombs

Outputs a list of tombstone keys (deleted keys where the tombstone has not been reaped) in the bucket, potentially limited by key range or modified date range.

- Uses the AF4 queue when running node worker pools in `dscp` mode.

#### erase_keys

Prompts for a list of matching keys in the bucket to be erased via the `riak_kv_eraser`, potentially limited by key range or modified date range.

- Uses the `riak_kv_eraser` queue, and consumption from that queue is constrained by having a single process per node handling queued repairs, and by the configuration of the `tombstone_pause` within riak.conf.
- The queue has a small in-memory part but a large on-disk part.  The size of the on-disk component is controlled in `riak.conf` via `eraser_overflow_limit`.
- Uses the AF4 queue when running node worker pools in `dscp` mode.

#### reap_tombs

Prompts for a list of matching tombstones in the bucket to be erased via the `riak_kv_reaper`, potentially limited by key range or modified date range.

- Uses the `riak_kv_reaper` queue, and consumption from that queue is constrained by having a single process per node handling queued repairs, and by the configuration of the `tombstone_pause` within riak.conf.
- The queue has a small in-memory part but a large on-disk part.  The size of the on-disk component is controlled in `riak.conf` via `reaper_overflow_limit`.
- Uses the AF4 queue when running node worker pools in `dscp` mode.

#### object_stats

Returns a summary of stats for objects within the bucket, potentially limited by key range or modified date range.

- Returns an output like `[{total_count, 1000}, {total_size, 1000000},  {sizes, [{1, 800}, {2, 180}, {3, 20}]},  {siblings, [{1, 1000}]}]`.
  - The sizes are the count of objects by order of magnitude in bytes (e.g. 1 is 10 -> 100 bytes, 2 is 100 -> 1000 bytes etc).
  - The siblings are the count of objects with that count of siblings.
- Uses the AF4 queue when running node worker pools in `dscp` mode.

#### list_buckets

Returns a list of buckets, assuming the given n_val.

- The list may be incomplete if the passed n_val is greater than the configured n_val of some buckets.
- will only return buckets that contain objects.
- Uses a skipping cursor in both `native` and the `leveled_ko` type of parallel store, so that the fold is much more efficient than folding over all keys.
- Uses the AF4 queue when running node worker pools in `dscp` mode.

### Performance and Efficiency

The AAE Fold implementation has similarities to [the Query API](./QueryAPI.md#performance-and-efficiency).  The sequence of operations for the fold is:

- On the local node that received the request, a query server is started to orchestrate the fold across the cluster;
  - In Riak 3.4 the query server has a different underlying implementation to the query server used in the Query API; but this may change to use a common implementation in a future release.
- Folds are run over a covering set of vnodes, i.e. either `RingSize div n_val` or `(RingSize div n_val) + 1`.
- Folds will first take a snapshot of each vnode, before running each vnode query against the snapshot.
  - When running in parallel mode, this will be a snapshot of the parallel keystore, in native mode this will be a snapshot of the leveled ledger (the native keystore).
  - The snapshot requests will need to wait in the vnode queue, but operations on the snapshot are not constrained by the queue.
  - The snapshots have a timeout, and a fold that runs after the timeout is likely to fail;
    - On native stores the timeout for AAE folds is configured via `leveled.snapshot_timeout_long`.  On parallel stores it defaults to 2 days.
- The folds will then scan across the keys and metadata using the filters provided, accumulate results, and return the results to the controlling node for the query once complete.
  - Unlike the Query API, there is no sending of partial results, and waiting for acknowledgement.
  - AAE folds will continue to run, even when the query server for the request has timed out.
  - If a queue-type accumulator is used, the results are sent to the queue in batches during the fold, and the final result returned to the query server is just a count.
- Once all vnode folds have completed and sent results, the query server will combine the results and return the final result-set back to the requester.

#### Node worker pools

Riak API requests are generally not subject to constraints on the resources they use.  If there exists contention over available CPU cores within a busy cluster, the contention is managed by the Erlang scheduler, and the database backends are designed to degrade gradually - to slow smoothly as available resources are restricted.

In contrast, the AAE Fold API has specific constraints on throughput, governed by the node worker pools.  These pools are defined to constrain concurrency for operational queries, to provide an upper limit on how many CPU cores may be used by different classes of operational work.  There is no guarantee that worker pools will be able to use their limit - use of each core is still managed fairly by the erlang scheduler for that core.

The node worker pool can be configured via the `worker_pool_strategy` in riak.conf, and can be set to three different modes:

- `none`; do not use node worker pools.
  - aae_folds and other operational work will be fairly scheduled by the erlang scheduler alongside other activity.
  - the folds will share the `vnode_worker_pool` used by folds for the Query API.
- `single`; use a single pool of work for all operational work.
  - This means the whole bandwidth for operational work can be consumed by any operational work.
  - No segmentation, so one set of jobs may prevent other work from finding available capacity.
- `dscp`; divides pools up into categories based on the network pooling strategy of differentiated services.
  - There is no Expedited Forwarding queue, this is assumed to be the `vnode_worker_pool`.
  - There are four Assured Forwarding queues: AF1 (cached tree rebuilds, hot backups); AF2 (legacy key-listing); AF3 (AAE folds); AF4 (AAE folds).
  - There is a single Best Endeavours queue, this is used only for parallel aae store rebuilds.

When queueing items via a fold (e.g. `repl_keys_range`, `repair_keys_range`, `find_tombs` and `reap_tombs`), if a smaller node worker pool is used, then items will be added to the queue in batches by vnode.  When items are dequeued, this may result in phases of concentrated activity on particular preflists.

#### AAE Fold efficiency

Some considerations on the efficiency of AAE Folds:

- Using a restricted key_range is the most reliable method of improving the speed and efficiency of AAE Folds;
- A modified date range will reduce the volume of data to be processed and returned, but significant gains are only made when setting a "high" low modified date.  Old content below the low modified data can be skipped over without reading, but new content since the high modified date must still be read and deserialised.
- The segment_filter can skip the reading and deserialising of slots (each slot contains 128 keys, split into 5 blocks) by checking in the slot header, with approximately 99.6% of blocks skipped when checking for a single segment.
- The segment_filter can be used for sampling, or approximations.  With the standard tree size, there are a `1024 * 1024` segments, so choosing a random slice of 64 segments in that integer space will give results from `1 / (8 * 1024)`th of the key-space.
  - Use of a contiguous slice is more efficient than selecting random slices, as when checking Segments only the first 15 of the 20 bits (assuming standard tree size) in a segment ID are used.
  - When folds are used with Riak anti-entropy mechanisms, the `max_results` settings are used to control the size of the list of segment IDs passed into a fold.

The AAE folds will scan over blocks of keys and metadata.  The performance of AAE fold requests are impacted by the volume of metadata per key, and the throughput per CPU core is likely to be lower than with the [Query API](./QueryAPI.md#performance-and-efficiency) - where only blocks of index entities need to be scanned.  Unlike the Query API, none of the accumulators are required to deduplicate, so there is no related impact on performance.

Where a fold is returning a list of keys, or keys and clocks, it is necessary for the node coordinating the fold to hold the full result-set in memory; and on conclusion of the fold the results will need to be copied at least once to produce an API response.  The performance of the fold will also be impacted by an accumulator which grows with the number of entries covered.

{: .note }
> It is important to consider the memory impact of running an AAE fold on the node that handles the request, especially when using a `find_keys` fold.

### AAE Folds via the Command Line
{: .d-inline-block }

Available from Riak 3.4.0
{: .label .label-purple }

AAE folds can be triggered via the command line using `riak admin tictacaae fold`:

```console
riak admin tictacaae fold list-buckets NVAL
riak admin tictacaae fold find-keys BUCKET KEY_RANGE MODIFIED_RANGE sibling_count=COUNT|object_size=BYTES
riak admin tictacaae fold find-keys BUCKET KEY_RANGE MODIFIED_RANGE sibling_count=COUNT|object_size=BYTES
riak admin tictacaae fold find|count-tombstones KEY_RANGE SEGMENTS MODIFIED_RANGE
riak admin tictacaae fold reap-tombstones KEY_RANGE SEGMENTS MODIFIED_RANGE CHANGE_METHOD
riak admin tictacaae fold object-stats BUCKET KEY_RANGE MODIFIED_RANGE
riak admin tictacaae fold erase-keys BUCKET KEY_RANGE SEGMENTS MODIFIED_RANGE CHANGE_METHOD
riak admin tictacaae fold repair-keys BUCKET KEY_RANGE MODIFIED_RANGE
```

Each of these fold commands will call the corresponding aae_fold operation and write the results in JSON format in a file named `aaefold-%o-results-%t.json`, where `%o` will be substituted with the operation being performed, and `%t`, with the current datetime string, or to a file explicitly specified with option `-o`.

{: .warning }
> The outcome is written to the file only when the fold is completed; so if using `find_keys` the node must be able to hold all keys found in memory at least twice (as the result set needs to be copied between processes).

{: .note }
> It is recommended that the output file be specified, including the full file path, using the `-o` option; rather than being left to the default.  The file path should be writable by the `riak` user.

### AAE Folds via the Remote Console

The AAE Fold API is accessible via `remote_console`.  Using the remote_console is an operator action, but it can be helpful when writing [Erlang functions](https://www.erlang.org/doc/readme.html) that take action based on AAE Folds.

To run an aae_fold via `remote_console`, a query definition is required and then that definition can be called using:

```erlang
FoldResult = riak_client:aae_fold(QueryDefinition).
```

The different inputs to an aae_fold are described in the specification:

```erlang
-type segment_filter() :: list(integer()).
-type tree_size() :: leveled_tictac:tree_size().
-type branch_filter() :: list(integer()).
-type key_range() :: {riak_object:key(), riak_object:key()}|all.
-type bucket() :: riak_object:bucket().
-type n_val() :: pos_integer().
-type riak_client_modified_range() ::
    {date, calendar:datetime(), calendar:datetime()}.
    %% If using riak_client:aae_fold/1 -
    %% will be auto-converted to modified_range().
-type modified_range() ::
    {date, non_neg_integer(), non_neg_integer()}.
-type hash_method() :: pre_hash|{rehash, non_neg_integer()}.
    %% Use pre_hash unless there is specific concern about hash collision
-type change_method() :: {job, pos_integer()}|local|count.
    %% Should generally just use count or local only
-type query_types() :: 
    merge_root_nval|merge_branch_nval|fetch_clocks_nval|
    merge_tree_range|fetch_clocks_range|repl_keys_range|repair_keys_range|
    find_keys|object_stats|
    find_tombs|reap_tombs|erase_keys|
    list_buckets.

-type query_definition() ::
    {merge_root_nval, n_val()} |
    {merge_branch_nval, n_val(), branch_filter()} |
    {fetch_clocks_nval, n_val(), segment_filter()} |
    {fetch_clocks_nval, n_val(), segment_filter(), modified_range()} |
    {merge_tree_range, bucket(), key_range(), tree_size(), {segments, segment_filter(), tree_size()} | all, modified_range() | all, hash_method()} |
    {fetch_clocks_range, bucket(), key_range(), {segments, segment_filter(), tree_size()} | all, modified_range() | all} |
    {repl_keys_range, bucket(), key_range(), modified_range() | all, riak_kv_replrtq_src:queue_name()} |
    {repair_keys_range, bucket(), key_range(), modified_range() | all, all} |
    {find_keys, bucket(), key_range(), modified_range() | all, {sibling_count, pos_integer()}|{object_size, pos_integer()}} |
    {find_tombs, bucket(), key_range(), {segments, segment_filter(), tree_size()} | all, modified_range() | all} |
    {erase_keys, bucket(), key_range(), {segments, segment_filter(), tree_size()} | all, modified_range() | all, change_method()} |
    {reap_tombs, bucket(), key_range(), {segments, segment_filter(), tree_size()} | all, modified_range() | all, change_method()} |
    {object_stats, bucket(), key_range(), modified_range() | all} |
    {list_buckets, n_val()}.
```

### AAE Folds via HTTP

AAE folds require a URL and potentially a filter.  The filter may be a base64 encoded list of JSON key/value pairs to pass key_range, date_range, segment_filter, hash_iv, or change_method.

| Query Type | URL | Filter |
|:-----------|:-----------|:-----------|
| merge_root_nval | `/cachedtrees/nvals/<NVal>/root`| no filter required |
| merge_branch_nval | `/cachedtrees/nvals/<NVal>/branch` | b64 encode json: list of integers |
| fetch_clocks_nval | `/cachedtrees/nvals/<NVal>/keysclocks` | b64 encode json: segment_filter, date_range |
| merge_tree_range | `/rangetrees/types/<BucketType>/buckets/<Bucket>/trees/<TreeSize>` | b64 encode json: key_range, segment_filter, date_range |
| fetch_clocks_range  | `/rangetrees/types/<BucketType>/buckets/<Bucket>/keysclocks`| b64 encode json: key_range, segment_filter, date_range |
| repl_keys_range | `/rangerepl/types/<BucketType>/buckets/<Bucket>` | b64 encode json: key_range, segment_filter, date_range |
| repair_keys_range | `/rangerepair/types/<BucketType>/buckets/<Bucket>` | b64 encode json: key_range, segment_filter, date_range  |
| find_keys (siblings) | `/siblings/types/<BucketType>/buckets/<Bucket>/counts/<Cnt>` | b64 encode json: key_range, date_range |
| find_keys (by size) | `/objectsizes/types/<BucketType>/buckets/<Bucket>/size/<Size>` | b64 encode json: key_range, date_range  |
| find_tombs  | `/tombs/types/<BucketType>/buckets/<Bucket>` | b64 encode json: key_range, segment_filter, date_range |
| erase_keys | `/erase/types/<BucketType>/buckets/<Bucket>` | b64 encode json: key_range, segment_filter, date_range |
| reap_tombs  | `/reap/types/<BucketType>/buckets/<Bucket>` | b64 encode json: key_range, segment_filter, date_range |
| list_buckets | `/aaebucketlist` | `filter=<NVal>` |

To run a query against an untyped bucket, remove the `types/<BucketType>` slice of the URL.

### AAE Folds via PB

The [PB Object API is described in the riak_pb repository](https://github.com/OpenRiak/riak_pb/blob/e908ddaadc06cb56e248f197dc2dca7d759e53b2/src/riak_kv.proto#L409-L660).

## The Fetch API

The fetch API supports three requests: the GET of a membership request, the GET from a queue and the POST to a queue.

| URL | Request parameters | Method | Description |
|:--------------|:--------------|:--------------|:--------------|
| `/membership_request` | n/a | GET | Return a list of IP listeners and ports for members of the cluster |
| `/queuename/<QueueName>` | `object_format = internal\|internal_aaehash` | GET | Consume the next object on queue referred to by Queue Name.  Object response may include segment ID and AAE hash of Key/VC if `internal_aaehash` chosen |
| `/queuename/<QueueName>` | n/a | POST | Push a list of Keys and clocks onto the queue so that those objects may be fetched by a consumer of the queue |

The fetch API is for internal use only in Riak 3.4.  The definition of the API may change in future releases.

## The Data Type API

Riak supports Conflict-Free Replicated Data-Types (CRDTs); specific object formats that can be merged within the database on conflict between versions, so that the application will not see siblings.

There are four basic data-types supported:

- counters;
- grow-only sets;
- sets;
- maps,
  - combinations of the above three types, with support for two additional types - registers and flags.

Support for these data types is unchanged since Riak 2.2.3, so refer to the [legacy documentation](https://docs.riak.com/riak/kv/2.2.3/learn/concepts/crdts/index.html) for further information.

Before using data-types, there are important caveats within the current implementation to consider:

- All CRDTs implement "Action At a Distance", that is to say the application does not provide an identity of the actor making the request.  Due to this, other than for grow-only sets, CRDT updates are not idempotent.
  - The correct handling of failure of an individual request is not presently defined.
- Riak is designed for the storing of many keys, where the load of object requests is spread roughly evenly across the key-space; this is also true for CRDTs.  Do not use individual counters, for example a single hit counter for an application, that may create a __hot__ key that is accessed much more frequently than other keys.
- Both sets and maps have specific constraints in Riak 3.4 where the growth of components within an object is not handled efficiently.
- There is no in-built support for querying data within data-types, the Data Type API is incompatible with the [Query API](./QueryAPI.md).

{: .note }
> The approach to supporting data types is expected to be evolved significantly in future Riak releases; which may result in significant changes to both sets and maps, and change the use of those data types in those releases.

## The Map/Reduce API

The use of Map/Reduce API is deprecated in Riak 3.4, and the API will be retired in Riak 4.0.

For using Map/Reduce with Erlang functions, the API is unchanged since Riak 2.2.3, so refer to the [legacy documentation](https://docs.riak.com/riak/kv/2.2.3/developing/app-guide/advanced-mapreduce/index.html) for further information.  The Map/Reduce API no longer supports JavaScript functions.

{: .note }
> For querying data the [Query API](./QueryAPI.md) should be used in preference to the Map/Reduce API.  The Query API is under active development to expand the number of Map/Reduce use cases it covers, in particular the ability to prompt the fetching of multiple objects.

## The List API

The list API supports the listing of keys and buckets.  The List API is deprecated in Riak 3.4, the [AAE Fold API](#aae-fold-api) should be used instead, with the fold functions [`list_buckets`](#list_buckets), [`find_keys`](#find_keys) and [`find_tombs`](#find_tombs).

The APIs are unchanged since Riak 2.2.3, so refer to the legacy documentation for information on [list keys](https://docs.riak.com/riak/kv/2.2.3/developing/api/http/list-keys/index.html) o [list buckets](https://docs.riak.com/riak/kv/2.2.3/developing/api/http/list-buckets/index.html).

{: .warning }
> The use of list keys or list buckets may have a critical impact on the performance of production clusters.  The AAE Fold alternatives are safe to use on production systems as long as two copies of the result-set can be held within available memory on a single node.

## Legacy Query API

Prior to the introduction of the [Riak Query API](./QueryAPI.md), there existed a simple REST-based API for querying index entries in Riak.  This API is deprecated, use of the Query API is preferred to support new queries.

The binary secondary indexes supported by the legacy index queries, are compatible with the new Query API - anything that could be queried and filtered in the old API can be achieved using the expressions in the new API.

The functionality of the legacy query API is unchanged since Riak 2.2.3, so refer to the [legacy documentation](https://docs.riak.com/riak/kv/latest/developing/usage/secondary-indexes/index.html) for further information.

{: .highlight }
> The legacy API had an undocumented feature that the query attribute `term_regex` could be used to pass regular expressions to filter terms from query results within the range.  This feature is replicated in the new Query API using the `regular_expression` option.

## Strong Consistency API

The use of the strong consistency API is deprecated in Riak 3.4, and the API will be retired in Riak 4.0.

From Riak 4.0, Riak will only have support for eventual consistency, but protection for conflicts can be improved through [conditional PUTs with token-based consensus](./ObjectAPI.md#conditional-requests).

The functionality of Strong Consistency is unchanged since Riak 2.2.3, so refer to the [legacy documentation](https://docs.riak.com/riak/kv/2.2.3/developing/app-guide/strong-consistency/index.html) for further information.

## Write Once Path API

The use of the write once path is deprecated in Riak 3.4, and the API will be retired in Riak 4.0.  The write once path was added to improve performance in very specific use cases, but broader changes have reduced the significance of any performance delta previously gained.  The write once path was not feature compatible with other write methods, and the preference of the OpenRiak community in the future is to reduce the number of caveats required to be understood when working with Riak.

The functionality of the Write Once Path is unchanged since Riak 2.2.3, so refer to the [legacy documentation](https://docs.riak.com/riak/kv/2.2.3/developing/app-guide/write-once/index.html) for further information.
