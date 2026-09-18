# First Volume Foundation Ledgers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete editorial constraint system for volume one, sections 001-199, before any further prose revision.

**Architecture:** Preserve the existing batch ledgers as historical evidence and add volume-scoped ledgers with stable IDs, section ranges, evidence grades, decision states, and downstream effects. A decision register is the authoritative index; combat, resources, chronology/geography, character state, and foreshadowing ledgers provide the evidence used by each decision.

**Tech Stack:** UTF-8 Markdown and CSV, PowerShell validation, Git.

## Global Constraints

- Do not modify the edited novel text during this phase.
- Do not alter the main event order, outcomes, character endings, or information-release order.
- Treat later stable canon and demonstrated combat performance as stronger evidence than isolated early labels.
- Distinguish confirmed errors, reconstructable ambiguities, character knowledge, and unresolved disputes.
- Record every ruling with section scope and downstream impact.

---

### Task 1: Combat and Beast-Group Ledger

**Files:**
- Create: `notes/vol1-combat-ledger.md`

- [x] Record the rank model and the difference between threat tier and duel equivalence.
- [x] Map the three villages before, during, and after the wolf tide.
- [x] Map ordinary beasts, hundred-beast kings, thousand-beast kings, myriad-beast kings, and beast emperors.
- [x] Record the confirmed crane-army reconstruction: one rank-five ironbeak flying crane emperor, no rank-four myriad-beast king subordinate, many rank-two/rank-three beast kings.
- [x] Record every battle whose demonstrated performance overrides an early label.
- [x] Validate that every ruling has an exact section range and evidence grade.

### Task 2: Resource and Purchasing-Power Ledger

**Files:**
- Create: `notes/vol1-resource-audit.md`
- Preserve: `notes/resource-ledger.csv`

- [x] Establish civilian, rank-one, rank-two, elder, lineage, and clan economic scales.
- [x] Reconcile all confirmed income and expenditure anchors.
- [x] Isolate FD002 and FD007 instead of choosing unsupported figures.
- [x] Classify the 10,000, 40,000, and 50,000 primeval-stone transactions as organizational-scale flows.
- [x] Record every amount that must be recalculated before prose revision.

### Task 3: Chronology and Geography Ledger

**Files:**
- Create: `notes/vol1-chronology-geography.md`
- Preserve: `notes/timeline-ledger.csv`

- [x] Build the relative sequence from rebirth through the destruction of Qing Mao Mountain.
- [x] Mark exact dates that remain unsupported.
- [x] Define Qing Mao Mountain's local travel zones and the three-village battlefield.
- [x] Rule that the hundred-li competition area is a boundary, not a required one-day traversal.
- [x] Move the Yellow Dragon River voyage to volume two's future audit scope.

### Task 4: Character-State Ledger

**Files:**
- Create: `notes/vol1-character-state-ledger.md`
- Preserve: `notes/character-ledger.csv`

- [x] Track Fang Yuan, Fang Zheng, Bai Ning Bing, Tie Ruo Nan, Gu Yue Bo, first-generation Gu Yue, Lord Sky Crane, and the three village leadership states.
- [x] Record motivation, knowledge, resources, injuries, alliances, and end-of-volume state at each phase boundary.
- [x] Flag transitions that current prose states too abruptly.

### Task 5: Foreshadowing and Information Ledger

**Files:**
- Create: `notes/vol1-information-ledger.md`
- Preserve: `notes/foreshadowing-ledger.csv`

- [x] Separate reader knowledge, Fang Yuan's knowledge, local character knowledge, false history, and later-book truth.
- [x] Protect delayed revelations concerning Spring Autumn Cicada, Heaven's Will, venerables, Bai Ning Bing, and the Gu Yue ancestor.
- [x] Map setup and payoff sections inside volume one.

### Task 6: P0/P1 Decision Register

**Files:**
- Create: `notes/vol1-decision-register.md`
- Modify: `notes/fact-disputes.csv`

- [x] Record the volume-boundary contamination as P0.
- [x] Record wolf-tide scale, combat correspondence, crane emperor, crane-army composition, economy, geography, and Blood Sea inheritance rulings.
- [x] Mark the user-approved crane-army option B as decided.
- [x] Add unresolved numeric conflicts to the fact-dispute CSV without overwriting historical rows.

### Task 7: Regression Validation

**Files:**
- Validate: `notes/vol1-*.md`
- Validate: `notes/fact-disputes.csv`

- [x] Confirm all five ledgers cover sections 001-199.
- [x] Confirm every P0/P1 entry has evidence, ruling, affected sections, and downstream impact.
- [x] Scan for placeholders and encoding residue.
- [x] Confirm no edited novel file changed during this phase.
- [x] Review `git diff --check` and working-tree status.
