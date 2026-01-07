---
title: Object API
nav_order: 4
layout : default
---

# Riak KV - Object API

Objects can be fetched and updated via either a HTTP or Protocol Buffer API.  Considerations to be made when choosing a transport protocol include:

- The PB API is more performant, in particular when using significant numbers of index entries or user metadata due to the overheads of parsing HTTP headers, the delta between the APIs is generally between 5% and 15% in terms of request latency;
  - Improving relative HTTP performance is a key goal of Riak development for future releases.
- The HTTP API is generally quicker to develop against due to the ubiquity of HTTP-based tooling, and the ability for developers to switch to command line tools (e.g. curl) or graphical tools.
  - The HTTP API is not strictly standards compliant, in that it uses HTTP request headers to describe the object rather than the request.  It is not possible to describe the API using standard tooling (e.g. OpenAPI).
- The HTTP API places strict requirements on the characters supported in identifiers, user metadata and index entries.  Supporting non-HTTP safe characters is possible via the PB API but it is NOT supported.
  - Always ensure that objects will be supported via HTTP, even when using PB.
- Using the HTTP API will provide greater flexibility to control access to Riak via standard internet infrastructure (e.g. Web-Application Firewalls, Proxies and Load-Balancers).

{: .note }
> New APIs added to Riak will be added to the HTTP API first.  It is expected that in the long term the performance of the HTTP API will be improved, and that the relative ubiquity of HTTP will evolve the choice of API towards HTTP being the default protocol.

