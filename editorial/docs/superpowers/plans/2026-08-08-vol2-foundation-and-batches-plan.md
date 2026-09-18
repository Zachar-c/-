# Second Volume Foundation and Batches Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish an evidence-based editorial foundation for volume two, sections 001-206, and prepare seven non-overlapping batch baselines and detailed outlines without rewriting prose.

**Architecture:** A chief-editor conversation owns source-boundary verification, volume-wide decisions, specialist ledgers, structural surgery, and shared validation. Seven batch conversations may later own exactly one detailed outline and one edited-text batch, but they consume frozen shared decisions and submit proposed ledger updates instead of modifying shared assets directly.

**Tech Stack:** UTF-8 Markdown and edited text, CP936 source extraction, PowerShell 5.1 scripts, JSON volume configuration, Git.

## Global Constraints

- `AGENTS.md` is the only normative source; this plan defines execution order and file ownership but does not override editorial rules.
- Do not rewrite second-volume prose during this plan's foundation and batch-preparation phase.
- Preserve the complete source outside Git; never add `蛊真人.txt`, full-source copies, or temporary CP936 extracts to the repository.
- Preserve all existing untracked files, especially `working/read-*.txt`, `working/round3-*.txt`, `working/vol1-sec*.cp936.txt`, and `docs/superpowers/plans/2026-08-08-vol1-foundation-ledgers-plan.md`.
- Treat `volumes/02-魔子出山/vol2-sec001.edited.txt` as the migrated opening baseline, not as approved or completed prose.
- Do not alter the main event order, outcomes, character endings, major foreshadowing, or information-release order.
- Do not convert suspected inconsistencies into confirmed errors before source evidence and later stable canon have been cross-checked.
- Reduce repetitive authorial resentment, modern political projection, Earth analogies, and internet-commentary phrasing while preserving darkness, cruelty, demonic logic, institutional sacrifice, unequal life value, philosophy, implication, and Fang Yuan's five-hundred-year perspective.
- Every body-text conversation owns exactly one non-overlapping range: `001-030`, `031-060`, `061-090`, `091-120`, `121-150`, `151-180`, or `181-206`.
- Only the chief-editor conversation may modify `notes/vol2-*.md`, volume configuration, shared scripts, or cross-batch decisions.

## File Structure and Ownership

### Chief-editor shared assets

- Create: `config/editorial-volumes.json` - machine-readable volume directories, section totals, and batch ranges.
- Modify: `scripts/validate_editorial_assets.ps1` - validate all configured volumes instead of hard-coding volume one.
- Create: `notes/vol2-decision-register.md` - authoritative P0/P1 rulings and unresolved decisions.
- Create: `notes/vol2-combat-ledger.md` - rank, Gu combination, injury, battlefield, and cross-rank influence evidence.
- Create: `notes/vol2-resource-audit.md` - primeval stones, Gu, materials, caravan assets, organizational flows, and purchasing power.
- Create: `notes/vol2-chronology-geography.md` - travel routes, elapsed time, locations, seasonal continuity, and historical dating.
- Create: `notes/vol2-character-state-ledger.md` - cultivation, injuries, Gu worms, identity, motives, alliances, and end states.
- Create: `notes/vol2-information-ledger.md` - reader knowledge, character knowledge, false records, secrets, and release order.
- Create: `notes/vol2-structural-surgery.md` - section-level moves, expansions, compressions, and protected narrative functions.

### Batch-owned assets

- Create: `outlines/detail/vol2-sec001-030.md`
- Create: `outlines/detail/vol2-sec031-060.md`
- Create: `outlines/detail/vol2-sec061-090.md`
- Create: `outlines/detail/vol2-sec091-120.md`
- Create: `outlines/detail/vol2-sec121-150.md`
- Create: `outlines/detail/vol2-sec151-180.md`
- Create: `outlines/detail/vol2-sec181-206.md`
- Create or rebuild from verified source: `volumes/02-魔子出山/vol2-sec001-030.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec031-060.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec061-090.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec091-120.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec121-150.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec151-180.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec181-206.edited.txt`

