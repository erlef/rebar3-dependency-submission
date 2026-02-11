# GitHub Dependency Submission Action for Rebar3

This GitHub Action extracts dependencies from an Rebar3 project and submits them to
[GitHub's Dependency Submission API](https://docs.github.com/en/rest/dependency-graph/dependency-submission),
helping you unlock advanced dependency graph and security features for your
project.

## Why Use This?

By submitting your dependencies to GitHub:

- 🔐 **Stay secure** – Receive
  [Dependabot alerts and security updates](https://docs.github.com/en/code-security/dependabot/dependabot-alerts)
  for known vulnerabilities in your direct and transitive dependencies.
- 🔎 **Improve visibility** – View your full dependency graph, including
  dependencies not found in lockfiles, right on GitHub.
- 🔁 **Automated updates** – Dependabot can automatically open pull requests to
  fix vulnerable dependencies.
- ✅ **Better reviews** – See dependencies in pull request diffs via GitHub’s
  [Dependency Review](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/about-dependency-review).
- 📊 **Support compliance** – Help your team understand and audit what
  third-party code your software depends on.

## Usage

This action is intended to be used within a GitHub Actions workflow.

### Minimal Example

```yaml
on:
  push:

permissions:
  # The API requires write permission on the repository to submit dependencies
  contents: write

jobs:
  rebar3-dependency-submission:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v6.0.2
      # TBD(erlef): update uses
      - uses: kivra/rebar3-dependency-submission@v1.0.0
```

## Inputs

| Name    | Description                         | Default               |
|---------|-------------------------------------|-----------------------|
| `token` | GitHub token to use for submission. | `${{ github.token }}` |

## OS and Architecture Support

This action was tested for the following operating systems and architectures, using the corresponding
[GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources):

| Operating System | Architecture | Tested Runner      |
|------------------|--------------|--------------------|
| Linux            | x64          | `ubuntu-24.04`     |
| Linux            | ARM64        | `ubuntu-24.04-arm` |

If you find it working for another operating system / architecture, feel free to open a pull request
to update the table above.

## License

Copyright 2026 Kivra

<!-- # TBD(erlef): Copyright? -->

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at:

  > <http://www.apache.org/licenses/LICENSE-2.0>

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
