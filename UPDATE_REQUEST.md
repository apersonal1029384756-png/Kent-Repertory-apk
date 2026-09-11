# Kent Repertory App — Update Request

Update the existing Kent Repertory Android application.

IMPORTANT:
- Do NOT replace, reduce, merge, or alter the existing repertory database.
- Preserve all existing repertory data, rubrics, grades, and remedy abbreviations.
- Preserve the existing package/application ID unless absolutely necessary.
- Make changes to the existing application.
- Do not make unrelated changes.

## 1. APP NAME

Rename the application to:

Kent Repertory

The name shown under the Android launcher icon and in Android application information should be "Kent Repertory".

Do not change the package ID.

## 2. APP IMAGE / ICON

Use the Kent Repertory cover image already present in the project for the appropriate application branding.

Inspect the existing project resources first.

Set the appropriate launcher/app icon and branding image without breaking Android resource requirements.

Do not unnecessarily distort or replace the existing Kent Repertory image.

## 3. FIX BACK NAVIGATION

There is currently a serious bug.

After entering/selecting symptoms, pressing the Android Back button closes the application instead of returning to the previous screen.

Fix the underlying navigation problem.

Required behavior:

- Back from symptom entry/selection returns to the previous screen.
- The application should not close unless the user is actually at the root/home screen.
- Already selected symptoms should not unexpectedly disappear.
- Back navigation must work consistently throughout symptom selection, selected symptoms, repertorial results, and remedy detail.
- Do not create duplicate screens or navigation loops.

Inspect the existing Activity/Fragment/Compose navigation and back-stack implementation and fix the real cause.

## 4. CUMULATIVE SYMPTOM / RUBRIC SELECTION

Change symptom selection so the user can progressively build a case by adding multiple symptoms/rubrics.

The workflow must be:

Select symptom/rubric
→ Add to case
→ Select another symptom/rubric
→ Add to case
→ continue.

Do NOT replace the previous symptom when a new symptom is selected.

Example selected case:

1. Head — Pain — Right
2. Head — Pain — Light, agg.
3. Stomach — Thirst — Frequent, small quantities
4. Mind — Anxiety — Health, about
5. Mind — Restlessness — Night

Display all accumulated rubrics clearly.

The user must be able to:
- Add another rubric.
- View all selected rubrics.
- Remove an individual rubric.
- Continue adding rubrics.
- Navigate backward without unexpectedly losing the case.

Prevent accidental duplicate addition of exactly the same rubric.

## 5. REPERTORIZATION

Repertorization must use ALL selected rubrics together.

Do not repertorize only the most recently selected symptom.

Use the existing repertory database and remedy/rubric relationships.

Preserve the existing repertorial grading/marks.

Do not invent grades.

## 6. REPERTORIAL RESULTS

Display ranked remedies.

Each remedy must show:

REMEDY NAME — MARKS OBTAINED / NUMBER OF SELECTED RUBRICS COVERED

Example:

Arsenicum album — 12 / 5
Phosphorus — 10 / 4
Nux vomica — 9 / 4
Sulphur — 8 / 3

Meaning:

- First number = actual repertorial marks obtained.
- Second number = number of selected rubrics covered.

The marks must be calculated from the existing repertorial grades.

Do not simply give one mark per covered rubric when the database contains different grades.

Sort primarily by total marks obtained while displaying rubric coverage.

## 7. TAP A REMEDY FOR DETAILS

When a user taps a remedy in the results, open a detail screen.

Example:

Arsenicum album

12 marks / 5 of 5 rubrics

Covered rubrics:

✓ Mind — Anxiety — health, about — 3
✓ Mind — Restlessness — night — 2
✓ Stomach — Thirst — frequent, small quantities — 3
✓ Head — Pain — right side — 2
✓ Head — Pain — light, agg. — 2

Total: 12

The exact rubric wording must come from the selected rubrics/database.

For every covered selected rubric, show the actual repertorial grade/marks contributed by that remedy.

Also show:

- Total marks obtained.
- Number of selected rubrics covered.
- Total number of selected rubrics.

## 8. TRANSPARENT CALCULATION

For every remedy:

total marks = sum of the actual repertorial grades for that remedy across all selected rubrics.

rubrics covered = number of selected rubrics for which that remedy has a valid repertory entry.

Only the selected rubrics belonging to the current case should be considered.

Do not alter the underlying repertory grades.

## 9. CASE STATE

Maintain the selected rubric list throughout the repertorization workflow.

Navigation:

Symptom selection
→ Selected symptoms
→ Repertorial results
→ Remedy detail

must preserve the case.

The user must be able to navigate back through these screens without losing selected rubrics.

## 10. UI

Keep the existing visual design where possible.

Provide clear controls such as:

+ Add Symptom/Rubric

Selected Symptoms

Remove

REPERTORIZE

Results should be easy to read on a phone.

Do not redesign unrelated parts of the application.

## 11. ERROR HANDLING

Handle gracefully:

- No symptoms selected → ask the user to add at least one rubric.
- One symptom → repertorize normally.
- Multiple symptoms → combine all.
- Remedy covers none → do not show it as a meaningful result.
- Duplicate rubric → prevent accidental duplicate.
- Empty result → show a useful message rather than crashing.

## 12. DATABASE SAFETY

CRITICAL:

Do NOT:
- delete remedies,
- merge remedy abbreviations,
- reduce the existing remedy list,
- rewrite the repertory database unnecessarily,
- change existing repertorial grades,
- change existing rubric identities.

Only modify data-access/repertorization code if required for cumulative repertorization.

## 13. BUILD AND TEST

After implementation:

1. Build the Android application.
2. Fix compilation errors.
3. Verify the application launches.
4. Verify app name is Kent Repertory.
5. Verify image/icon.
6. Test symptom selection.
7. Add at least 3 different rubrics.
8. Verify all remain in the selected-rubric list.
9. Press Android Back and verify the app does not close.
10. Run repertorization.
11. Verify results show MARKS / RUBRICS COVERED.
12. Tap a remedy.
13. Verify its detail screen lists the exact selected rubrics it covers and marks contributed by each.
14. Navigate back from remedy detail → results → selected rubrics without losing the case.
15. Build the final APK successfully.

## 14. FINAL REPORT

Report:

- Files changed.
- App name change.
- Image/icon change.
- Back-navigation fix.
- Cumulative symptom/rubric functionality.
- Repertorization calculation.
- Results format.
- Remedy-detail rubric coverage.
- Confirmation that the database was preserved.
- Build result.
- APK output path.

Do not make unrelated changes.