### Local-only evidence files

- Create under `working/vol2-source/`: seven CP936 extracts and any comparison reports required for source verification.
- Keep `working/vol2-source/` untracked; if the current ignore rules do not cover it, modify `.gitignore` before extraction.

---

### Task 1: Verify the Source and Volume Boundary

**Files:**
- Read: `AGENTS.md`
- Read: `outlines/volumes/02-魔子出山.md`
- Read: `outlines/00-full-book-outline.md`
- Read: `notes/full-book-audit-register.md`
- Read: `notes/vol1-decision-register.md`
- Read: `notes/vol1-character-state-ledger.md`
- Read: `volumes/02-魔子出山/vol2-sec001.edited.txt`
- Optional modify: `.gitignore`
- Local-only create: `working/vol2-source/vol2-full.cp936.txt`
- Local-only create: `working/vol2-source/section-index.txt`

**Interfaces:**
- Consumes: canonical source `C:\DevEnv\05_Downloads\蛊真人.txt` or the repository-root ignored `蛊真人.txt`, decoded as CP936.
- Produces: a verified mapping from second-volume section numbers `001-206` to exact source line spans, plus confirmed first and last headings.

- [ ] **Step 1: Confirm source identity without copying it into Git**

Run:

```powershell
$repoSource = Resolve-Path -LiteralPath '.\蛊真人.txt' -ErrorAction SilentlyContinue
$canonical = Resolve-Path -LiteralPath 'C:\DevEnv\05_Downloads\蛊真人.txt'
Get-Item -LiteralPath $canonical | Select-Object FullName,Length
if ($repoSource) { Get-FileHash -Algorithm SHA256 -LiteralPath $repoSource,$canonical }
git check-ignore -v -- '蛊真人.txt'
```

Expected: canonical source length is `16576824` bytes; when both copies exist their SHA256 hashes match; the repository-root source is ignored.

