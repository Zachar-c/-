# SDD Progress Ledger

- Execution mode: subagent-style task isolation with local implementer/reviewer artifacts because no dispatch API is exposed in this desktop tool context.
- Plan: docs/superpowers/plans/2026-08-06-outline-calibration-implementation.md

- Task 1: complete locally; normalized index and source audit generated, reviewed, and ready for checkpoint.
- Task 1 review: 724 candidates preserved; 679 clean canonical candidates; 41 rows require review because of duplicates, sequence breaks, or source noise; computed and user-stated character counts remain separate.
- Task 2: complete locally; outline schema, fact-dispute ledger, and staged validator added.
- Task 2 review: baseline validation passed; outline phase correctly blocks until the master outline exists; six dispute rows import successfully.

- Task 3: complete locally; six-volume master outline added at `outlines/00-full-book-outline.md`.
- Task 3 review: UTF-8 content review completed; six volume headings and six required subsections per volume are present; master outline includes the full causal chain, protagonist and character arcs, faction/resource/theme maps, climax and foreshadowing map, disclosure-order rules, and references to FD001-FD006.
- Task 3 validation: `scripts/validate_editorial_assets.ps1 -Phase outline` passed; `git diff --check` passed; the complete source remains outside Git and the unrelated untracked EPUB/script files were not touched.

- Task 4: complete locally; first three volume-level chapter outlines created at `outlines/volumes/01-魔性不改.md` through `03-魔头乱世.md`.
- Task 4 review: shared volume schema present; causal chains, climax/aftermath, resource boundaries, information-release rules, and first-volume links to the first-twenty trial context are recorded.
- Task 5: complete locally; last three volume-level chapter outlines created at `outlines/volumes/04-魔君纵横.md` through `06-魔尊永生.md`.
- Task 5 review: the two Wangting wars are separated; Yitian Mountain, Reverse Flow River, pre-Fate War, Ghost Soul pursuit, Crazy Demon Cave, immortality, Zunzhe, Refining Heaven, Great Love, and post-Fate arcs are treated as causal state changes rather than result lists. Late-source line gaps remain explicitly qualified.
- Task 5 validation: `scripts/validate_editorial_assets.ps1 -Phase outline` passed; all six volume files are strict UTF-8 and contain the shared eleven-section schema. Existing untracked EPUB/build-script files and the complete source were not touched.

- Task 6: complete locally; the transition map and ten named climax/war outlines now cover Qing Mao Mountain, Three Kings Mountain, the two Wangting stages, Yitian Mountain, Reverse Flow River, the pre-Fate War, the post-Fate War, Ghost Soul pursuit, and Crazy Demon Cave.
- Task 6 review: the six newly added late-stage outlines preserve event-level rules, protagonist goals, faction goals, resource limits, escalation, turning points, irreversible consequences, character changes, disclosure order, and editorial boundaries. Reverse Flow River is treated as a process-driven rule-bound炼蛊高潮 rather than a combat result; the pre- and post-Fate stages remain separate; the complete source remains outside Git.
- Task 6 validation: `scripts/validate_editorial_assets.ps1 -Phase outline` passed; `git diff --check` passed. Existing untracked EPUB/build-script files were not touched.

- Next task: create `outlines/detail/vol1-sec001-010.md` and `outlines/detail/vol1-sec011-020.md`, then use those detail outlines to recalibrate the first-twenty edited sections and record each actual text change in `notes/editorial-notes.md`.


## Candidate pipeline plan (2026-08-09)

- Task 1: complete (commit 6fb2d6f; review clean, Approved; 6 Minor logged M-1..M-6)
- Minor notes: M-1 empty candidate TSV headless output (harmless); M-2 resolve_batch_path inlined per code; M-3 ResourceWarning in tests; M-4 seq not sorted (set at scan time); M-5 placeholder leftovers expected; M-6 no trailing newline in serialized md — check in final review
- .gitignore extended: working/candidates-*.tsv|md, apply-*.log, audit-*.tsv (pending dedicated commit)
- Rebase fold-in: remote advanced 4 commits during Task 1; user vol3-sec091-120 changes preserved
- Task 2: complete (commit 223c683; review Approved; Minor: M2 CHINESE_NUM dead code, M3 f8ff redundant, M4 wordlist test fragility, M5 repeat line assertion blind spot; mojibake plan sample corrected \xfc->U+FFFD — plan erratum noted)
- Note: scan smoke produced ~30 candidates on vol3-151-180 per implementer report (verify at Task 6)
- Task 3: complete (commit 2483df6 review Approved w/ Important I1-I3; fix commit added: per-occurrence quote check, newline='' preserve, apply_to_file + integration tests) — re-review pending
- Task 3 re-review: I1 closed, I3 closed; I2 closed at eb81cae (byte-level IO, BOM both-way); MINOR backlog: single-quote pair untested, skipped multi-entry semantics, LF assert ambiguous

- Task 4: complete (commit pending; -Candidates switch added to gen_brief/gen_report, candidate stats section, audit stats section, tests/test_brief_report_candidates.py 7 cases green; fixed BOM/tab reading mismatch discovered while testing)

- Task 6: pilot run vol3-151-180 complete (scan 30 B-level redact candidates; -Apply wordlist 0 hits; 30/30 redaction words restored to text with verdicts logged; audit table generated pending user tick; V3-DEC-017/018 logged; commit pending)
