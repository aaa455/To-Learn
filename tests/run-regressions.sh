#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
# A single module uses the same production model/service implementations as the app.
{
  echo 'import Combine'
  cat LearnFlowApp/LearnFlowApp/Models/WorkflowModel.swift
  cat LearnFlowApp/LearnFlowApp/Models/GoalModel.swift
  cat LearnFlowApp/LearnFlowApp/Models/ReviewModel.swift
  cat LearnFlowApp/LearnFlowApp/Services/AIService.swift
  sed -n '/^class DataManager/,$p' LearnFlowApp/LearnFlowApp/LearnFlowAppApp.swift
  cat LearnFlowApp/LearnFlowApp/Models/TimerModel.swift
  cat tests/RegressionTests.swift
} > "$TEST_DIR/main.swift"
xcrun swiftc "$TEST_DIR/main.swift" -o "$TEST_DIR/regressions"
"$TEST_DIR/regressions"