- [ ] **Step 2: Extract only the candidate volume-two range to a local-only file**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'working\vol2-source' | Out-Null
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/extract_batch.ps1 -SourcePath 'C:\DevEnv\05_Downloads\蛊真人.txt' -StartLine 34590 -EndLine 75004 -OutputPath 'working\vol2-source\vol2-full.cp936.txt'
git check-ignore -v -- 'working/vol2-source/vol2-full.cp936.txt'
```

Expected: `40415` source lines are written and the extract is ignored by Git.

- [ ] **Step 3: Build a heading index from the extracted source**

Run:

```powershell
$enc = [Text.Encoding]::GetEncoding(936)
$lines = [IO.File]::ReadAllLines((Resolve-Path 'working\vol2-source\vol2-full.cp936.txt'), $enc)
$rows = for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*第.{1,12}节(?:[：:]|\s{2,})') {
        '{0}`t{1}' -f ($i + 34590), $lines[$i].Trim()
    }
}
$rows | Set-Content -LiteralPath 'working\vol2-source\section-index.txt' -Encoding UTF8
$rows.Count
$rows | Select-Object -First 3
$rows | Select-Object -Last 3
```

Expected: exactly `206` main-sequence headings after excluding clear webpage duplicates; first heading is `第一节：黄龙江上竹筏倾`; last heading is `第二百零六节：今日暂且展翼去，明朝登仙笞凤凰！` or the source's typographically equivalent title.

- [ ] **Step 4: Resolve duplicate, missing, or malformed headings before proceeding**

For every count other than `206`, compare the adjacent source lines and classify the anomaly as webpage duplicate, malformed heading, source omission, or true narrative section. Record exact source line numbers in the future chronology ledger. Do not renumber or synthesize a missing section from context.

- [ ] **Step 5: Compare the migrated first section against the source**

Run a normalized heading/body comparison that ignores only the edition header and known site noise. Expected: `vol2-sec001.edited.txt` contains the complete narrative content of source section 001 and no material from section 002; any prose edits are flagged for later diagnosis rather than silently retained or reverted.

- [ ] **Step 6: Stop the workflow if the hard gate fails**

Gate passes only when all `206` section boundaries, the opening boundary, and the volume-ending boundary are evidenced. No ledger, baseline, outline, or prose task may proceed on an inferred boundary.

### Task 2: Add Per-Volume Validation Configuration

**Files:**
- Create: `config/editorial-volumes.json`
- Modify: `scripts/validate_editorial_assets.ps1`

**Interfaces:**
- Consumes: volume metadata with `id`, `directoryPattern`, `detailPattern`, `sectionCount`, and ordered `batches`.
- Produces: validation of configured volume detail headings and edited-text batch section counts while preserving all current UTF-8, source-boundary, CSV, noise, paragraph-length, and link checks.

- [ ] **Step 1: Create the volume configuration**

Use this schema and data:

```json
{
  "volumes": [
    {
      "id": "vol1",
      "directoryPattern": "01-*",
      "detailPattern": "vol1-sec*.md",
      "sectionCount": 199,
      "batches": [
        { "range": "001-010", "count": 10 },
        { "range": "011-020", "count": 10 },
        { "range": "021-030", "count": 10 },
        { "range": "031-060", "count": 30 },
        { "range": "061-090", "count": 30 },
        { "range": "091-120", "count": 30 },
        { "range": "121-150", "count": 30 },
        { "range": "151-180", "count": 30 },
        { "range": "181-199", "count": 19 }
      ]
    },
    {
      "id": "vol2",
      "directoryPattern": "02-*",
      "detailPattern": "vol2-sec*.md",
      "sectionCount": 206,
      "batches": [
        { "range": "001-030", "count": 30 },
        { "range": "031-060", "count": 30 },
        { "range": "061-090", "count": 30 },
        { "range": "091-120", "count": 30 },
        { "range": "121-150", "count": 30 },
        { "range": "151-180", "count": 30 },
        { "range": "181-206", "count": 26 }
      ]
    }
  ]
}
```

- [ ] **Step 2: Add a `-Volume` selector to the validator**

Add `[string[]]$Volume = @('vol1')` so existing commands retain their current behavior. Accept `all` by expanding it to every configured volume ID; reject unknown IDs with a clear validation error.

- [ ] **Step 3: Replace hard-coded detail validation with configured validation**

For each selected volume, require every configured `outlines/detail/<id>-sec<range>.md`, collect `第N节` headings from only that volume's files, reject duplicates, and require exactly `1..sectionCount`.

- [ ] **Step 4: Replace `Test-VolumeOneSectionBatches` with generic batch validation**

Resolve exactly one directory matching `volumes/<directoryPattern>`, require `<id>-sec<range>.edited.txt`, count section headings in each batch, and compare both per-file counts and total count to configuration.

- [ ] **Step 5: Prove backward compatibility before volume-two assets exist**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate_editorial_assets.ps1 -Phase detail -Volume vol1
```

Expected: `Editorial asset validation passed: phase=detail` and no volume-two file is required.

- [ ] **Step 6: Commit the validator foundation independently**

```powershell
git add -- config/editorial-volumes.json scripts/validate_editorial_assets.ps1
git commit -m "支持按卷校验精编资产"
```

Expected: commit contains only the configuration and validator changes.

### Task 3: Build the Volume-Two Decision Register

**Files:**
- Create: `notes/vol2-decision-register.md`
- Read: `notes/full-book-audit-register.md`
- Read: `notes/vol1-decision-register.md`
- Read: `outlines/volumes/02-魔子出山.md`

**Interfaces:**
- Consumes: verified section boundaries and source evidence gathered by later specialist-ledger tasks.
- Produces: stable decision IDs `V2-DEC-001` onward with priority, issue, source location, evidence, ruling type, implementation scope, downstream impact, information-release risk, and state.

- [ ] **Step 1: Create the register schema and state vocabulary**

Use states `待核证`, `核证中`, `待用户裁决`, `已裁决`, and `已实施`. Use ruling types `保留原文`, `改为角色认知`, `以后期设定替换`, `中性模糊`, `新增重构设定`, and `需要用户裁决`.

