---
title: OpenRiak QuickDocs Introduction
nav_order: 0
layout: home
---

# OpenRiak QuickDocs 3.4

This site provides overview documentation for the OpenRiak community release of Riak.

## What is Riak?

Riak is a distributed key-value store, designed to provide high-availability with predictable response times in the presence of complex failure scenarios. It can be configured to provide assurance against data loss, even where individual nodes have ephemeral storage, and groups of nodes can be concurrently impacted by failure events.

{: .highlight }
> It is a reliable system whilst running on simple, low-cost, commodity components - remaining highly available without the need for urgent operator intervention.

Riak is commonly used as a schema-free database for the storage and indexing of records, documents, objects or binaries with minimal constraints imposed by the database. In functional terms, Riak can be considered to be a hybrid combination of some of the features available within S3 and DynamoDB.

Riak fully supports multi-cluster environments (within and across physical locations), where open replication is possible not just between Riak clusters, but between Riak clusters and other database services. With Riak, reconciliation is considered as important as replication. Clusters may come in different shapes and sizes - but it is important that as well as replicating data between clusters, it is possible to do rapid and continuous verification that clusters are synchronised.

{: .highlight }
> Riak users have been running large-scale production databases in mission-critical environments on commodity hardware with more than a decade of continuous uptime.  These environments are noted not just for their high availability, but for their low operator-intervention rates.

Riak is often preferred in organisations where technology choices need to be long-lasting, and ongoing operational costs are a more important consideration than up-front developer costs.

Riak is built almost entirely using [OTP](https://www.erlang.org/), a platform designed from the start to support the next generation of reliable systems. Over the past few years Riak has been evolved to make better use of the platform, and is now supported on an ongoing basis by the OpenRiak Working Group of the [Erlang Ecosystem Foundation](https://erlef.org/).

## Riak History

The Riak database, version 1.0, was originally released by [Basho Technologies](https://en.wikipedia.org/wiki/Basho_Technologies) in 2011.  Despite securing a niche within the database market, Basho technologies entered receivership in 2017.  All assets were purchased from the receiver by a [large Riak customer, bet365, who open-sourced all proprietary aspects](https://www.theregister.com/2017/08/25/bet365_to_buy_basho_release_code/).

Since that point, Riak has been maintained by pre-existing Riak users, and regular improvements have been made.  In 2024 the [OpenRiak community](https://openriak.org/) was formed with the intention of further progressing development of the Riak database, but also opening up the development process, with the aim of promoting adoption of Riak outside of its existing base of users.
