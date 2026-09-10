# Policy behavior comparison

- Previous policy: `quay.io/conforma/release-policy@sha256:ee5c3a020c9545eca738ed87198af0b235463069b2d72c5dba609364a83321d2`
- Candidate policy: `quay.io/conforma/release-policy@sha256:10de4ff888f9d054baeaa15c528ff74118bfd3c99ed0e5fc0ac24e72e83e01dc`
- Conforma CLI: `quay.io/conforma/cli@sha256:f19ee80ccf91370136ad865ee8c79a9adee944b998183a6a2db5049fc0f448c2`
- Effective time: `2026-09-08T16:26:05Z`

## How to read this report

- **Sentinel rules** verify that each fixture still exercises its intended
  rules. **Expected** lists the rules the candidate must trigger. **Missing
  from candidate** lists expected rules that did not trigger.
- **Change** compares the candidate policy with the previous policy.
  **Expected rule codes** are intentional release changes declared in the
  candidate release's `policyBehavior.expectedChanges` configuration.
  **Actual rule codes** are the changes observed by running both policies.
- An em dash (—) means none. A test passes only when no sentinel rule is
  missing and every observed change exactly matches the declared change.

## insecure-buildah-parameters: PASS

Input: `policy-inputs/insecure-buildah-parameters.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `buildah_build_task.add_capabilities_param`<br>`buildah_build_task.buildah_uses_local_dockerfile`<br>`buildah_build_task.privileged_nested_param` | — |
| warnings | `buildah_build_task.disallowed_platform_patterns_pattern` | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | `buildah_build_task.disallowed_platform_patterns_pattern` | `buildah_build_task.disallowed_platform_patterns_pattern` |
| Removed warnings | — | — |

## non-hermetic-build: PASS

Input: `policy-inputs/non-hermetic-build.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `hermetic_task.hermetic` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## permissive-prefetch: PASS

Input: `policy-inputs/permissive-prefetch.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `prefetch_dependencies.mode_not_permissive`<br>`prefetch_dependencies.package_registry_proxy_enabled` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## invalid-slsa-v1-materials: PASS

Input: `policy-inputs/invalid-slsa-v1-materials.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `slsa_source_version_controlled.materials_include_git_sha`<br>`slsa_source_version_controlled.materials_uri_is_git_repo` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## unpinned-rpm-ostree-builder: PASS

Input: `policy-inputs/unpinned-rpm-ostree-builder.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `rpm_ostree_task.builder_image_param` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## failed-pipeline-tasks: PASS

Input: `policy-inputs/failed-pipeline-tasks.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `tasks.successful_pipeline_tasks`<br>`tasks.pinned_task_refs` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## unexpected-builder-id: PASS

Input: `policy-inputs/unexpected-builder-id.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `slsa_build_build_service.slsa_builder_id_accepted` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## source-reference-mismatch: PASS

Input: `policy-inputs/source-reference-mismatch.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `provenance_materials.git_clone_source_matches_provenance`<br>`slsa_source_correlated.expected_source_code_reference` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## invalid-test-results: PASS

Input: `policy-inputs/invalid-test-results.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `test.no_failed_tests`<br>`test.test_results_known` | — |
| warnings | `test.no_test_warnings` | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## empty-spdx-sbom: PASS

Input: `policy-inputs/empty-spdx-sbom.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `sbom_spdx.contains_packages`<br>`sbom_spdx.contains_files` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## unsupported-cyclonedx-version: PASS

Input: `policy-inputs/unsupported-cyclonedx-version.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `sbom_cyclonedx.cdx_supported_version` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## invalid-rpm-pipeline: PASS

Input: `policy-inputs/invalid-rpm-pipeline.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `rpm_pipeline.invalid_pipeline` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## invalid-rhtap-multi-ci: PASS

Input: `policy-inputs/invalid-rhtap-multi-ci.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `rhtap_multi_ci.attestation_format` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## unsafe-external-parameters: PASS

Input: `policy-inputs/unsafe-external-parameters.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `external_parameters.pipeline_run_params`<br>`external_parameters.restrict_shared_volumes` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

## unsafe-pre-build-script: PASS

Input: `policy-inputs/unsafe-pre-build-script.json`

| Sentinel rules | Expected | Missing from candidate |
|---|---|---|
| violations | `pre_build_script_task.pre_build_script_task_runner_image_allowed`<br>`pre_build_script_task.valid_pre_build_script_task_runner_image_ref` | — |
| warnings | — | — |

| Change | Expected rule codes | Actual rule codes |
|---|---|---|
| Added violations | — | — |
| Removed violations | — | — |
| Added warnings | — | — |
| Removed warnings | — | — |