- [ ] **Step 2: Seed only confirmed structural facts**

Record the verified `001-206` boundary, the migrated section 001 baseline, the seven batch boundaries, and the protected volume ending. Do not pre-decide geography, Three Kings dating, Ba Gui survival, prices, or battle tiers.

- [ ] **Step 3: Register the six applicable full-book audits**

Add references to `FB-002`, `FB-003`, `FB-004`, `FB-005`, `FB-015`, and `FB-016`, preserving their current audit state. Each entry must say what evidence would promote it to a volume-level ruling.

- [ ] **Step 4: Add a cross-ledger evidence rule**

A P0/P1 item may become `已裁决` only after its combat, resource, chronology/geography, character, or information evidence is cited by exact section. Unsupported reconstruction remains `待用户裁决`.

### Task 4: Build the Chronology and Geography Ledger

**Files:**
- Create: `notes/vol2-chronology-geography.md`

**Interfaces:**
- Consumes: the verified section index, volume-one end state, route statements, elapsed-time statements, transport methods, and later stable geographic scale.
- Produces: phase-by-phase route and elapsed-time constraints used by every batch outline.

- [ ] **Step 1: Define chronology phases with exact section spans**

At minimum separate Yellow Dragon River escape, White Bone inheritance, caravan travel, Shang Clan City residence, Three Kings preparation, Three Kings Mountain conflict, and Hu Immortal blessed-land ending.

- [ ] **Step 2: Audit the five-day Yellow Dragon River voyage**

Record departure condition, raft speed evidence, current assistance, rest or continuous travel, injuries, food and water, pursuers, landing point, and approach to White Bone Mountain. Distinguish local river travel from crossing a large fraction of Southern Border.

- [ ] **Step 3: Audit every explicit journey duration**

For each route record start, destination, elapsed time, cultivation, transport Gu or beast, road or river conditions, narration gaps, and confidence grade. Prefer route clarification or time skip over inventing a teleportation method.

- [ ] **Step 4: Audit Three Kings and Ba Gui historical dating**

Separate public legend, character statements, inheritance records, narrator facts, and later canon. Connect unresolved historical scale to `FB-002` and `FB-003` without assuming stasis, dormancy, annexation, or tribulation transfer.

- [ ] **Step 5: Record the volume-ending time and location state**

Protect the exact transition into Hu Immortal blessed land and ensure no outline brings later knowledge or consequences into section 206.

### Task 5: Build the Combat Ledger

**Files:**
- Create: `notes/vol2-combat-ledger.md`

**Interfaces:**
- Consumes: every major fight's cultivation, Gu set, injuries, primeval essence, terrain, preparation, surprise, numbers, and result.
- Produces: evidence-based threat mappings and continuity constraints, not rank labels alone.

- [ ] **Step 1: Record opening combat state**

Map Fang Yuan and Bai Ning Bing's cultivation, apertures, usable Gu, missing Gu, injuries, healing capacity, essence access, and mutual constraints immediately after Qing Mao Mountain.

- [ ] **Step 2: Map White Bone inheritance battles**

For each encounter record preparation, traps, inheritance restrictions, resource consumption, cross-rank effects, and irreversible injuries or losses.

- [ ] **Step 3: Map caravan, arena, and Shang Clan City combat**

Distinguish public rank, concealed ability, Gu combination quality, arena rules, organizational support, healing between matches, and reputation effects.

- [ ] **Step 4: Map Three Kings Mountain battle tiers**

Record rank-three, rank-four, rank-five, beast-group, formation, inheritance-rule, and ambush contributions separately. Apply the established rule that rank-four forces can influence a rank-five battlefield through numbers, counters, attrition, formations, surprise, or sacrifice without becoming rank-five equivalents.

- [ ] **Step 5: Flag unexplained missing forces**

Whenever a character or organization possesses a relevant rank-three or rank-four combat group but the group disappears from a decisive fight, require source explanation, tactical exclusion, prior loss, or a volume-level decision.