The [PB Object API is described in the riak_pb repository](https://github.com/OpenRiak/riak_pb/blob/e908ddaadc06cb56e248f197dc2dca7d759e53b2/src/riak_kv.proto#L45-L125), but the concepts are the same as for the HTTP API.

The Riak Object HTTP API is described here:

- [The URL](#object-identifier---the-url)
- [The body](#object-value---the-request-body)
- [The request and response headers](#object-meta-content---the-request-and-response-headers)
- [Adding options to a request - query parameters](#get-and-put-options)
- [Conditional requests](#conditional-requests)
- [Commit hooks](#commit-hooks)
- [Storing an object](#http-api-definition---store)
- [Fetching an object](#http-api-definition---fetch)
- [Deleting an object](#http-api-definition---delete)
- [Legacy objects](#accessing-legacy-objects)

## Object Identifier - the URL

The Riak object Identifier is split into three parts:

- Bucket Type;
- Bucket;
- Key.

Internally within Riak all three elements are binary identifiers,  With the Object HTTP API these elements are represented within the URL e.g. `/types/BucketType/buckets/Bucket/keys/Key`.

{: .warning }
> Although it is possible to use non-URL-safe identifiers using the Protocol Buffer API, it is important not to do so - as any object using a non-URL safe identifier will not be accessible via the HTTP API, as there is no encoding of non-Alphanumeric identifier parts.

The [Bucket Type](./InstallAndStartGuide.md#configuration-of-riak---bucket-properties) is used to describe the properties of the object.  Properties are associated with a Bucket Type, and all Objects in the Buckets under that type will inherit those properties. The Bucket is a namespace, and a Bucket Type is allowed to have an arbitrary number of Buckets.  A Bucket cannot be moved between Bucket Types, but the properties of an individual Bucket may be changed to override that of the Bucket Type.  Keys are unique identifiers of an object within a Bucket.

A Bucket Type cannot be used via the API until it has been created and activated, to do this see:

```console
riak admin bucket-type --help
```

It is preferable to set the properties of a Bucket Type before using it.

## Object Value - the request body

Within Riak, object values are generally opaque to Riak.  The schema of the value is managed by the application, not by Riak.  Values are normally binaries, but a content-type can be passed by the user and associated with the value - and any content type can be used, as Riak will not read the value it will store it.

Riak is not optimised for small values, although there is no lower limit to the size of the value.

{: .note }
> Typically values stored in Riak are between o(1KB) and o(1MB) in size, but are not constrained by these limits.

To Riak object values are generally opaque, but Riak does have support for [data-types](./OtherAPI.md#the-data-type-api); specially formatted values where the handling of conflict is deterministic and managed within the database, so the application does not see siblings even though [`allow_mult` is set to `true`](./InstallAndStartGuide.md#property---allow_mult).

## Object Meta Content - the request and response headers

There are four object components that make use of HTTP headers:

- Version vector;
- User Metadata;
- Object Metadata;
- Index Entries.

### Version Vector

The Riak [version vector](./RiakTheoryGuide.md#version-vectors) is relevant to the database, but generally opaque to the application.  The application should read the version vector (which will be presented base64 encoded), and present the read version vector when updating an object.  The application does not need to understand the contents of the version vector.

The version vector is referred to in the API as a `vector clock` (or `vclock`).  This vector is used internally within Riak to track which content is most up-to-date - to differentiate between content that is superseded (i.e. where an update had seen the content) or genuinely concurrent (the writes were made in parallel).  Parallel writes will lead to unresolvable conflict, and how this is handled is defined within the [bucket properties](./InstallAndStartGuide.md#property---allow_mult).

### User Metadata

User Metadata is arbitrary pairs of binary Keys and Values that form part of the content.  The user metadata is opaque to the database.  Internally, and via the protocol buffer API then the Keys and Values may be any binary - but for presentation and use via the HTTP API they keys must be url safe and case insensitive, and the values must be visible ascii.

### Object Metadata

Riak carries metadata about an object, primarily:

- the last modified date;
  - internally within Riak this is a timestamp to microsecond accuracy,
  - when presented via the HTTP API the accuracy is truncated to a second.
- the deleted status (does the object represent a current value or a record of deletion).
- the ["dot" for each content item](#version-vector) - this is not returned via the API;
- the content type
  - the content type is never validated, it may be added to an update, and will be returned as-is regardless of the nature of the value.

### Index Entries

Index entries consist of multiple index fields, where each index field may have multiple values. The field names must have a suffix of either `_bin` or `_int` - where `_bin` indicates the value will be a binary, and `_int` indicates the value is an integer.  Although the value of an index entry may be a binary type, as it is passed in HTTP headers it is [restricted to visible ASCII text](https://datatracker.ietf.org/doc/html/rfc7230#section-3.2), and field names are required to be handled in a case-insensitive way: so using only lower-case alphanumeric index field names is recommended to avoid future compatibility issues between APIs.

An object will always be presented (in a GET response) with all its index entries, and when updating an object all index entries must be passed - an update requires all entries, not a delta.

If an object results in an unresolved conflict, the index entries for the object within the database will be the union of the index entries for all sibling content items.

## GET and PUT Options

The GET and PUT API allow for options to be passed in the HTTP API via [HTTP query parameters appended to the URI](https://www.rfc-editor.org/rfc/rfc3986#section-3.4).

It is recommended that the options supported in the Object API should be set via [bucket properties](./InstallAndStartGuide.md#configuration-of-riak---bucket-properties) wherever possible (except where the option is a per-request option rather than a property e.g. `vtag`).  It is best practice to define the expectations for managing a request within the properties of the type, and only use options to override those definitions.

The most common options used are:

- `vtag`; to be added to a read request from an object in a sibling state, where the value is the `vtag` of one of the sibling objects.
- `notfound_ok`; should be set to `false` if the application is expecting an object.  Only valid for read requests.
- `node_confirms`; can be set to a number 1..N where N is the `n_val` for that object, and used to indicate how many unique nodes must contribute to the quorum when handling the request.  Can be set on either store or read requests.
- <span>Available from Riak 3.0.8</span>{: .label .label-green }`sync_on_write`; can be set to `one`, `all` or `backend` and is used to indicate whether it is necessary to flush the write to disk before confirming a request.  Generally all backends should be set not to flush pre-request (for performance), and where required the setting of `one` or `all` may be used where data-loss protection in catastrophic failure scenarios is of elevated importance.  Only valid for store requests.
- `pr`; can be set to 1..N where N is the `n_val` for that object.  Stipulates how many primary vnodes must be involved in providing consensus before returning an object.  Should be set to `1`.  Only valid for read requests. 
- `pw`; can be set to 1..N where N is the `n_val` for that object.  Stipulates how many primary vnodes must have acknowledged acceptance of a store request before returning a positive response to the client.  Only valid for write requests.
- `return_body`; should the updated object be returned in response to a store request.  Only valid for write requests.
- `deleted_vclock`; if an object is not_found, but is in fact a tombstone, should the version vector of the tombstone be returned, to be used if it is required to update the deleted object with a new object.  Only valid for read requests.
- `timeout`; the maximum time (in milliseconds) to wait for a response from Riak before returning a timeout error.

There are four other potential PUT and GET options related to the balance between consistency, performance and availability: `w`, `r`, `sloppy_quorum` and `dw`; but changing of these defaults on a per-request basis is not recommended.

## Conditional Requests
{: .d-inline-block }

Available from Riak 3.4.0
{: .label .label-purple }

Conditional updates are very useful when looking to prevent siblings.  By default, any concurrent updates will lead to sibling generation, and handling siblings within application code may be expensive (and in some cases may require user intervention).  This can be controlled by making PUT requests conditional, with configurable degrees of strictness on how the condition will be checked to prevent concurrent changes.

{: .note }
> Conditional updates allow for improved consistency, but not formal consistency.

There are four levels of strictness to the application of conditions:

- api_only;
  - this is the loosest check; in this case when the PUT request has been received and parsed by Riak, it will check that the object has not changed (if_not_modified) or does not exist (if_none_match).
  - there remains broad scope for parallel writes leading to siblings in this case.
- prefer_token and head_only;
  - in this form, the process controlling the PUT within Riak must first get a token for the object key from the token manager, and the token manager will only grant a token to one process at a time;
  - the granting of tokens is managed by the node at the head of the preflist, and only the node at the head of the preflist;
  - in a cluster without failure or administrative cluster changes this will prevent concurrent writes, with a minimal performance overhead.
- prefer_token and basic_consensus;
  - in this form, the process controlling the PUT within Riak must first get a token for the object key from the token manager, and the token manager will only grant a token to one process at a time;
  - the granting of tokens is managed by consensus between available unique nodes in the preflist (either primary or fallback);
  - in a cluster without failure or administrative cluster changes this will prevent concurrent writes;
  - tokens can still be granted in a wide range of failure scenarios safely, but with a risk of duplicate grants, in particular should a cluster be partitioned.
- prefer_token and primary_consensus;
  - in this form, the process controlling the PUT within Riak must first get a token for the object key from the token manager, and the token manager will only grant a token to one process at a time;
  - the granting of tokens is managed by consensus between 3 of 5 primary nodes in a preflist;
  - to use this node, the cluster must be built with a target_n_val of at least 5;
  - in a cluster without failure or administrative cluster changes this will prevent concurrent writes
  - the chance of duplicate grants in this scenario is very small, but non-zero;
  - there will be no failure to grant as long as there are no more than two nodes down or unreachable within the cluster.

The level of strictness is set for the entire cluster, using the `conditional_put_mode` and `token_request_mode` configuration items in `riak.conf`:

```console
riak admin describe conditional_put_mode
riak admin describe token_request_mode
```

A failure of a conditional request will result in a `412: Precondition Failed` response.  Note, that data is not secure at this point, and is vulnerable to the failure of the application, if it was not stored already in a Riak cluster prior to making the conditional change (e.g. when using Riak in an Event Source / CQRS model).

Tests have verified that in non-exceptional scenarios, simple failure events and cluster administration changes will lead to the promise of consensus being upheld (with both basic and primary consensus). This however, is not equal to strong consistency by any formal definition.  There will be complex and potentially unexpected scenarios where the condition will not be applied in a serialised way.  Riak remains an eventually consistent store, to protect data in all scenarios still requires the setting of `allow_mult = true` and the potential return of multiple (sibling) content values to an object read request.

There are three scenarios where the conditional check will be weakened:

- The token granting system uses an internal queue method, and requests made whilst the token has been currently granted will be notified to re-request for a grant when it is their turn for the grant.  So sending multiple requests in parallel will generally result in one update succeeding, and then all other parallel requests failing due to the precondition check in rapid succession as they gain ownership of the token when the previous request releases.  There is though a timeout, beyond which a process will not wait, and on timeout a process will revert to an `api_only` check.
- The token granting system is enforced as **an honesty system**, it is the role of the application to ensure that all objects that require token protection have conditions added to update requests.  Updates without condition checks will be accepted in parallel to updates with condition checks, and there may be unresolved conflicts as a consequence.
- When using multi-data centre replication, there is no cross-checking between clusters before granting tokens.  If running multiple clusters in active/active mode, then token consensus offers no protection against parallel writes, unless there is natural isolation within the application (should objects have a natural association with a region that would make inter-cluster concurrent writes unexpected).

Stronger conditional updates can be made via either API through the use of "if_none_match" and the Riak-bespoke "if_not_modified" headers (or options in the case of the PB API).  Use of the HTTP-standard "if_not_modified" header or of the "if_match" header will result only in weak `api_only` checks, and is not fully supported.

### Use of Request Header - If_None_Match

The use of if_none_match is tested on update operations only.  It uses the standard HTTP request header, but ignores the value - setting the request header to any content will be treated as `if_none_match: *`.  The purpose of if_none_match is simply to check that there is no object present before accepting the update.

### Use of Request Header - If_Not_Modified (non-standard Riak header)

The use of if_not_modified varies from the standard behaviour of the if_not_modified HTTP request.  For Riak the `x-riak-if_not_modified` header should be used as a modification check, and the value of the header should be set to the encoded version vector that had been read prior to the update.  The PUT will then be conditional on the object being at this state before the change is applied.

### Conditional requests and latch objects

There may be circumstances where it is necessary to prevent multiple application processes working on the same set of objects concurrently - e.g. where there are two processes for batching objects, and only one should be batching at a time so the batches don't overlap.  Although conditional requests are intended to provide consensus over individual objects, the application developer may define individual objects in such a way so that they can be used as part of a system to provide broader pseudo-serialisation of activity.

## Commit Hooks

For store requests it is possible, via bucket properties, to configure "commit hooks" - functions that will be applied either pre-commit (before the PUT has coordinated), or post-commit (after coordination and before response to the client).  This may have uses such as: value validation; updating inverted index objects; triggering actions in external systems.

Commit hooks are an expert feature, and should not be added without an understanding of the Riak codebase.

## HTTP API Definition - Store

Store requests should be sent using the `PUT` method, although the `POST` method is supported.  Using `POST` is not strictly correct with regards to RFC 7231, and a misconfigured URL may lead to objects being inserted using Riak-generated keys (a deprecated feature).

Supported HTTP request headers for PUT:

- `x-riak-vclock`; should be provided when mutating existing objects, should be the contents of the object read prior to update.
- `x-riak-if_not_modified`; optional, for conditional requests.
- `if_none-match: *`; optional, for conditional requests.
- `authorization`; optional, for tls-protected requests only when [Riak security is enabled](./OperationsAndTroubleshootingGuide.md#enabling-riak-security).
- `x-riak-meta-<key>: <value>`; optional, multiple keys may be provided, and will be mapped to user metadata.
- `x-riak-index-<field> : <value1>, <value2>`; optional add multiple index fields, with multiple values in each field where those values are comma (and whitespace) separated.  Index fields should have the suffix `_bin` or `_int`.
- `content-type: <content_type>`; optional, specify the content-type of the value to be stored, to be provided in response to future GET requests.

### Example PUT request

```console
curl -v -XPUT
 -d '{"bar":"baz"}'
 -H "Content-Type: application/json"
 -H "x-riak-index-twitter_bin: jsmith123"
 -H "x-riak-index-email_bin: jsmith@riak.com, jsmith_personal@btinternet.com"
 -H "X-Riak-Vclock: a85hYGBgzGDKBVIszMk55zKYEhnzWBlKIniO8mUBAA=="
 http://127.0.0.1:8098/types/BType/buckets/BTest/keys/TestKey
```

## HTTP API Definition - Fetch

Fetch requests for objects should be sent using the `GET` method, or the HEAD method.

When using the HEAD method the request will still result in the object value being read by Riak, but the value will be stripped before returning the object - the process is not currently optimised. A HEAD response may not contain a valid content-length.

Supported HTTP request headers for GET:

- `authorization`; optional, for tls-protected requests only when [Riak security is enabled](./OperationsAndTroubleshootingGuide.md#enabling-riak-security).
- `accept: multipart/mixed`; optional, will cause results in a conflicted state to return all siblings as one multipart-mime object body.  Without this option a list of sibling vtags will be returned, and each `vtag` may be fetched using the `vtag=<vtag>` query parameter in the URL.

Expected HTTP response headers for GET:

- `x-riak-vclock`; an encoded representation of the version_vector, must be provided in an update message to indicate which version of the object is to be updated.
- `x-riak-meta-<key>: <value>`; potentially multiple headers representing the user metadata for the object.
- `x-riak-index-<field> : <value1>, <value2>`; potentially multiple headers representing the current index values for the object.
- `content-type: <content_type>`; the content-type provided when the object was stored.

### Example GET request

```console
curl -v
  http://127.0.0.1:8098/types/BType/buckets/BTest/keys/TestKey
  -H "Accept: multipart/mixed"
```

## HTTP API Definition - Delete

Delete requests should be sent using the DELETE method.  As with PUT requests, DELETE requests should include the `x-riak-vclock` header with the value of the entry that was read.  

Without providing version information, the delete will first read the current version of the object, and then attempt to delete the object using that discovered version information.  This may not be the same version of the object that prompted the delete request.  DELETE with no `x-riak-vclock` is "delete regardless", whereas with a `x-riak-vclock` it is a request to delete only the object at that version.

Supported HTTP request headers for DELETE:

- `x-riak-vclock`; see above.
- `x-riak-if_not_modified`; optional, for conditional requests.
- `if_none-match: *`; optional, for conditional requests.
- `authorization`; optional, for tls-protected requests only when Riak security is enabled.

### Example DELETE request

```console
curl -v -X DELETE
  http://127.0.0.1:8098/types/BType/buckets/BTest/keys/TestKey
  -H "X-Riak-Vclock: a85hYGBgzGDKBVIszMk55zKYEhnzWBlKIniO8mUBAA=="
```

## Accessing Legacy Objects

As well as typed buckets, Riak offers support for untyped buckets for backwards compatibility.  Using the HTTP API for such buckets is the same as using typed buckets, except that the URI for keys in untyped buckets is `buckets/Bucket/keys/Key` (i.e. as before but without the prefix of `types\TypedBucket`).

## Performance and Efficiency

### Notes on Implementation

When a request is made to PUT an object in Riak, the PUT is sent to an available primary to coordinate the change.  A Primary vnode is considered available when the node on which it resides is reachable and reported as active by intra-cluster health-checks.  The coordination of a change is the updating of the version history of the object (the version vector), storing the object and prompting replication to other clusters where required. The PUT is then sent to the remaining available primaries (or fallbacks should there be a failure), to be stored at those vnodes if the version history indicates this change is more recent that the currently stored object.

Handling a forwarded PUT is marginally less expensive than coordinating a PUT.

When a request is made to GET an object in Riak, the metadata (containing the vector of the version history) for that object is fetched from each vnode in the preflist.  The first vnode to respond is tasked with fetching the value, and the remaining responses are used to determine whether the fetched value represents the most recent version (and if it is it may be returned to the client as the response).  If a replacement (later) version is available, then that is fetched as the value instead.  If analysis of the version vector and the version of the values, cannot determine which value is up-to-date the full history of unreconciled values is returned as "siblings".

{: .note }
> As of Riak 3.4, the bitcask backend does not support the handling of HEAD requests.  Each vnode will respond to the original request with the whole object, and no race is invoked.  Support for HEAD requests is available only in the leveled backend.

Handling the value fetch on vnode is an order of magnitude more expensive than simply handling the request for metadata.

Each vnode has a single queue through which all requests are received.  There is no priority on this queue, a request cannot be processed until all previous requests have been handled.  Latency on a very busy Riak cluster is generally governed by the vnode queue sizes.  The GET and PUT process are designed to ensure that request performance is never governed by the pace of the longest queue.  Activity can proceed with a quorum of answers, and work is dynamically reduced so that vnodes with longer queues do less work until those queues realign with other vnodes.

### Performance Expectations

Within the object API load distribution is first based on consistent hashing (to find the preflist of vnodes), but the race to support the value fetch in `GET` operations, and also the selection of the coordinator of a `PUT` operation is designed to try and rebalance load discrepancies within a preflist of vnodes.

The Object API is designed to be the most efficient of all the Riak APIs; it is assumed that requests to the Object API will occur with at least an order of magnitude of frequency greater than requests to other APIs.

{: .highlight }
> The primary target of Riak is not to minimise response times in normal conditions, but to provide predictable response times in extreme conditions with resource contention, device failure and device recovery.

In summary, the performance targets for the Object API are:

- With high-speed infrastructure, a 1ms mean response time should be achievable assuming small object sizes and a limited number of index entries per object.
- Without contention and under healthy conditions, for objects of o(100KB) in size with o(10) index entries per object (via the HTTP API) into a store with > 100M records, as measured from the application;
  - 3ms per GET (mean).
  - 7ms per PUT (mean).
- Under contention, and within failure scenarios, for o(10ms) 99th percentile response times to Object API requests.
  - It should be possible to maintain controlled response times as the failure is recovered (including repair of lost data), as well as when the failure occurs.
  - In general the 99th percentile should be less than twice the mean.
- As object sizes grow, the growth is response times should be logarithmic not linear - and stability of tail latency should not be impacted
  - As the differential between the cost of a HEAD request and a GET request expands with the size of objects, the stability of tail latency may actually improve with larger objects.

In Riak, an object of o(1KB) in size is considered to be small, and an object of o(1MB) in size is considered to be large.  For very large objects overall performance will be improved by the sharding of objects within the application.
