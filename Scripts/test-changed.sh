#!/bin/bash
#
# Runs the tests that the current diff can plausibly break, instead of all 31.
#
#   Scripts/test-changed.sh              # vs working tree + staged
#   Scripts/test-changed.sh --base main  # everything since a ref
#   Scripts/test-changed.sh --full       # the whole suite anyway
#   Scripts/test-changed.sh --no-build   # reuse the last build (test-without-building)
#
# Why this exists: the UI suite is 31 tests at ~19s each, ~590s, and roughly two
# thirds of that is the prologue every test pays — launch, four onboarding steps,
# reachDashboard. A one-file change does not need to buy that 31 times.
#
# **Selection is a heuristic and it can miss things.** That is not a reason to
# skip it, but it is the reason for the SHARED list below: anything that many
# screens draw goes to the full suite, no exceptions. The example this repo
# already paid for is HFBackChip — a change to one shared control in
# DesignSystem/ that could have broken the header of every screen in the app, and
# whose bug (a dead 6pt margin around the tap target) no single feature test would
# have caught. Selection is for iterating; **run the full suite before you
# commit.**
#
# The Domain suite always runs: 102 tests in about a hundredth of a second is not
# worth deciding about.

set -euo pipefail
cd "$(dirname "$0")/.."

DEST='platform=iOS Simulator,name=iPhone 17 Pro'
BASE=""
FORCE_FULL=0
BUILD_ACTION="test"
DRY_RUN=0
FILES_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) FORCE_FULL=1; shift ;;
    --base) BASE="$2"; shift 2 ;;
    --no-build) BUILD_ACTION="test-without-building"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    # Ask the selector what it would run for a given list, without touching git.
    # Mostly so the narrow branch can be exercised — an untested branch of a
    # test-selection script is the worst place to be wrong.
    --files) FILES_OVERRIDE="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# Untracked files are listed too. `git diff` does not see a file that has never
# been added, so without this a brand-new view — the commonest kind of change
# there is — would select no tests at all and the run would look clean.
UNTRACKED="$(git ls-files --others --exclude-standard)"
if [[ -n "$FILES_OVERRIDE" ]]; then
  CHANGED="$(echo "$FILES_OVERRIDE" | tr ' ' '\n')"
elif [[ -n "$BASE" ]]; then
  CHANGED="$(git diff --name-only "$BASE"...HEAD; git diff --name-only; git diff --cached --name-only; echo "$UNTRACKED")"
else
  CHANGED="$(git diff --name-only; git diff --cached --name-only; echo "$UNTRACKED")"
fi
CHANGED="$(echo "$CHANGED" | sort -u | sed '/^$/d')"
[[ -n "$FILES_OVERRIDE" ]] && echo "(--files: bỏ qua git, dùng danh sách được truyền vào)"

if [[ -z "$CHANGED" ]]; then
  echo "no changes — nothing to test"
  exit 0
fi

echo "changed:"
echo "$CHANGED" | sed 's/^/  /'
echo

# Domain first, always. It needs no simulator and costs nothing.
if [[ $DRY_RUN == 0 ]]; then
  echo "== Domain =="
  swift test 2>&1 | tail -1
  echo
fi

# Nothing here reaches the built app: specs, docs, and the dev scripts. They are
# skipped outright rather than falling into the catch-all, which sent a spec edit
# to a ten-minute run.
#
# `Scripts/` is safe even though `make-brand-images.swift` generates artwork,
# because the app only changes when that script is *run* — and what it writes is
# App/Resources/, which the shared list below already catches.
IGNORED='^(design_handoff[^/]*/|Scripts/|build/|\.gitignore$|[^/]*\.md$|.*/[^/]*\.md$)'

# Anything here can break a screen the diff never mentions, so it buys the lot.
# Config/ and the project file are in the list because they change the bundle
# itself — Info.plist keys, the launch storyboard, the asset catalog.
SHARED='^(App/Presentation/(DesignSystem|Welcome)/|App/(DependencyContainer|HeathFirstApp)\.swift|App/Presentation/(RootView|MainTabView|DisplayCopy|DisplayNames|BMILine|MealPhotoGrid)\.swift|App/Data/|App/Resources/|Config/|HeathFirst\.xcodeproj/|Package\.swift)'