### Task 6: Build the Resource and Purchasing-Power Audit

**Files:**
- Create: `notes/vol2-resource-audit.md`

**Interfaces:**
- Consumes: opening inventories, all stated primeval-stone amounts, Gu purchases and sales, feeding costs, caravan flows, auction prices, arena rewards, inheritance gains, and organizational assets.
- Produces: transaction-level reconciliation and purchasing-power bands.

- [ ] **Step 1: Establish opening balances**

Record Fang Yuan and Bai Ning Bing's cash, Gu worms, food, healing assets, clothing, identities, and liabilities after the first-volume disaster. Unknown values remain ranges or explicit unknowns.

- [ ] **Step 2: Reconcile White Bone inheritance gains and costs**

Track each Gu, material, consumable, injury cost, feeding obligation, and ownership dispute. Do not count discovered resources as liquid cash without a sale or usable transfer.

- [ ] **Step 3: Establish caravan and Shang Clan City price bands**

Separate ordinary living costs, rank-one and rank-two Gu, rank-three Gu, rare materials, auction liquidity, arena rewards, clan-backed credit, and large organizational transfers.

- [ ] **Step 4: Audit every large transaction**

For each amount record payer, recipient, asset source, cash versus inventory, timing, obligations, monopoly or urgency premium, and post-transaction balance. Flag contradictions instead of smoothing them with larger numbers.

- [ ] **Step 5: Reconcile Three Kings preparation and proceeds**

Track travel, feeding, refinement, information, disguise, healing, replacement Gu, inheritance gains, and losses. Ensure repeated entries into inheritances consume time and resources.

### Task 7: Build Character-State and Information Ledgers

**Files:**
- Create: `notes/vol2-character-state-ledger.md`
- Create: `notes/vol2-information-ledger.md`

**Interfaces:**
- Consumes: phase boundaries and all state-changing sections.
- Produces: batch opening/closing snapshots and protected information-release constraints.

- [ ] **Step 1: Track principal character states**

At minimum include Fang Yuan, Bai Ning Bing, Shang Xin Ci, Xiao Die, Wei Yang, Shang Yan Fei, Tie Ruo Nan, Bai Gu inheritance principals, Three Kings Mountain principals, Feng Jin Huang, and Hu Immortal land spirit where they enter the volume.

- [ ] **Step 2: Record state transitions at every batch boundary**

For each relevant character record cultivation, Gu, injuries, resources, identity, public reputation, motives, alliances, leverage, location, and immediate objective at sections `030`, `060`, `090`, `120`, `150`, `180`, and `206`.

- [ ] **Step 3: Separate five information classes**

Use `读者已知`, `方源已知`, `其他角色已知`, `公开说法/地方传闻`, and `后期真相`. A later truth cannot replace an earlier character belief unless the prose clearly marks the belief as limited knowledge.

- [ ] **Step 4: Protect delayed revelations**

Map Bai Ning Bing's intentions and constraints, Fang Yuan's rebirth knowledge, Shang Xin Ci's identity and political value, Three Kings inheritance mechanics, Ba Gui's nature and limits, Hu Immortal blessed-land rules, and Fang Yuan's identity at the volume ending.

- [ ] **Step 5: Protect philosophy and implication**

Flag passages that express five-hundred-year judgment, demonic choice, life-value hierarchy, black-white conflict, personal road, sacrifice, or suggestive dialogue. These passages may be refined for repetition but may not be deleted merely because they are discursive.

### Task 8: Freeze P0/P1 Decisions and Structural Surgery

**Files:**
- Modify: `notes/vol2-decision-register.md`
- Create: `notes/vol2-structural-surgery.md`

**Interfaces:**
- Consumes: all five specialist ledgers.
- Produces: frozen rulings and section-level actions that detailed outlines can safely reference.

- [ ] **Step 1: Review every P0/P1 candidate**

For each candidate state the source expression, conflicting evidence, narrator or character status, risk, recommended ruling, affected sections, downstream consequences, and information-release effect.

