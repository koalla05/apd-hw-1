# Plan

## Scope

Implement the reliable Swift domain logic for `StudyPlanner` preserving the required public API and public test suite:
- Model validation for `StudyItem` (blank title rejection, non-positive estimated minutes check, and title-before-minutes precedence).
- Codable compliance with boundary validation for `StudyItem` (validating fields during decode, defaulting `isCompleted` to `false` when omitted).
- Keyed `StudyPlan` decoding (validating duplicate IDs and sorting deterministically) and top-level JSON-array decoding via `StudyPlan.decode(from data: Data)`.
- Duplicate ID detection reporting the first encountered duplicate ID and deterministic sorting by title ascending, then ID ascending.
- Query methods (`items(in:)`, `incompleteMinutes()`) and idempotent item completion (`markCompleted(id:)`, throwing `unknownID` for missing items).
- Optional bonus: Atomic import merging (`importMerging(_:)`) rejecting duplicate incoming IDs, replacing existing IDs in place, and appending new IDs in ascending order.
- Comprehensive student unit test suite (21 atomic tests following the AAA pattern) in `Tests/StudyPlannerTests/StudyPlannerPublicTests.swift`.

## Acceptance criteria

1. **Validation & Errors**:
   - `StudyItem.init` throws `.blankTitle` when title consists only of whitespaces or newlines.
   - `StudyItem.init` throws `.nonPositiveEstimatedMinutes` when estimated minutes <= 0.
   - Title validation takes precedence over minutes validation when both are invalid.
2. **Codable Boundaries**:
   - Decoding invalid JSON into `StudyItem` throws corresponding validation errors (`.blankTitle`, `.nonPositiveEstimatedMinutes`).
   - Keyed `StudyPlan` decoding validates duplicate IDs and sorts items.
   - `StudyPlan.decode(from data: Data)` successfully decodes top-level JSON arrays (including `Fixtures/study-items.json`) into a valid `StudyPlan`.
3. **Duplicates and Ordering**:
   - Duplicate IDs in `StudyPlan.init(items:)` throw `.duplicateID(id)` reporting the first duplicate encountered.
   - `StudyPlan.items` is sorted by `title` ascending, then `id` ascending.
4. **Queries and Completion**:
   - `items(in category:)` returns only items matching the specified category in their sorted order.
   - `incompleteMinutes()` sums estimated minutes for all items where `isCompleted == false`.
   - `markCompleted(id:)` throws `.unknownID(id)` when ID does not exist.
   - `markCompleted(id:)` is idempotent when called repeatedly on already-completed items.
5. **Bonus — importMerging**:
   - Atomically rejects duplicate incoming IDs without modifying the existing plan.
   - Replaces matching existing items at their current indices.
   - Appends genuinely new items sorted by `id` ascending to the end of the plan.
6. **Test Suite**:
   - Passes all 3 supplied starter tests and at least 6 distinct student-authored tests with `swift test`.

## Implementation steps

1. **Validation & Initial Queries** (`Sources/StudyPlanner/StudyPlanner.swift`):
   - Implemented title trimming and blank check, minutes check (`<= 0`).
   - Implemented `markAsCompleted` on `StudyItem`.
   - Implemented `StudyPlan.init(items:)` duplicate check and sorting (`title`, then `id`).
   - Implemented `items(in:)`, `incompleteMinutes()`, and `markCompleted(id:)`.
2. **Codable Boundaries** (`Sources/StudyPlanner/StudyPlanner.swift`):
   - Added custom `init(from decoder:)` and `encode(to encoder:)` to `StudyItem` to enforce domain validation on decoded data and handle optional `isCompleted`.
   - Added custom `init(from decoder:)` and `encode(to encoder:)` to `StudyPlan` for keyed JSON decoding with validation and sorting.
   - Implemented `StudyPlan.decode(from data: Data)` for top-level JSON array decoding.
3. **Optional Bonus — importMerging** (`Sources/StudyPlanner/StudyPlanner.swift`):
   - Implemented `importMerging(_:)` with upfront incoming duplicate validation for atomicity, in-place replacement of existing items, and sorted appending of new items.
4. **Student Test Suite** (`Tests/StudyPlannerTests/StudyPlannerPublicTests.swift`):
   - Authored 10 thorough tests covering validation precedence, Codable boundaries, duplicate ID reporting, query filtering, idempotent completion, and `importMerging` replacement/appending/atomicity directly in `StudyPlannerPublicTests`.
5. **Verification & Artifacts** (`artifacts/test-run.txt`, `AGENT_WORKLOG.md`):
   - Executed `swift test`, recorded output in `artifacts/test-run.txt`, and documented tool assistance in `AGENT_WORKLOG.md`.

## Risks

- **Codable bypassing validation**: Synthesized `init(from decoder:)` could allow invalid data into models. Mitigated by explicit `init(from decoder:)` delegating to throwing initializer.
- **Title sorting stability**: Items with the same title must be deterministically sorted. Mitigated by using secondary sort key `lhs.id < rhs.id`.
- **Atomicity in importMerging**: Partial mutations if validation fails mid-way. Mitigated by validating incoming duplicate IDs before mutating and applying changes on a temporary array.
- **Sandbox caching issues**: SwiftPM build cache permissions inside sandboxed environments. Mitigated by standard verification command `swift test`.

## `swift test` verification

- **Initial status check**: 3 passed, 0 failures (starter tests).
- **After Task 2 & Bonus implementation**: 3 passed, 0 failures.
- **After student test suite addition**: 24 passed, 0 failures (3 starter + 21 student tests) in `StudyPlannerPublicTests`.
- **Artifact capture run**: 24 passed, 0 failures; recorded to `artifacts/test-run.txt`.
