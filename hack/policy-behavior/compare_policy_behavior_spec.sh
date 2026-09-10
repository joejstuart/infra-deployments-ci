Describe "compare-policy-behavior.sh"
  SCRIPT="./policy-behavior/compare-policy-behavior.sh"

  setup() {
    setup_tmpdir
    export CONTAINER_ENGINE="mock-container"

    cat > "${MOCK_BIN}/mock-container" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
echo "$args" > "${MOCK_RESULTS}/args.txt"
if [[ "$args" == *"sha256:1"* ]]; then
  cat "${MOCK_RESULTS}/before.json"
else
  cat "${MOCK_RESULTS}/after.json"
fi
EOF
    chmod +x "${MOCK_BIN}/mock-container"
    export PATH="${MOCK_BIN}:${PATH}"
    export MOCK_RESULTS="${TMPDIR}/results"
    mkdir -p "$MOCK_RESULTS"

    cat > "${TMPDIR}/tests.json" <<'EOF'
{
  "tests": [{
    "name": "fixture",
    "input": "input.json",
    "expectedRules": {
      "violations": ["new.deny"],
      "warnings": ["new.warn"]
    }
  }]
}
EOF
    echo '{"attestations":[]}' > "${TMPDIR}/input.json"

    cat > "${TMPDIR}/before-release.json" <<'EOF'
{
  "policy": [{
    "image": "quay.io/conforma/release-policy",
    "digest": "sha256:1"
  }]
}
EOF

    cat > "${TMPDIR}/candidate-release.json" <<'EOF'
{
  "policy": [{
    "image": "quay.io/conforma/release-policy",
    "digest": "sha256:2"
  }],
  "components": [{
    "image": "quay.io/conforma/cli",
    "digest": "sha256:3"
  }],
  "policyBehavior": {
    "effectiveTime": "2026-09-08T16:26:05Z",
    "expectedChanges": {
      "fixture": {
        "addedViolations": ["new.deny"],
        "removedViolations": ["old.deny"],
        "addedWarnings": ["new.warn"],
        "removedWarnings": []
      }
    }
  }
}
EOF

    cat > "${MOCK_RESULTS}/before.json" <<'EOF'
{"filepaths":[{"violations":[{"metadata":{"code":"old.deny"}}],"warnings":[{"metadata":{"code":"existing.warn"}}]}]}
EOF
    cat > "${MOCK_RESULTS}/after.json" <<'EOF'
{"filepaths":[{"violations":[{"metadata":{"code":"new.deny"}}],"warnings":[{"metadata":{"code":"existing.warn"}},{"metadata":{"code":"new.warn"}}]}]}
EOF
  }

  cleanup() {
    cleanup_tmpdir
  }

  Before "setup"
  After "cleanup"

  It "shows concise help"
    When run script "$SCRIPT" --help
    The status should be success
    The output should include "<previous-images.json> <candidate-images.json>"
    The output should include "--container-engine CMD"
  End

  It "explains missing arguments without a shell expansion error"
    When run script "$SCRIPT"
    The status should be failure
    The stderr should include "ERROR: Provide the previous and candidate images.json files"
    The stderr should include "Usage:"
  End

  It "passes and reports expected rule changes"
    When run script "$SCRIPT" --tests "${TMPDIR}/tests.json" --report "${TMPDIR}/report.md" "${TMPDIR}/before-release.json" "${TMPDIR}/candidate-release.json"
    The status should be success
    The output should include "fixture: PASS"
    The stderr should include "Comparing policy behavior for fixture"
    The contents of file "${TMPDIR}/report.md" should include "new.deny"
    The contents of file "${TMPDIR}/report.md" should include "old.deny"
    The contents of file "${TMPDIR}/report.md" should include "2026-09-08T16:26:05Z"
    The contents of file "${TMPDIR}/report.md" should include "How to read this report"
    The contents of file "${TMPDIR}/report.md" should include "An em dash (—) means none"
    The contents of file "${TMPDIR}/report.md" should include "Added warnings"
    The contents of file "${MOCK_RESULTS}/args.txt" should include "validate input /policy-tests/input.json"
  End

  It "fails when an unacknowledged rule starts triggering"
    jq '.policyBehavior.expectedChanges.fixture = {}' \
      "${TMPDIR}/candidate-release.json" > "${TMPDIR}/candidate-unacknowledged.json"
    When run script "$SCRIPT" --tests "${TMPDIR}/tests.json" --report "${TMPDIR}/report.md" "${TMPDIR}/before-release.json" "${TMPDIR}/candidate-unacknowledged.json"
    The status should be failure
    The output should include "fixture: FAIL"
    The stderr should include "does not match expected changes or sentinel rules"
  End

  It "fails when a fixture no longer triggers a sentinel rule"
    jq '.tests[0].expectedRules.violations += ["missing.deny"]' \
      "${TMPDIR}/tests.json" > "${TMPDIR}/tests-with-missing-rule.json"
    cp "${TMPDIR}/input.json" "${TMPDIR}/input-copy.json"
    jq '.tests[0].input = "input-copy.json"' \
      "${TMPDIR}/tests-with-missing-rule.json" > "${TMPDIR}/tests-final.json"
    When run script "$SCRIPT" --tests "${TMPDIR}/tests-final.json" --report "${TMPDIR}/report.md" "${TMPDIR}/before-release.json" "${TMPDIR}/candidate-release.json"
    The status should be failure
    The output should include "missing.deny"
    The output should include "fixture: FAIL"
    The stderr should include "does not match expected changes or sentinel rules"
  End

  It "rejects invalid ec output"
    echo "not json" > "${MOCK_RESULTS}/after.json"
    When run script "$SCRIPT" --tests "${TMPDIR}/tests.json" --report "${TMPDIR}/report.md" "${TMPDIR}/before-release.json" "${TMPDIR}/candidate-release.json"
    The status should be failure
    The stderr should include "did not produce a valid input report"
  End
End