- [ ] **Step 2: Escalate genuinely ambiguous reconstructions**

Any issue with two materially different self-consistent solutions becomes `待用户裁决`. Do not select a new travel device, blessed-land survival mechanism, hidden combat force, or economic subsidy without textual support.

- [ ] **Step 3: Freeze decided items**

Only entries with complete evidence and one defensible minimal intervention become `已裁决`. Record the date and evidence ledger IDs.

- [ ] **Step 4: Build the structural-surgery table**

For every affected section specify `保留`, `改写`, `重排`, `压缩`, `扩写`, `补足`, or `移除非正文`. Include the original narrative function, protected sentence or image, replacement carrier, cross-batch dependency, and whether user review is required.

- [ ] **Step 5: Confirm that no prose changed**

Run:

```powershell
git diff --name-only -- 'volumes/02-魔子出山/*.edited.txt'
```

Expected: no output during ledger and decision work.

- [ ] **Step 6: Commit the frozen shared foundation**

```powershell
git add -- notes/vol2-decision-register.md notes/vol2-combat-ledger.md notes/vol2-resource-audit.md notes/vol2-chronology-geography.md notes/vol2-character-state-ledger.md notes/vol2-information-ledger.md notes/vol2-structural-surgery.md
git commit -m "建立第二卷裁决与专项台账"
```

Expected: commit contains only the seven volume-two shared ledgers.

### Task 9: Create Seven Verified Baseline Files

**Files:**
- Create or replace after comparison: `volumes/02-魔子出山/vol2-sec001-030.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec031-060.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec061-090.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec091-120.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec121-150.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec151-180.edited.txt`
- Create: `volumes/02-魔子出山/vol2-sec181-206.edited.txt`

**Interfaces:**
- Consumes: exact source spans from Task 1 and `scripts/create_edited_baseline.ps1` noise removal.
- Produces: seven UTF-8 source-faithful working baselines with exact section counts and no editorial rewrite.

- [ ] **Step 1: Extract seven exact CP936 source ranges**

Use the verified heading index, starting each extract at its first heading and ending immediately before the next batch heading; the final extract ends at the verified end of section 206. Never estimate line numbers from the approximate volume outline anchors.

- [ ] **Step 2: Create UTF-8 baselines with the existing normalizer**

Run `scripts/create_edited_baseline.ps1` separately for each extract with `-BookTitle '《蛊真人》精编版'` and `-VolumeTitle '第二部 魔子出山'`.

- [ ] **Step 3: Preserve the migrated section 001 evidence**

Before replacing `vol2-sec001.edited.txt`, compare it against the new section-001 source baseline. Carry forward only confirmed boundary cleanup and user-authored edits; record any other differences in the first batch outline for review.

- [ ] **Step 4: Verify exact batch counts**

Expected counts are `30, 30, 30, 30, 30, 30, 26`; combined total is `206`; headings are strictly increasing with no duplicate or missing number.

- [ ] **Step 5: Verify source fidelity**

For each batch compare normalized source text against baseline text. Allowed differences are edition headers, encoding normalization, known webpage noise, postscripts, watermarks, and heading punctuation normalization. Every narrative deletion or addition fails the baseline gate.

- [ ] **Step 6: Commit baselines independently**

```powershell
git add -- 'volumes/02-魔子出山/vol2-sec001-030.edited.txt' 'volumes/02-魔子出山/vol2-sec031-060.edited.txt' 'volumes/02-魔子出山/vol2-sec061-090.edited.txt' 'volumes/02-魔子出山/vol2-sec091-120.edited.txt' 'volumes/02-魔子出山/vol2-sec121-150.edited.txt' 'volumes/02-魔子出山/vol2-sec151-180.edited.txt' 'volumes/02-魔子出山/vol2-sec181-206.edited.txt'
git commit -m "建立第二卷七批正文基线"
```

Expected: no `working/` source extract is staged.

### Task 10: Create the Seven Detailed Batch Outlines

