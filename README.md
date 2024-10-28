# Riak - a distributed, decentralised data storage system.

![Riak Core OpenRiak Status](https://github.com/OpenRiak/riak_core/actions/workflows/erlang.yml/badge.svg?branch=openriak-3.2)
![Riak KV OpenRiak Status](https://github.com/OpenRiak/riak_kv/actions/workflows/erlang.yml/badge.svg?branch=openriak-3.2)
![Riak Repl OpenRiak Status](https://github.com/OpenRiak/riak_repl/actions/workflows/erlang.yml/badge.svg?branch=openriak-3.2)

To build riak, Erlang OTP 22 or higher is required.

`make rel` will build a release which can be run via `rel/riak/bin/riak start`.  Riak is primarily configured via `rel/riak/etc/riak.conf`

To make a package, install appropriate build tools for your operating system and run `make package`.

To create a local multi-node build environment use `make devclean; make devrel`.

To test Riak use [Riak Test](https://github.com/basho/riak_test/blob/develop-3.0/doc/SIMPLE_SETUP.md).

Up to date documentation is not available, but work on [documentation](https://www.tiot.jp/riak-docs/riak/kv/3.2.0/) is ongoing and the core information available in the [legacy documentation](https://docs.riak.com/riak/kv/latest/index.html) is still generally relevant.

Issues and PRs can be tracked via [Riak Github](https://github.com/basho/riak/issues) or [Riak KV Github](https://github.com/basho/riak_kv/issues).
