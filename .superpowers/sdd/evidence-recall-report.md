# Evidence recall report (Stage 0 evidence debt, offline recall pass)

## Why this exists

Task 0.8's Gate result is `NO_GO` for exactly one reason: all 24 high-impact claims
are still `deferred` with no P0 citations. Nothing else blocks Stage 0. The pipeline
that consumes evidence is finished and green; the missing piece is content.

Per the user's decision, this pass does **offline batch recall** of candidate
passages so a human can inspect and confirm them, rather than hand-searching the
novel claim by claim.

## What was built

`tools/stage0_evidence_candidates.py` - offline, stdlib only, deterministic,
read-only with respect to the benchmark ledger.

- Reads both sources through `lore_engine.src.source_manifest.read_source`, so
  offsets are **decoded character** indices with the same strict decoding the
  resolver uses (utf-8 for `gu_zhenren_main`, gb18030 for `ren_zu_zhuan`).
- Per topic, runs a weighted Chinese pattern table (`QUERIES`), scores each hit by
  how many *distinct* topic patterns sit in its neighbourhood (tie-broken by pattern
  weight and then by rarity), deduplicates nearby hits, and keeps the best 6 per
  topic per source.
- Grows every hit into a **globally unique** quote: at least `MIN_QUOTE` (30)
  characters, at most `MAX_QUOTE` (120), extended alternately until
  `text.count(quote) == 1`. This mirrors the resolver's hardest constraint -
  a citation is accepted only when its quote occurs exactly once at exactly
  `char_start`.
- Self-checks each candidate (`text[char_start:char_end] == quote` and occurrence
  count) and records `resolver_ready`, so the review sheet flags anything that would
  be rejected later instead of hiding it.

Outputs (review artefacts, **not** pipeline input):

- `docs/lore/candidates/stage0-evidence-candidates.jsonl` - machine-readable, one
  row per candidate, `confirmed: false`, ready to be copied from once confirmed.
- `docs/lore/candidates/stage0-evidence-candidates.md` - the same set as a table for
  skimming, grouped by topic, with source / rank / readiness / offset / quote.

## Results

```text
source gu_zhenren_main: 9024757 decoded characters, sha256=bf78d41427e2...
source ren_zu_zhuan:      82247 decoded characters, sha256=e6a6a6187ec6...
topics=24  candidates=208  resolver_ready=207  not_unique=1
主文 144 candidates / 人祖传 64 candidates
quote length: min 2 (the flagged one) / median 30 / max 33
```

Re-running the tool twice produces byte-identical outputs (hash-stable), so the
candidate set is reproducible.

Spot checks show the recall is on target, for example:

- `natal_gu` - "蛊师炼化的第一只蛊虫，意义重大，称之为本命蛊，性命交修" style
  passages around `本命蛊`, including the 月光蛊 clan example.
- `gu_is_life` - "一只活蛊和一只死蛊之间的价值差距" and the 赌蛊 dead-versus-alive
  contrast.
- `soul` - 荡魂山 passages where 魂魄 is damaged by proximity.
- `economy_and_primeval_stones` - 元石 / 仙元石 value statements.
- `world_scope_and_compression` - 至尊仙窍「广袤无比，内分五域九天的格局」.

The one `resolver_ready=false` row is `gu_activation` rank 6, whose only remaining
window is the bare two-character term `催动`; it needs a human-chosen longer window
or a different hit. That is reported rather than papered over.

## How a confirmed candidate becomes evidence

Only after the user marks a candidate as confirmed:

1. Add an `evidence` record to
   `lore_sources/benchmarks/world_model_stage0/evidence.jsonl`:
   `evidence_id`, `source_file_id`, `source_ref`, `char_start`, `char_end`, `quote`
   (the exact slice, not the whitespace-collapsed display text), `authority`
   (`primary_text` for the main text, `in_world_text` for 《人祖传》),
   `evidence_kind` (`support` / `condition` / `counterexample`).
2. Add the new `evidence_id` to that claim's `evidence_ids` (or
   `counter_evidence_ids`) in `claims.jsonl` and set its `status`
   (`candidate` -> `canonical` requires the decision-ledger transition rule, which
   the validator enforces).
3. Re-run `python -m unittest discover -s lore_engine/tests`, then the Gate. Each
   confirmed claim moves the Gate's `high-impact complete references` counter by
   one; at 20 of 24 the minimum-evidence blocker clears.

The tool deliberately stops at step 0: it never writes to the ledger and never flips
a status, because verified evidence is a human judgement, not a retrieval result.

## Open decisions for the user

1. **Authority policy for 《人祖传》.** 64 of the 208 candidates come from it. Its
   manifest authority is `in_world_text` and it is listed in `p0_source_ids`, so it
   satisfies the mechanical P0 rule - but for world-model truth the main text is
   stronger. Proposed default: main-text candidates carry `support` for the ruling,
   人祖传 candidates are used as `condition` / corroboration, or as the primary
   source only for topics that are about in-world lore.
2. **Recall breadth.** Currently 6 per topic per source. Raising it costs nothing but
   review time; lowering it to 3 would cut the sheet to ~144 rows.
3. **Keyword table tuning.** The tool prints per-pattern hit counts, so any pattern
   that turns out to be too broad or too narrow can be adjusted in one place.