**Files:**
- Create: `outlines/detail/vol2-sec001-030.md`
- Create: `outlines/detail/vol2-sec031-060.md`
- Create: `outlines/detail/vol2-sec061-090.md`
- Create: `outlines/detail/vol2-sec091-120.md`
- Create: `outlines/detail/vol2-sec121-150.md`
- Create: `outlines/detail/vol2-sec151-180.md`
- Create: `outlines/detail/vol2-sec181-206.md`

**Interfaces:**
- Consumes: frozen shared decisions, all specialist ledgers, structural surgery, verified baseline text, previous-batch closing state, and next-batch opening constraints.
- Produces: one entry per section containing diagnosis and implementation constraints, not rewritten prose.

- [ ] **Step 1: Use one consistent section template**

Every section entry must include title, source span, narrative function, opening state, closing state, required events, protected emotional or philosophical anchor, P0/P1 references, P2/P3 issues, combat/resource/time/information checks, proposed action, downstream effects, and chapter-ending propulsion.

- [ ] **Step 2: Draft `001-030` with opening continuity as its primary gate**

Cover the Yellow Dragon River five-day voyage, Fang Yuan and Bai Ning Bing's damaged opening state, White Bone inheritance entry and development, mutual leverage, and all source differences inherited from the migrated first section.

- [ ] **Step 3: Draft `031-060` with caravan and purchasing power as its primary gate**

Cover White Bone aftermath, caravan integration, identities, travel costs, combat recovery, Shang Xin Ci setup, and the transition toward Shang Clan City.

- [ ] **Step 4: Draft `061-090` with Shang Clan City systems as its primary gate**

Cover trade, auctions, arena rules, public identity, Gu acquisition and feeding, organizational support, Shang Xin Ci's development, and Fang Yuan/Bai Ning Bing's changing leverage.

- [ ] **Step 5: Draft `091-120` with arena and political resource flow as its primary gate**

Cover cultivation progression, repeated combat recovery, reputation, factional exchanges, major transactions, philosophical passages, and preparation that must causally support Three Kings Mountain.

- [ ] **Step 6: Draft `121-150` with Three Kings history and entry rules as its primary gate**

Cover the opening of the inheritances, public and private historical claims, entry constraints, preparation costs, battlefield tiers, and the first Ba Gui or blessed-land evidence without deciding unsupported ancient-history mechanisms.

- [ ] **Step 7: Draft `151-180` with inheritance attrition as its primary gate**

Cover repeated entries, resource depletion, injuries, rank-four influence on rank-five conflict, missing-force explanations, identity pressure, Bai Ning Bing's choices, and causal preparation for the final crisis.

- [ ] **Step 8: Draft `181-206` with information order and volume boundary as its primary gate**

Cover Three Kings Mountain resolution, Ba Gui constraints, Hu Immortal blessed-land opening, Feng Jin Huang, Ding Xian You, Spring Autumn Cicada cost, identity concealment, and the exact volume-ending state without importing volume-three consequences.

- [ ] **Step 9: Review adjacent boundaries serially**

The chief editor compares `030/031`, `060/061`, `090/091`, `120/121`, `150/151`, and `180/181` for cultivation, injuries, Gu, cash, location, elapsed time, identity, alliances, unresolved danger, and reader knowledge. Any mismatch is fixed in outlines or shared ledgers before prose work starts.

- [ ] **Step 10: Commit all outlines after boundary review**

```powershell
git add -- outlines/detail/vol2-sec001-030.md outlines/detail/vol2-sec031-060.md outlines/detail/vol2-sec061-090.md outlines/detail/vol2-sec091-120.md outlines/detail/vol2-sec121-150.md outlines/detail/vol2-sec151-180.md outlines/detail/vol2-sec181-206.md
git commit -m "建立第二卷七批精编细纲"
```

Expected: each section `001-206` appears exactly once across the seven files.

### Task 11: Run the Foundation Regression Gate

**Files:**
- Validate: `config/editorial-volumes.json`
- Validate: `scripts/validate_editorial_assets.ps1`
- Validate: `notes/vol2-*.md`
- Validate: `outlines/detail/vol2-sec*.md`
- Validate: `volumes/02-魔子出山/vol2-sec*.edited.txt`

