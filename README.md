# GitHub Dependency Submission Action for Rebar

This GitHub Action extracts dependencies from an Rebar project and submits them to
[GitHub's Dependency Submission API](https://docs.github.com/en/rest/dependency-graph/dependency-submission),
helping you unlock advanced dependency graph and security features for your
project.

## Why Use This?

By submitting your dependencies to GitHub:

- 🔐 **Stay secure** – Receive
  [Dependabot alerts and security updates](https://docs.github.com/en/code-security/dependabot/dependabot-alerts) for
  known vulnerabilities in your direct and transitive dependencies.
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
name: "Rebar Dependency Submission"

on:
  push:
    branches:
      - "main"

# The API requires write permission on the repository to submit dependencies
permissions:
  contents: write

jobs:
  report_rebar_deps:
    name: "Report Rebar Dependencies"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: kivra/rebar-dependency-submission@v1
```

### Example Using `actions/dependency-review-action`

```yaml
name: "Rebar Dependency Submission"

on:
  push:
    branches:
      - "main"
  pull_request: {}

# The API requires write permission on the repository to submit dependencies
permissions:
  contents: write

jobs:
  report_rebar_deps:
    name: "Report Rebar Dependencies"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: kivra/rebar-dependency-submission@v1
      - uses: actions/dependency-review-action@v4
        if: "${{ github.event_name == 'pull_request' }}"
```

## Inputs

| Name           | Description                                                                                 | Default                     |
|----------------|---------------------------------------------------------------------------------------------|-----------------------------|
| `token`        | GitHub token to use for submission.                                                         | `${{ github.token }}`       |
<!--| `project-path` | Path to the Mix project.                                                                    | `${{ github.workspace }}`   |-->
<!--| `install-deps` | Whether to run `mix deps.get` before analysis. Set to `true` for accurate transitive info.  | `false`                     |-->
<!--| `ignore`       | A comma-separated list of directories to ignore when searching for Mix projects.            | *(none)*                    |-->

<!--> ⚠️ If `install-deps` is set to `false`, the action may not fully resolve transitive dependencies, leading to an incomplete dependency graph.-->

## Outputs

| Name                   | Description                                 | Example Value                                                                 |
|------------------------|---------------------------------------------|-------------------------------------------------------------------------------|
| `submission-json-path` | Path to the generated submission JSON file. | `/tmp/submission-213124323.json`                                              |
| `snapshot-id`        | ID of the submission.                       | `1234`                                                                        |
| `snapshot-api-url`   | URL of the submission API.                  | `https://api.github.com/repos/{owner}/{repo}/dependency-graph/snapshots/1234` |

<!--
## OS and Architecture Support

This action supports the following operating systems and architectures, tested using the corresponding
[GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources):

| Operating System | Architecture | Supported | Tested Runner         |
|------------------|--------------|-----------|------------------------|
| Linux            | x64          | ✅        | `ubuntu-24.04`         |
| Linux            | ARM64        | ✅        | `ubuntu-24.04-arm`     |
| macOS            | x64          | ✅        | `macos-13`             |
| macOS            | ARM64        | ✅        | `macos-15`             |
| Windows          | x64          | ✅        | `windows-2025`         |
| Windows          | ARM64        | ❌        | *(not supported)*      |
-->

## License

Copyright 2025 Kivra

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at:

  > <http://www.apache.org/licenses/LICENSE-2.0>

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
