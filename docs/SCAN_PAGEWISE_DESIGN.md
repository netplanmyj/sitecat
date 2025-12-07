# Page-wise Full Scan Design (Draft)

## Goals
- Fix pause/resume correctness: resume from the first uncompleted page, stop exactly at the batch boundary (100-page chunks: 1-100, 101-200, ...), respect overall pageLimit/totalPages.
- Make progress reporting stable and single-sourced for UI (no flicker to 0, one progress bar under Start/Continue).
- Reduce blast radius by keeping the existing data model mostly intact; add only minimal fields needed for page-wise checkpoints.

## Non-goals (for this iteration)
- Changing pricing/plan limits.
- Reworking external-link concurrency behavior (keep current caps unless perf requires tuning).
- Moving entitlement enforcement to backend (see TODO #210).

## Data model deltas (incremental, minimal)
- `LinkCheckResult`
  - Add: `pagesCompleted` (int) — number of pages fully processed in this scan chain.
  - Add: `currentBatchStart` (int) — start index (1-based) of the batch that produced this result.
  - Add: `currentBatchEnd` (int) — end index (1-based) of that batch (e.g., 100, 200, ... or totalPages cap).
  - Keep: `newLastScannedPageIndex` — becomes the cursor for resume; set to `pagesCompleted` when not completed, else 0.
  - Keep: `scanCompleted` — true only when all pages are done (or totalPages/pageLimit reached).
- Site
  - Keep existing `lastScannedPageIndex`; semantics unchanged (last completed page index). No schema change needed.

## Service flow (page-wise, batch-aware)
1) **Init**
   - Determine `startIndex = continue ? site.lastScannedPageIndex : 0`.
   - Compute `batchStart = startIndex` (0-based) and `batchEnd = min(totalPages, pageLimit, nextBoundary)` where `nextBoundary` is the next multiple of 100 (exclusive upper bound in code, but for display use inclusive 1-based).
2) **Per-page cycle**
   - For each page in [batchStart, batchEnd):
     - Fetch page, extract links.
     - Validate links with bounded link concurrency.
     - On success of that page, increment `pagesCompleted` and emit progress (`checked = pagesCompleted`, `total = totalPages`).
     - Honor `shouldCancel` between pages to keep stops precise.
3) **Stop/Cancel**
   - Persist result with `pagesCompleted` and `newLastScannedPageIndex = pagesCompleted`.
   - `scanCompleted = false`; `currentBatchEnd` set to the batch boundary (or total cap) that was targeted.
4) **Batch complete (<=100 pages)**
   - When page loop reaches `batchEnd`, set `newLastScannedPageIndex = batchEnd` unless fully done; if fully done (all pages), set to 0 and `scanCompleted = true`.
   - Persist `pagesCompleted` as cumulative for this scan chain (not just the batch) so UI can show total progress.
5) **Resume**
   - `startIndex = site.lastScannedPageIndex` (0-based). Recompute next boundary (e.g., 100->200) and repeat.

## Progress reporting (single source)
- Provider keeps `checked = pagesCompleted`, `total = pagesTotal`. On resume, initialize from cached result/site to avoid 0 flash.
- UI progress bar shows `checked/total` only; no secondary bar inside result cards.
- External-link progress can stay secondary text, not a bar (optional to display beneath main bar).

## UI/UX notes
- Start/Continue enabled only when cooldown is clear and `pagesCompleted < pagesTotal`.
- Stop always enabled while running.
- Countdown starts on Stop or batch completion (unchanged from recent fix).
- Status copy: "Pages 120 / 350"; optionally show "Batch 2 of 4" using `currentBatchEnd / 100`.

### Result card updates (Full Scan Results / All Results)
- **Display scanned page range**: Show the actual pages processed in this scan batch (e.g., "Pages 1-100", "Pages 101-200", "Pages 141-200 of 350 total").
- Use `currentBatchStart` (1-based) and `currentBatchEnd` (1-based) from result model to compute the range.
- For incomplete scans, show both the range and the total available (e.g., "Pages 1-100 of 350 total").
- For completed scans, show "All pages scanned (350 total)" or just "Pages 1-350".
- Update existing cards (`FullScanCard`, etc.) to render `currentBatchStart-currentBatchEnd` prominently alongside link statistics.

## Concurrency shape
- Page-level concurrency: small pool (e.g., 3-5) to overlap fetch/parse across pages while keeping pause responsiveness.
- Link-level concurrency: reuse current caps; ensure backpressure so page pool does not overwhelm link pool.
- `shouldCancel` checked at page boundaries and before dispatching link validation for a page.

## Persistence and merge
- Broken links saved per result as today. No per-page partial documents; we still aggregate per batch result for simplicity.
- When continuing, merge previous broken links with new ones (existing behavior) but ensure dedupe if the same page reprocessed (optional future improvement: keyed by sourceUrl+url+status).

## Error handling
- On page fetch/parse error: log and continue to next page; count as completed to avoid infinite retry loops (or consider marking as failed with retry limit per page).
- On global failure/exception: save current `pagesCompleted` and cursor so resume works.

## Migration / compatibility
- New fields are additive; older results remain valid. UI should null-check `pagesCompleted` and fall back to existing fields when absent.

## Implementation steps (suggested)
1) Update models and repository to carry `pagesCompleted`, `currentBatchStart`, `currentBatchEnd`.
2) Refactor `ScanOrchestrator` to return batch window and drive page-wise loop.
3) Update `LinkCheckerService` to loop per page, emitting progress per page and saving `pagesCompleted` on stop/complete.
4) Provider: initialize progress from cached result/site on resume; remove any secondary progress states.
5) UI: keep single progress bar under Start/Continue; show pagesCompleted/total and optional batch label.
6) Tests: service unit tests for batch boundaries, resume after stop, and pageLimit/totalPages caps; provider tests for resume progress initialization.
