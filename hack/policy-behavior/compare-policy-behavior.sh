#!/usr/bin/env bash
# Copyright The Conforma Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

# Compare the warnings and violations produced by two release-policy bundles
# when they evaluate checked-in SLSA provenance inputs. The ec CLI is run from
# the supplied container image so both evaluations use the same implementation.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
    cat <<EOF
Usage:
  $(basename "$0") [options] <previous-images.json> <candidate-images.json>

Compare release-policy behavior between two releases. The script reads the
policy and CLI image digests from each release's images.json, runs every test
in the test manifest, and writes a Markdown report.

Arguments:
  previous-images.json   images.json from the currently deployed release
  candidate-images.json  images.json from the release being evaluated

Options:
  --tests FILE           Test manifest (default: ${SCRIPT_DIR}/policy-behavior-tests.json)
  --report FILE          Markdown output (default: ${SCRIPT_DIR}/policy-behavior-report.md)
  --container-engine CMD Container engine command (default: \$CONTAINER_ENGINE or docker)
  -h, --help             Show this help

Examples:
  ./policy-behavior/compare-policy-behavior.sh \\
    releases/2026-08-11T17:36:11/images.json \\
    releases/2026-09-08T16:26:05/images.json

  ./policy-behavior/compare-policy-behavior.sh --container-engine podman \\
    releases/previous/images.json releases/candidate/images.json
EOF
}

die() {
    echo "ERROR: $*" >&2
    echo >&2
    usage >&2
    exit 2
}