# Feature area → the tests that walk it. A path not listed here is unknown, and
# unknown means the full suite.
map_tests() {
  case "$1" in
    App/Presentation/Scan/*)
      echo "testScanFlowProposesAMealAndRefusesToSaveUnresolvedItems
testScanReviewShowsThePhotoThatWasAnalysed
testLeavingTheScanReviewAsksBeforeDiscarding" ;;
    App/Presentation/MealHistory/*)
      echo "testHistoryListsTheDayAMealWasLoggedOn
testHistoryRefreshesAfterRemovingOneFood
testHistoryTimelineOpensADay
testHistoryTimelineKeepsItsScrollPositionAcrossADay
testHistoryTimelinePagesToOlderMonths
testHistoryTimelineRowsSurviveAccessibilitySizes
testHistorySearchFindsAMealTypedWithoutDiacritics
testHistoryFilterChipNarrowsToMealsWithAPhoto
testHistoryEmptyStateOffersBothWaysToLogAMeal
testDeletingAMealFromTheDaySheetKeepsItsConfirmation" ;;
    App/Presentation/Dashboard/*)
      echo "testLoggingAMealMovesTheDashboard
testSavingAMealConfirmsWithAToast
testCrossingSeventyPercentShowsTheInformMessage
testExceedingTheTargetIsReportedNeutrally" ;;
    App/Presentation/MealEntry/*)
      echo "testLoggingAMealMovesTheDashboard
testSavingAMealConfirmsWithAToast
testAddingEditingAndRemovingAFoodKeepsTheTotalsInStep" ;;
    App/Presentation/MealDetail/*)
      echo "testALoggedMealOpensItsDetailAndCanBeDeleted
testAddingEditingAndRemovingAFoodKeepsTheTotalsInStep
testDeletingAMealFromTheDaySheetKeepsItsConfirmation" ;;
    App/Presentation/Onboarding/*)
      echo "testOnboardingWalksFourStepsAndProducesTargets
testGoingBackReturnsToTheEarlierStep
testOutOfRangeWeightBlocksTheStepAndSaysWhy
testProfileShowsTheDerivedTargetAndOpensEditing" ;;
    App/Presentation/Health/*)
      echo "testAppleHealthScreenFollowsTheLastStep
testAppleHealthCanReturnToTheGoalStep" ;;
    App/Presentation/Insights/*)
      echo "testInsightsReportTheWeekAndTheWeightRecordedAtOnboarding
testInsightsReportHowOftenTheScanNeededCorrecting
testInsightsOmitTheCorrectionCellWithNothingScanned" ;;
    App/Presentation/Profile/*)
      echo "testProfileShowsTheDerivedTargetAndOpensEditing
testNotificationSwitchesStayInertUntilTheSystemHasBeenAsked
testNotificationSwitchesAreLiveOncePermissionIsGranted" ;;
    App/Notifications/*)
      echo "testNotificationSwitchesStayInertUntilTheSystemHasBeenAsked
testNotificationSwitchesAreLiveOncePermissionIsGranted" ;;
    # The splash does not run under -uiTesting — it would put an 860ms overlay in
    # front of all 31 tests — so no UI test covers it. Saying "none" out loud is
    # the point: silently mapping it to zero tests would read as "covered".
    App/Presentation/Splash/*) echo "__NONE__" ;;
    AppUITests/*) echo "__FULL__" ;;
    Sources/Domain/*|Tests/DomainTests/*) echo "" ;;   # Domain suite already ran
    *) echo "__FULL__" ;;
  esac
}

FULL=$FORCE_FULL
TESTS=""
UNCOVERED=""

IGNORED_COUNT=0
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  if [[ "$file" =~ $IGNORED ]]; then
    IGNORED_COUNT=$((IGNORED_COUNT + 1))
    continue
  fi
  if [[ "$file" =~ $SHARED ]]; then
    echo "shared: $file → cả bộ"
    FULL=1
    continue
  fi
  result="$(map_tests "$file")"
  case "$result" in
    __FULL__) echo "chưa map: $file → cả bộ"; FULL=1 ;;
    __NONE__) UNCOVERED="$UNCOVERED$file"$'\n' ;;
    "") ;;
    *) TESTS="$TESTS$result"$'\n' ;;
  esac
done <<< "$CHANGED"

if [[ $IGNORED_COUNT -gt 0 ]]; then
  echo "bỏ qua $IGNORED_COUNT file không vào app (spec, docs, Scripts/)"
fi

if [[ -n "$UNCOVERED" ]]; then
  echo
  echo "không có UI test nào phủ (phải kiểm bằng mắt):"
  echo "$UNCOVERED" | sed '/^$/d' | sed 's/^/  /'
fi

TESTS="$(echo "$TESTS" | sort -u | sed '/^$/d')"

if [[ $FULL == 0 && -z "$TESTS" ]]; then
  echo
  echo "không có UI test nào cần chạy."
  exit 0
fi

echo
ARGS=()
if [[ $FULL == 1 ]]; then
  echo "== UI: cả bộ (31 test, ~590s) =="
else
  COUNT=$(echo "$TESTS" | wc -l | tr -d ' ')
  echo "== UI: $COUNT test (~$((COUNT * 19))s), bỏ qua $((31 - COUNT)) =="
  echo "$TESTS" | sed 's/^/  /'
  while IFS= read -r t; do
    ARGS+=("-only-testing:HeathFirstUITests/Phase1FlowTests/$t")
  done <<< "$TESTS"
fi
echo

if [[ $DRY_RUN == 1 ]]; then
  echo "(--dry-run: dừng ở đây, không chạy gì)"
  exit 0
fi

LOG="${TMPDIR:-/tmp}/heathfirst-test-changed.log"
set +e
# `${ARGS[@]+...}` rather than `"${ARGS[@]}"`: `ARGS` is empty on the
# full-suite path, and bash 3.2 — which is the bash on macOS — treats an
# empty array under `set -u` as unbound and aborts. That made the one run
# this script tells you to do before committing the one run it could not do,
# and it failed *after* announcing the suite.
xcodebuild -scheme HeathFirst -destination "$DEST" ${ARGS[@]+"${ARGS[@]}"} "$BUILD_ACTION" > "$LOG" 2>&1
STATUS=$?
set -e

grep -E "^Test Case .* (passed|failed) \(|error: -\[|\*\* TEST" "$LOG" | sed 's/^/  /' || true
echo
echo "log: $LOG"

if [[ $FULL == 0 && $STATUS == 0 ]]; then
  echo
  echo "Đây là tập con. Chạy Scripts/test-changed.sh --full trước khi commit."
fi
exit $STATUS
