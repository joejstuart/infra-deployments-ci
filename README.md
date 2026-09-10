# infra-deployments-ci
Keep infra-deployments updated with the latest Enterprise Contract components

## Policy behavior checks

`policy-behavior/compare-policy-behavior.sh` runs `ec validate input` on the
checked-in policy inputs selected by `policy-behavior/policy-behavior-tests.json`.
The suite includes SLSA v0.2 and v1 provenance plus SPDX and CycloneDX SBOM
attestations. Each fixture is
evaluated with both a previous release-policy bundle and a candidate bundle.
The standalone check compares the rule codes in their warnings and violations
and writes a Markdown report. It is not currently part of CI.

Each test also lists sentinel rules in `expectedRules`. The candidate must
trigger those rules. One `@redhat` case provides broad integration coverage;
the other cases select focused packages or rule codes so unrelated failures do
not obscure the behavior being tested. The suite exercises build parameters,
hermetic and dependency-prefetch behavior, source materials, task status and
references, test results, builder identity, RPM pipelines, Multi-CI provenance,
external parameters, pre-build scripts, and both supported SBOM formats.

### Run locally

The comparison requires Bash, `jq`, and either Docker or Podman. The selected
container engine must be running and able to pull images from Quay.

#### macOS

Install Bash and `jq` with Homebrew:

```bash
brew install bash jq
```

Use either Docker Desktop or Podman. For Docker Desktop, start the application
and verify the engine is ready:

```bash
docker info
unset CONTAINER_ENGINE
```

For Podman, install it and create its Linux virtual machine once:

```bash
brew install podman
podman machine init
```

On subsequent runs, start the machine and select Podman for the comparison:

```bash
podman machine start
export CONTAINER_ENGINE=podman
```

`podman machine init` reports an error if a machine already exists; in that
case, only `podman machine start` is needed.

#### Linux

Install Bash, `jq`, and Docker or Podman with the distribution's package
manager. Podman runs without a daemon. To use it, verify access and select it:

```bash
podman info
export CONTAINER_ENGINE=podman
```

To use Docker, start its service, verify that the current user can access it,
and leave `CONTAINER_ENGINE` unset (Docker is the default):

```bash
sudo systemctl start docker
docker info
unset CONTAINER_ENGINE
```

#### Run the comparison

The remaining commands are the same on macOS and Linux. From the repository
root, select the previous and candidate release files:

```bash
previous_release=releases/2026-08-11T17:36:11/images.json
candidate_release=releases/2026-09-08T16:26:05/images.json
```

Run the comparison. The script derives the policy images, candidate CLI image,
test manifest, expectations, and report location automatically:

```bash
./policy-behavior/compare-policy-behavior.sh "$previous_release" "$candidate_release"
```

Use command-line options instead of environment variables when desired:

```bash
./policy-behavior/compare-policy-behavior.sh \
  --container-engine podman \
  --tests policy-behavior/policy-behavior-tests.json \
  --report policy-behavior/policy-behavior-report.md \
  "$previous_release" "$candidate_release"
```

View all arguments and defaults with:

```bash
./policy-behavior/compare-policy-behavior.sh --help
```

The command prints the report and writes it to
`policy-behavior/policy-behavior-report.md` by default. It
returns zero only when every sentinel rule triggers and the observed release
delta matches `policyBehavior.expectedChanges` in the candidate `images.json`.
An unexpected added or removed rule, or a missing sentinel rule, returns a
non-zero status. The script passes `--allow-past-effective-time` so a release's
pinned evaluation time remains reproducible when the comparison is rerun later.

The comparison script's isolated tests require
[ShellSpec](https://shellspec.info/). Run them with:

```bash
shellspec policy-behavior/compare_policy_behavior_spec.sh
```

### Add a policy input fixture

1. Add the synthetic SLSA provenance or SBOM input under
   `policy-behavior/policy-inputs/`. Wrap attestations in an `attestations`
   array, matching the input shape used by the release-policy Rego tests.
2. Add a case to `policy-behavior/policy-behavior-tests.json` with its input
   path, collection,
   optional `ruleData` or data sources, and the rule codes it must trigger in
   `expectedRules`. Prefer an exact package or rule in `include` for a focused
   test; reserve collections such as `@redhat` for integration coverage.
3. Prefer the suite-wide `rhtap-ec-policy` data source used by the deployed
   configuration. If fixture-specific data is essential, put it under
   `policy-behavior/policy-data/` and refer to it as
   `file::/policy-tests/policy-data/...`;
   `/policy-tests` is the read-only mount used inside the CLI container.
4. Run the local comparison. If the reported release delta is intentional,
   copy its rule codes into the candidate release's
   `policyBehavior.expectedChanges` entry for that test.

The 2026-09-08 candidate adds three rules that validate shared policy or rule
data rather than values in an attestation. With the current `rhtap-ec-policy`
data, `buildah_build_task.disallowed_platform_patterns_pattern` produces a
warning in the broad `@redhat` fixture. The configured values already satisfy
`git_branch.allowed_target_branch_patterns_format` and
`rpm_build_deps.allowed_rpm_build_dependency_sources_format`, so those two
rules do not currently produce warnings and the suite does not fabricate
invalid data to activate them.

The `tasks.required_test_tasks_found` and
`tasks.future_required_test_tasks_found` rules are not currently active because
`rhtap-ec-policy` does not provide the `required-test-tasks` data key. The suite
does not fabricate that key; these rules will start producing a release delta
when the deployed data source enables them.

`sbom.signature_verification` cannot be triggered by a checked-in provenance or
SBOM attestation. It reports a failure from the `ec.oci` and `ec.sigstore`
built-ins while discovering an SBOM attached to an image. Covering that rule
requires an OCI-registry integration fixture containing an SBOM referrer or tag
whose signature fails verification.

The check fails for an unacknowledged change. If a change is intentional, add
the reported codes to the candidate release's `images.json` under the test
name. The release generator also records `effectiveTime`, keeping results with
future enforcement dates reproducible. For example:

```json
"policyBehavior": {
  "effectiveTime": "2026-09-08T16:26:05Z",
  "expectedChanges": {
    "insecure-buildah-parameters": {
      "addedViolations": [],
      "removedViolations": [],
      "addedWarnings": ["package.rule_name"],
      "removedWarnings": []
    }
  }
}
```