TESTS_FILE="${SCRIPT_DIR}/policy-behavior-tests.json"
REPORT_FILE="${SCRIPT_DIR}/policy-behavior-report.md"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-docker}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tests)
            [[ $# -ge 2 ]] || die "--tests requires a file path"
            TESTS_FILE="$2"
            shift 2
            ;;
        --report)
            [[ $# -ge 2 ]] || die "--report requires a file path"
            REPORT_FILE="$2"
            shift 2
            ;;
        --container-engine)
            [[ $# -ge 2 ]] || die "--container-engine requires a command"
            CONTAINER_ENGINE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            break
            ;;
    esac
done

[[ $# -eq 2 ]] || die "Provide the previous and candidate images.json files"

PREVIOUS_RELEASE_FILE="$1"
CANDIDATE_RELEASE_FILE="$2"
EXPECTATIONS_FILE="$CANDIDATE_RELEASE_FILE"

for release_file in "$PREVIOUS_RELEASE_FILE" "$CANDIDATE_RELEASE_FILE"; do
    [[ -f "$release_file" ]] || die "Release file does not exist: ${release_file}"
done

for command in jq "$CONTAINER_ENGINE"; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: ${command}" >&2
        exit 1
    fi
done

release_policy_ref() {
    jq -er '
        .policy[]
        | select(.image == "quay.io/conforma/release-policy")
        | "\(.image)@\(.digest)"
    ' "$1"
}

candidate_cli_ref() {
    jq -er '
        .components[]
        | select(.image == "quay.io/conforma/cli")
        | "\(.image)@\(.digest)"
    ' "$1"
}

BEFORE_POLICY=$(release_policy_ref "$PREVIOUS_RELEASE_FILE") || \
    die "Previous release is missing quay.io/conforma/release-policy: ${PREVIOUS_RELEASE_FILE}"
AFTER_POLICY=$(release_policy_ref "$CANDIDATE_RELEASE_FILE") || \
    die "Candidate release is missing quay.io/conforma/release-policy: ${CANDIDATE_RELEASE_FILE}"
EC_IMAGE=$(candidate_cli_ref "$CANDIDATE_RELEASE_FILE") || \
    die "Candidate release is missing quay.io/conforma/cli: ${CANDIDATE_RELEASE_FILE}"

if ! jq -e '.tests | type == "array" and length > 0' "$TESTS_FILE" >/dev/null; then
    echo "ERROR: ${TESTS_FILE} must contain a non-empty tests array" >&2
    exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

effective_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [[ -n "$EXPECTATIONS_FILE" ]]; then
    configured_effective_time=$(jq -r '.policyBehavior.effectiveTime // empty' "$EXPECTATIONS_FILE")
    if [[ -n "$configured_effective_time" ]]; then
        effective_time="$configured_effective_time"
    fi
fi

mkdir -p "$(dirname "$REPORT_FILE")"
cat > "$REPORT_FILE" <<EOF
# Policy behavior comparison

- Previous policy: \`${BEFORE_POLICY}\`
- Candidate policy: \`${AFTER_POLICY}\`
- Conforma CLI: \`${EC_IMAGE}\`
- Effective time: \`${effective_time}\`

## How to read this report

- **Sentinel rules** verify that each fixture still exercises its intended
  rules. **Expected** lists the rules the candidate must trigger. **Missing
  from candidate** lists expected rules that did not trigger.
- **Change** compares the candidate policy with the previous policy.
  **Expected rule codes** are intentional release changes declared in the
  candidate release's \`policyBehavior.expectedChanges\` configuration.
  **Actual rule codes** are the changes observed by running both policies.
- An em dash (—) means none. A test passes only when no sentinel rule is
  missing and every observed change exactly matches the declared change.

EOF

failed=0

result_codes() {
    local result_file="$1"
    local result_type="$2"
    jq -c --arg result_type "$result_type" '
        [.filepaths[]?[$result_type][]?.metadata.code // empty] | unique | sort
    ' "$result_file"
}

array_difference() {
    jq -cn --argjson left "$1" --argjson right "$2" \
        '$left - $right | unique | sort'
}

run_validation() {
    local test_json="$1"
    local policy_ref="$2"
    local output_file="$3"
    local input_path input_relative policy_config tests_root

    tests_root=$(cd "$(dirname "$TESTS_FILE")" && pwd)
    input_relative=$(jq -r '.input' <<< "$test_json")
    input_path="${tests_root}/${input_relative}"
    if [[ ! -f "$input_path" ]]; then
        echo "ERROR: Policy input does not exist: ${input_path}" >&2
        return 1
    fi
    policy_config=$(jq -c --arg policy "oci::${policy_ref}" '
        {
          sources: [{
            policy: [$policy],
            data: (.data // []),
            config: {
              include: (.include // []),
              exclude: (.exclude // [])
            },
            ruleData: (.ruleData // {})
          }]
        }
    ' <<< "$test_json")

    # Policy violations produce a non-zero ec exit status. A valid JSON report
    # is therefore the success condition; command/configuration failures do not
    # produce one and are rejected below.
    "$CONTAINER_ENGINE" run --rm \
        --volume "${tests_root}:/policy-tests:ro" \
        "$EC_IMAGE" validate input "/policy-tests/${input_relative}" \
        --policy "$policy_config" \
        --effective-time "$effective_time" \
        --allow-past-effective-time \
        --show-warnings \
        --strict=false \
        --output json > "$output_file" || true

    if ! jq -e '.filepaths | type == "array"' "$output_file" >/dev/null 2>&1; then
        echo "ERROR: ec did not produce a valid input report for ${input_path} with ${policy_ref}" >&2
        return 1
    fi
}

while IFS= read -r test_json; do
    name=$(jq -r '.name' <<< "$test_json")
    safe_name=$(printf '%s' "$name" | tr -cs '[:alnum:]_.-' '_')
    before_result="${WORK_DIR}/${safe_name}-before.json"
    after_result="${WORK_DIR}/${safe_name}-after.json"

    echo "Comparing policy behavior for ${name}" >&2
    run_validation "$test_json" "$BEFORE_POLICY" "$before_result"
    run_validation "$test_json" "$AFTER_POLICY" "$after_result"

    before_violations=$(result_codes "$before_result" violations)
    after_violations=$(result_codes "$after_result" violations)
    before_warnings=$(result_codes "$before_result" warnings)
    after_warnings=$(result_codes "$after_result" warnings)

    added_violations=$(array_difference "$after_violations" "$before_violations")
    removed_violations=$(array_difference "$before_violations" "$after_violations")
    added_warnings=$(array_difference "$after_warnings" "$before_warnings")
    removed_warnings=$(array_difference "$before_warnings" "$after_warnings")

    expected_violations=$(jq -c '.expectedRules.violations // [] | unique | sort' <<< "$test_json")
    expected_warnings=$(jq -c '.expectedRules.warnings // [] | unique | sort' <<< "$test_json")
    missing_violations=$(array_difference "$expected_violations" "$after_violations")
    missing_warnings=$(array_difference "$expected_warnings" "$after_warnings")

    actual=$(jq -cn \
        --argjson addedViolations "$added_violations" \
        --argjson removedViolations "$removed_violations" \
        --argjson addedWarnings "$added_warnings" \
        --argjson removedWarnings "$removed_warnings" \
        '{addedViolations: $addedViolations, removedViolations: $removedViolations, addedWarnings: $addedWarnings, removedWarnings: $removedWarnings}')
    if [[ -n "$EXPECTATIONS_FILE" ]]; then
        expected=$(jq -c --arg name "$name" '
            .policyBehavior.expectedChanges[$name] //
            {addedViolations: [], removedViolations: [], addedWarnings: [], removedWarnings: []}
        ' "$EXPECTATIONS_FILE")
    else
        expected=$(jq -c '
            .expectedChanges //
            {addedViolations: [], removedViolations: [], addedWarnings: [], removedWarnings: []}
        ' <<< "$test_json")
    fi

    if jq -en \
        --argjson actual "$actual" \
        --argjson expected "$expected" \
        --argjson missingViolations "$missing_violations" \
        --argjson missingWarnings "$missing_warnings" \
        '$actual == $expected and ($missingViolations | length == 0) and ($missingWarnings | length == 0)' >/dev/null; then
        status="PASS"
    else
        status="FAIL"
        failed=1
    fi

    {
        echo "## ${name}: ${status}"
        echo
        echo "Input: \`$(jq -r '.input' <<< "$test_json")\`"
        echo
        echo '| Sentinel rules | Expected | Missing from candidate |'
        echo '|---|---|---|'
        for result_type in violations warnings; do
            expected_rules=$(jq -r --arg result_type "$result_type" '.expectedRules[$result_type] // [] | if length == 0 then "—" else map("`" + . + "`") | join("<br>") end' <<< "$test_json")
            if [[ "$result_type" == "violations" ]]; then
                missing_rules="$missing_violations"
            else
                missing_rules="$missing_warnings"
            fi
            missing_rules_text=$(jq -r 'if length == 0 then "—" else map("`" + . + "`") | join("<br>") end' <<< "$missing_rules")
            echo "| ${result_type} | ${expected_rules} | ${missing_rules_text} |"
        done
        echo
        echo '| Change | Expected rule codes | Actual rule codes |'
        echo '|---|---|---|'
        for field in addedViolations removedViolations addedWarnings removedWarnings; do
            case "$field" in
                addedViolations) label="Added violations" ;;
                removedViolations) label="Removed violations" ;;
                addedWarnings) label="Added warnings" ;;
                removedWarnings) label="Removed warnings" ;;
            esac
            expected_text=$(jq -r --arg field "$field" '.[$field] | if length == 0 then "—" else map("`" + . + "`") | join("<br>") end' <<< "$expected")
            actual_text=$(jq -r --arg field "$field" '.[$field] | if length == 0 then "—" else map("`" + . + "`") | join("<br>") end' <<< "$actual")
            echo "| ${label} | ${expected_text} | ${actual_text} |"
        done
        echo
    } >> "$REPORT_FILE"
done < <(jq -c '
    . as $suite |
    .tests[] |
    .data = ((($suite.data // []) + (.data // [])) | unique)
' "$TESTS_FILE")

cat "$REPORT_FILE"

if [[ "$failed" -ne 0 ]]; then
    echo "ERROR: Candidate policy behavior does not match expected changes or sentinel rules" >&2
    exit 1
fi