**Interfaces:**
- Consumes: all foundation deliverables.
- Produces: evidence that the second volume is structurally ready for later prose editing.

- [ ] **Step 1: Run configured validation for both volumes**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate_editorial_assets.ps1 -Phase detail -Volume all
```

Expected: `Editorial asset validation passed: phase=detail`; volume one still covers exactly `001-199`; volume two covers exactly `001-206`; all configured batch files exist with exact counts.

- [ ] **Step 2: Check whitespace and patch integrity**

```powershell
git diff --check
```

Expected: no output and exit code `0`.

- [ ] **Step 3: Confirm no complete source or local extract is tracked**

```powershell
git -c core.quotePath=false ls-files | Select-String -Pattern '蛊真人\.txt|working/vol2-source|\.cp936\.txt'
```

Expected: no output.

- [ ] **Step 4: Scan for placeholders and encoding residue**

```powershell
rg -n "TBD|TODO|待补|�|锛|銆|鈥" notes/vol2-*.md outlines/detail/vol2-sec*.md
```

Expected: no placeholder or mojibake match; legitimate Chinese punctuation is not flagged by the chosen patterns.

- [ ] **Step 5: Inspect the worktree without disturbing unrelated files**

```powershell
git status --short
```

Expected: only intended second-volume implementation files are modified or staged, plus the previously existing untracked first-volume plan and `working/` evidence files. Those unrelated untracked files remain untouched.

- [ ] **Step 6: Record the prose-editing readiness decision**

The chief editor may authorize batch prose work only when source boundaries, shared ledgers, all P0/P1 rulings required by the relevant batch, detailed outlines, and adjacent boundary checks pass. Authorization is per batch; unresolved later-batch questions do not block an earlier batch unless they affect its foreshadowing or information order.

### Task 12: Prepare Isolated Batch Execution

**Files:**
- Read only: `README.md`
- Read only: `AGENTS.md`
- No prose modification in this task.

**Interfaces:**
- Consumes: validated foundation and seven batch scopes.
- Produces: seven isolated future assignments with no shared-file write collisions.

- [ ] **Step 1: Create one branch or worktree per batch at execution time**

Use branch names `edit/vol2-001-030`, `edit/vol2-031-060`, `edit/vol2-061-090`, `edit/vol2-091-120`, `edit/vol2-121-150`, `edit/vol2-151-180`, and `edit/vol2-181-206`. Do not run concurrent body-text conversations in the same worktree.

- [ ] **Step 2: Give each conversation an exact ownership contract**

Each conversation may modify only its `volumes/02-魔子出山/vol2-sec<range>.edited.txt` and `outlines/detail/vol2-sec<range>.md`. It reads shared ledgers but submits shared-ledger changes as a separate recommendation in its final report.

- [ ] **Step 3: Require diagnosis before prose changes**

At batch start the conversation reports scope, previous ending, opening character/resource/time/information state, frozen decisions, unresolved risks, and the user's latest style corrections. It then provides a section-level problem list and confirms the outline before editing prose.

- [ ] **Step 4: Merge serially through the chief editor**

Merge in section order. After each batch, the chief editor reviews user comments, updates shared ledgers serially, reruns validation, and checks the next batch's opening state before authorizing continuation.

## Final Readiness Criteria

- Source section `001-206` is verified without inferred boundaries.
- Seven source-faithful UTF-8 baselines cover every section exactly once.
- Seven detailed outlines diagnose every section without rewriting prose.
- The decision register and six specialist ledgers provide traceable evidence and downstream effects.
- `FB-002`, `FB-003`, `FB-004`, `FB-005`, `FB-015`, and `FB-016` are linked to volume-two evidence without being prematurely declared errors.
- The validator supports volume one, volume two, and `all` through one configuration-driven implementation.
- Volume-one validation remains green.
- No complete source or temporary extract is tracked.
- No second-volume prose rewrite begins before its batch receives a chief-editor readiness decision.
