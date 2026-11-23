# Security Policy

[![OpenSSF Vulnerability Disclosure](https://img.shields.io/badge/OpenSSF-Vulnerability_Disclosure-green)][openssf-cvd-finders-guide]
[![GitHub Report](https://img.shields.io/badge/GitHub-Security_Advisories-blue)][github-private-vulnerability-reporting]

We take the security of this software seriously and are committed to ensuring
that any vulnerabilities are addressed promptly and effectively.

This repository follows the OpenSSF
[Vulnerability Disclosure guide][openssf-cvd-guide].
You can learn more about it in the [Finders Guide][openssf-cvd-finders-guide].

## Reporting Security Issues

If you believe you have found a security vulnerability in this repository,
please report it via [GitHub Security Vulnerability Reporting][github-private-vulnerability-reporting]
at `github.com/OpenRiak/riak/security/advisories/new`.

**Please do not report vulnerabilities through public channels** such as GitHub
issues, discussions, or pull requests, to avoid exposing the details of the
issue before it has been properly addressed.

We don't implement a bug bounty program or bounty rewards, but will work with
you to ensure that your findings get the appropriate handling.

When reporting a vulnerability, please include as much detail as possible to
help us triage and resolve the issue efficiently. Information that will be
specially helpful includes:

- The type of issue (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the issue
- The location of the affected source code (e.g., tag, branch, commit, or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if available)
- The potential impact, including how the issue might be exploited by an attacker

The OpenRiak maintainers will acknowledge and triage reports as soon as
possible. If an issue is confirmed as a vulnerability, the maintainers will
open a Security Advisory and work with the reporter to coordinate a fix and a public disclosure.
This project follows a 90-day disclosure timeline.

[openssf-cvd-guide]: https://github.com/ossf/oss-vulnerability-guide/tree/main
[openssf-cvd-finders-guide]: https://github.com/ossf/oss-vulnerability-guide/blob/main/finder-guide.md
[github-private-vulnerability-reporting]: https://github.com/OpenRiak/riak/security/advisories/new
