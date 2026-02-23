# Contributing to the OpenRiak Project

Thank-you for considering a contribution to the OpenRiak project.  Please follow this guide when making a contribution.

## Declaration

```txt
By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the 
    best of my knowledge, is covered under an appropriate open 
    source license and I have the right under that license to   
    submit that work with modifications, whether created in whole
    or in part by me, under the same open source license (unless
    I am permitted to submit under a different license), as 
    Indicated in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including 
    all personal information I submit with it, including my
    sign-off) is maintained indefinitely and may be redistributed
    consistent with this project or the open source license(s)
    involved.
```

See http://developercertificate.org/ for a copy of the Developer Certificate of Origin license.

The OpenRiak project is licensed under the Apache License 2.0, as stated in: [LICENSE.txt](LICENSE.txt)

## Overview

The OpenRiak project uses GitHub Discussions, Issues and Pull-Requests as part of a three-stage process to collaborate and accept code contributions.

Discussions are used to get feedback on ideas, issues are used to agree on the scope and approach to implementing an idea and pull-requests to manage the final process of submitting a change and having the change reviewed and released.

Please follow all stages for non-trivial changes to help avoid extensive re-work or rejection.

## Stage 1 - Discussions

For major feature changes, a Feature Proposal must be made on [Riak discussions](https://github.com/orgs/OpenRiak/discussions).

The proposal must have the following sections:

- Background; information on the need for the feature.
- Proposal; a description of the feature.
- Design; an overview of how the implementation is expected to work.
- Alternative Design Ideas; alternative implementation approaches considered but not chosen (with reasoning).
- Testing; specific test challenges expected (e.g. if this is a performance improvement, how to measure it is successful).
- Caveats; any known dependencies on other changes, or potential roadblocks which would cause the implementation to be abandoned.
- Reference; reference to any issues or PRs raised for the feature (to be added later).
- Planned Release for Inclusion.

If feedback is not received on the proposal, then please escalate via the `open-riak` channel on the Erlang Ecosystem Foundation Slack channel.

Note that without positive feedback, it may be difficult to pass any proposal through the PR review stage.  It is easier to find maintainer review-time for PRs in support of proposals with a broad consensus.

## Stage 2 - Issues

For major changes, the proposal should be split into one or more Github Issues.  Those issues can be used to discuss the details of the implementation.  Seeking feedback from maintainers on implementation approach through an issue is necessary prior to commencing work on any Pull Requests.  Each issue must be assigned to an individual who has agreed to complete the work.

An issue may cover changes required to multiple OpenRiak repositories - do not raise separate issues for each repo.  If it is not clear what the primary repository is for the change, then by default issues should be raised in the [riak_kv repo](https://github.com/OpenRiak/riak_kv/issues).

Once an Issue has been discussed and assigned, it will be added into a plan for a given release by a maintainer.  Progress towards releases is tracked via [github Projects](https://github.com/orgs/OpenRiak/projects) and discussed through the monthly `open-riak` EEF working-group meeting.  Agreeing the given release is necessary to determine the root branch from which to base any required PRs, and the target OTP release for testing that branch.  Do not proceed with PRs prior to an issue being aligned to a release.

## Stage 3 - Fork, Branch and raise PRs

Once a PR is made it may be reviewed and accepted into the code base.  General advice on raising PRs that will help the review process, is:

- Ensure all code is covered by an Apache 2.0 license.
- Reduce the footprint of each change by reusing existing code where possible.
- Use branch names that refer to the issue and the root branch from which the change has been made. 
- Every change must successfully pass `xref`, `dialyzer` and `eunit` for that repo.  Most repos will also have `QuickCheck` tests, and these can be verified by a maintainer.
- Some repos have specific additional acceptance criteria highlighted in their README files - e.g. code coverage constraints, ct tests, formatting requirements, and `eqwalizer` verification needs.
- Providing evidence of third-party test and assurance of the change will speed the acceptance process.
- All significant changes will require system test coverage in [riak_test](https://github.com/OpenRiak/riak_test).
- Any tests must also be added into a relevant [`riak_test` group](https://github.com/OpenRiak/riak_test/tree/openriak-3.4/groups).
- All significant changes will require [Riak QuickDocs updates](https://github.com/OpenRiak/riak_kv/tree/openriak-3.4/docs).  QuickDocs is rendered using [Just-The-Docs](https://github.com/just-the-docs/just-the-docs) and supports [Mermaid diagrams](https://mermaid.live/edit).- Any required evidence of performance testing must be added to the Github Issue related to the PR.
- Code formatting of new modules using [`erlfmt`](https://github.com/WhatsApp/erlfmt) is preferred, but not enforced unless specified with the README.
- All PRs required to resolve an issue must be linked to the issue.

A PR must be reviewed by a maintainer before being accepted.  Note that there are no guarantees that a maintainer will have the time required to review a change to meet a release deadline.

## Smaller Contributions

Existing needs and fixes are highlighted in the Github Issue for each project repo.  The majority can be found in [Riak KV](https://github.com/OpenRiak/riak_kv/issues).  When new to contributing to OpenRiak, tackling an issue marked `good first issue` is a good way to win trust within the community.
