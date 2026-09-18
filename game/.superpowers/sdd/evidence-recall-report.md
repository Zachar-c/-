# Evidence recall report (Stage 0 evidence debt, offline recall pass)

## Why this exists

Task 0.8's Gate result is `NO_GO` for exactly one reason: all 24 high-impact claims
are still `deferred` with no P0 citations. Nothing else blocks Stage 0. The pipeline
that consumes evidence is finished and green; the missing piece is content.

Per the user's decision, this pass does **offline batch recall** of candidate
passages so a human can inspect and confirm them, rather than hand-searching the
novel claim by claim.

## What was built

### `tools/stage0_evidence_candidates.py`

Offline, stdlib only, deterministic, read-only with respect to the benchmark ledger.

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
- Resolves every 《人祖传》 hit against the main text as well and attaches a `twin`
  block (see the policy section below).

### `tools/verify_stage0_candidates.py`

Re-resolves all 208 candidates - **and all 60 twins** - through the real
`world_evidence.resolve_evidence`, i.e. the same function the Gate uses to police
`evidence.jsonl`. It fails when the recall tool's own verdict disagrees with the
resolver, so no candidate can be promoted on a self-reported promise.

Outputs (review artefacts, **not** pipeline input):

- `docs/lore/candidates/stage0-evidence-candidates.jsonl` - machine-readable, one
  row per candidate, `confirmed: false`, ready to be copied from once confirmed.
- `docs/lore/candidates/stage0-evidence-candidates.md` - the same set as a table for
  skimming, grouped by topic, with source / rank / readiness / offset / `main`
  (twin offset) / quote.

## 《人祖传》 authority policy (user ruling, 2026-09-16)

The user's ruling: **《人祖传》 is a book-within-the-book; the whole of it is scattered
through 蛊真人.** Measured against that statement:

```text
《人祖传》 paragraphs (>= 20 chars)                             1572
  present verbatim in 蛊真人-clean.txt                          1362  (86.6%)
  locatable via an internal 24-char fragment                     +94  ( 5.9%)
  traceable to the main text in total                          1456  (92.6%)
  not locatable                                                 116  ( 7.4%)
```

Consequences, which the tool now encodes:

1. 《人祖传》 is a **derivative excerpt**, not an independent second witness. Two quotes
   that resolve to one sentence must **not** be counted as corroboration.
2. Both sources stay P0: `world_evidence._P0_AUTHORITIES` ranks `primary_text` and
   `in_world_text` equally (`_AUTHORITY_RANK` gives both `0`), and `ren_zu_zhuan` is
   listed in `config.p0_source_ids`. So an excerpt-only passage is a fully valid
   citation.
3. Where the same passage exists in the novel, **cite the novel**: every 《人祖传》 row
   carries a `twin` with the main-text coordinates, and `tools/verify_stage0_candidates.py`
   proves those offsets resolve.
4. Do not upgrade a legend to narration just because its words also appear in the novel.
   The in-world character stays; `evidence_kind` is where that is expressed.

**Why raw offsets from one source do not transfer to the other.** The novel indents
paragraphs with four spaces after `\r\n` (`\r\n\r\n    “就算是…`), while the excerpt is
de-indented (`\r\n\r\n“就算是…`). The same sentence therefore sits at different raw
offsets, and a naive raw-window probe fails on most excerpt rows. Twin location is
whitespace-insensitive and maps back through a compact-index -> raw-index table; adding
that took twin coverage from 23/64 to 60/64.

## Results

```text
source gu_zhenren_main: 9024757 decoded characters, sha256=bf78d41427e2...
source ren_zu_zhuan:      82247 decoded characters, sha256=e6a6a6187ec6...
topics=24  candidates=208 (主文 144 / 人祖传 64)
resolver_ready=207  not_unique=1
excerpt rows=64  located in 主文=60  excerpt-only=4  ambiguous=0
quote length: min 2 (the flagged one) / median 30 / max 33
every one of the 24 topics has 6 main-text candidates; 19/24 also have >=1 twin
```

`tools/verify_stage0_candidates.py`:

```text
candidates=208 refs=268 (self=208, twin=60) resolver_confirmed=267
known_rejections=1 disagreements=0
  KNOWN  self gu_activation#6 (gu_zhenren_main@7956169): quote must occur exactly once
PASS: every candidate's readiness matches the resolver
```

Re-running the candidate tool twice produces byte-identical outputs
(`jsonl 7db337a6cd14903e…`, `md 305467988d9fb083…`), so the candidate set is
reproducible.

The one `resolver_ready=false` row is `gu_activation` rank 6, whose only remaining
window is the bare two-character term `催动`; it needs a human-chosen longer window
or a different hit. That is reported rather than papered over.

The 4 excerpt-only rows are:

- `force_and_social_order` #4, `economy_and_primeval_stones` #6,
  `world_scope_and_compression` #4 - the excerpt's own section headers
  (`人祖传（二）——规矩`, `人祖传（二十七）——财富`, `人祖传（六）——天地四猴酒`). These are
  editorial scaffolding of the compilation and do not exist in the novel at all, so
  they are not usable citations as they stand.
- `lifespan` #4 - a line whose novel counterpart differs in wording.

Spot checks show the recall is on target, for example:

- `natal_gu` - "蛊师炼化的第一只蛊虫，意义重大，称之为本命蛊，性命交修" style
  passages around `本命蛊`, including the 月光蛊 clan example.
- `gu_is_life` - "一只活蛊和一只死蛊之间的价值差距" and the 赌蛊 dead-versus-alive
  contrast.
- `soul` - 荡魂山 passages where 魂魄 is damaged by proximity.
- `economy_and_primeval_stones` - 元石 / 仙元石 value statements.
- `world_scope_and_compression` - 至尊仙窍「广袤无比，内分五域九天的格局」.

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

For a row with a `twin`, promote the **twin** coordinates under
`source_file_id: gu_zhenren_main` / `authority: primary_text`, and keep the excerpt
copy at most as a `condition` note - never as a second `support` for the same claim.

The tool deliberately stops at step 0: it never writes to the ledger and never flips
a status, because verified evidence is a human judgement, not a retrieval result.

## Decisions from the 2026-09-16 review

1. **《人祖传》 authority** - settled, see the policy section above. It is a
   book-within-the-book and a derivative excerpt; both sources are P0, the novel is
   preferred where a passage exists in both.
2. **Recall breadth** - keep 6 per topic per source. No change.
3. **Keyword table** - may stay broad for now; filtering happens at confirmation
   time. The `QUERIES` table is still one place to tighten any single topic later.

## Still open for the user

The Gate cannot move until at least 20 of the 24 high-impact claims carry complete P0
references **and** no high-impact claim is left with a `defer` / `needs_evidence`
ruling (`_evaluate_stage0_gate` blocks on both). This pass produced the material for
that; the confirmations and the ruling transitions are the user's call. Confirmations
can be given per row - e.g. `natal_gu:1,3  soul:1  dao_marks:2` (a `t` suffix, as in
`natal_gu:t1`, means "use the twin, cite the novel").
