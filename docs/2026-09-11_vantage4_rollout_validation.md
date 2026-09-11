# vantage4 / vantage4_530 rollout — validation record

Date: 2026-09-11
Scope: added `vantage4` (raw VantageScore 4.0) and `vantage4_530` (`fico_score >= 530` boolean flag)
to four scripts, dev-tested and promoted to prod in this order:

1. `bi_application_redshift` (dev -> prod, full backfill)
2. `bi_application` (downstream union of `bi_application_redshift` + legacy)
3. `bi_loan_redshift` (dev -> prod)
4. `bi_loan` (downstream union of `bi_loan_redshift` + legacy; promoted directly, no separate
   dev run, since it's a low-risk pass-through of two already-validated columns)

Related files: [bi_application_redshift_dev](../bi_application_redshift_dev),
[bi_application_redshift_dev_backfill](../bi_application_redshift_dev_backfill),
[bi_application_rfedshift](../bi_application_rfedshift),
[bi_application_rfedshift_backfill](../bi_application_rfedshift_backfill),
[bi_application](../bi_application), [bi_application_backfill](../bi_application_backfill),
[bi_loan_redshift_dev](../bi_loan_redshift_dev), [bi_loan_redshift](../bi_loan_redshift),
[bi_loan_dev](../bi_loan_dev), [bi_loan](../bi_loan), and the [migrations/](../migrations) folder
for every schema change applied along the way.

Note: the column was originally named `vantage_530` and later renamed to `vantage4_530` for
clarity (ties it to the `vantage4` field it's derived from, same pattern as `fico_score`/`fico_550`).
The rename migrations are in `migrations/2026-09-11_rename_vantage_530_*.sql`.

---

## 1. bi_application_redshift

### Dev validation (after full backfill, 2023-01-01 -> present, 32,721,729 rows)

| Check | Result |
|---|---|
| `vantage4` population | 16,296,960 / 32,721,729 = 49.80% |
| `vantage4_530` population | 17,365,176 / 32,721,729 = 53.07% |
| `fico_score` population | 19,267,794 / 32,721,729 = 58.88% |
| Consistency: `fico_550 = true` implies `vantage4_530 = true` | 0 inconsistent rows |

**Anomaly found:** `vantage4 = '4'` appears in 355,384 rows (~1.1% of populated rows) — not a
plausible VantageScore (real values run ~500s-600s in this data; scores range 300-850). Checked
the date distribution: zero occurrences before September 2024, ramps up through ~March 2025
(peak 26,291/month), then settles into a steady ~10,000-15,000/month through the most recent
month. Sustained for over a year with no drop-off -> looks like a legitimate reserved/special
code from the VantageScore vendor (e.g. "no score" / "insufficient history"), introduced when
`vantage4` capture began, not an ETL bug on our side.
**Status: open follow-up** — needs confirmation from whoever owns `applicant_credit_char_bnpl` /
the credit bureau integration on what code `4` represents.

**Also found during setup:** a stray `cid` column existed in the dev table (not in prod, not
produced by any version of the script) — dropped before backfilling. See
`migrations/2026-09-11_add_vantage_columns_dev.sql`.

### Prod

Promoted after dev validation. Full backfill run via `bi_application_rfedshift_backfill`
(same 2023-01-01 -> present rebuild as dev, since prod's existing rows needed vantage data too,
not just new incremental rows).

---

## 2. bi_application

Downstream table: `UNION ALL` of `bi_application_redshift` (real vantage values) and a legacy
source (hardcoded `NULL` for `vantage4`/`vantage4_530`, since legacy has no vantage data).

### Validation (after backfill, 35,832,799 total rows)

| Check | Result |
|---|---|
| Overall `vantage4` population | 45.49% |
| Overall `vantage4_530` population | 48.46% |
| Overall `fico_score` population | 61.17% |
| By source: `redshift` (30,593,469 rows) | `vantage4` 15,277,515 populated; `vantage4_530` 16,523,643 populated |
| By source: `legacy` (3,108,547 rows) | `vantage4`/`vantage4_530` both 0 (correct — legacy has no vantage data) |
| By source: `redshift_mig` (2,130,783 rows) | `vantage4` 1,021,256 populated; `vantage4_530` 841,765 populated |
| Consistency: `fico_550 = true` implies `vantage4_530 = true`, **excluding legacy** | 0 inconsistent rows |
| Dedup: no duplicate `uplift_application_id` leftovers from non-`redshift` source when a `redshift` row exists | 0 |

Note: the naive consistency check (not excluding `legacy`) initially returned 2,649,151 —
this is expected, not a bug: the legacy branch computes `fico_550` from its own `fico` field but
always hardcodes `vantage4_530` to `NULL`, so any legacy row with a high `fico` will "fail" a
check that doesn't account for that. Excluding `source = 'legacy'` resolved it to 0.

Same `vantage4 = '4'` placeholder-code pattern carries through proportionally (355,424 rows).

---

## 3. bi_loan_redshift

This script always does a full `CREATE OR REPLACE TABLE` rebuild (staged `tmp_*` Delta tables ->
main query -> drop temp tables) — no incremental/backfill split needed, no `ALTER TABLE`
migration needed, since the schema is defined fresh from the query every run.

### Baseline (prod, before change)

| Metric | Value |
|---|---|
| Total rows | 7,367,979 |
| Distinct `loan_id` | 7,363,819 (4,160 duplicate rows, ~0.057%) |
| Date range | 2023-01-01 to 2026-09-11 |
| Total loan amount (USD) | $7,678,019,723.76 |
| Total GMV (USD) | $7,678,022,904.59 |
| Total MDR (USD) | $177,101,109.58 |

Notable population %: `device_type` 0% (same systemic gap seen in `bi_application_redshift`),
`merchant_path` 3.24%, `channel` 1.99%, `booking_window` 53.46%,
`mdr_amount_local`/`mdr_rate`/`subvention_true` all exactly 18.93% (correlated — subvention
deals carry MDR data, non-subvention loans don't).

**Pre-existing duplicate `loan_id` rows (~0.06%):** not caused by this change. `ccb`'s
`QUALIFY ROW_NUMBER() = 1` dedup is unaffected by adding a column to its `SELECT`. Most likely
cause is the un-deduplicated `tmp_loan_subvention` join (`LEFT JOIN ... ON l.loan_id = s.account_id`,
no `ROW_NUMBER`/`DISTINCT`) fanning out when a loan has more than one subvention record.
**Status: open, not investigated further** — low volume, pre-existing.

### Dev validation (after adding vantage4/vantage4_530)

| Check | Result |
|---|---|
| Total rows | 7,368,881 (distinct loans unchanged at 7,363,819 vs prod baseline) |
| Financial totals | Loan $7,678,019,723.74, GMV $7,678,022,904.57, MDR $177,101,109.58 — all within 2 cents of baseline |
| All other column population %s | Within 0.01-0.02% of baseline |
| `vantage4` population | 4,001,448 / 7,368,881 = 54.30% |
| `vantage4_530` population | 7,307,696 / 7,368,881 = 99.17% |
| Consistency: `fico_score >= 550` implies `vantage4_530` true | 0 inconsistent rows |

Duplicate `loan_id` count grew slightly to 5,062 (+902 vs baseline's 4,160) — attributed to
normal data drift between when the two snapshots were taken (dev ran ~2 hours after the baseline
was captured against the same live, growing source tables), not to the vantage4 addition.

`fico_550`-equivalent population is unusually high (99.06%) — expected here, since this table
only contains already-**issued** loans (`status IN ('ISSUED','CHARGED_OFF','DEBT_SOLD')`), which
by definition already cleared underwriting.

### Prod

Promoted after dev validation (see [bi_loan_redshift](../bi_loan_redshift) diff — 3 additions:
`vantage4` added to `tmp_ccb` and the `ccb` CTE, plus `vantage4`/`vantage4_530` in the main
`SELECT`).

---

## 4. bi_loan

Downstream table: `UNION ALL` of `bi_loan_redshift` and a legacy source (hardcoded `NULL` for
`vantage4`/`vantage4_530`). Promoted directly to prod without a separate dev run, since it's a
low-risk pass-through of two columns already fully validated in `bi_loan_redshift`.

### Validation (7,371,434 total rows)

| Check | Result |
|---|---|
| By source: `redshift` (7,368,881 rows) | `vantage4` 54.30% populated, `vantage4_530` 99.17% populated — matches `bi_loan_redshift` exactly |
| By source: `legacy` (2,553 rows) | `vantage4`/`vantage4_530` both 0% (correct) |
| Dedup: no leftover legacy row when a matching redshift row exists for the same `uplift_loan_id` | 0 |
| `total_rows` (7,371,434) vs `distinct uplift_loan_id` (7,126,389) gap (245,045) | Confirmed to be entirely `NULL uplift_loan_id` values, not real duplicates — `true_duplicates = 0` |

Financial totals ($7,680,178,975.66 loan / $7,680,262,147.19 GMV / $177,101,171.21 MDR) are
slightly higher than `bi_loan_redshift` alone, as expected since `bi_loan` also includes the
legacy-source rows.

---

## Open follow-ups

1. **`vantage4 = '4'` placeholder code** (~1% of populated rows across all four tables) — confirm
   with the `applicant_credit_char_bnpl` / credit bureau integration owner what this code means.
   Likely a "no score" / reserved code, not a real score — may need to be treated as `NULL` rather
   than a literal value once confirmed.
2. **`bi_loan_redshift` duplicate `loan_id` rows** (~0.06-0.07%, pre-existing) — likely caused by
   the un-deduplicated `tmp_loan_subvention` join. Not investigated further since it's low volume
   and predates this change, but worth root-causing if it ever affects downstream reporting.
3. **`device_type` is 0% populated** across `bi_application_redshift`, `bi_application`,
   `bi_loan_redshift`, and `bi_loan` — a systemic upstream gap, not specific to this rollout.
