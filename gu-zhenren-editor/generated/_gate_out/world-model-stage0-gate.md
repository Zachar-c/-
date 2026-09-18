# World Model Stage 0 Gate

- Result: **GO**
- Exact command: `tools/lore.ps1 world-model-0 --config lore_engine/config/world-model-stage0.json --out generated/_gate_out`
- Deterministic repeated output: `true`
- Provenance verified: `true`

## Source hashes

- `gu_zhenren_main`: `95cd0b13684e5ce9c47dea0c198d3ecfc1a7182c2263674cb021af6cbb287647`
- `ren_zu_zhuan`: `acc3ec34b7606ebcb96626b5bb3672d894e12c80cce8aa46ecacca28b7749155`

## Output hashes

- `world-model-baseline-v1.json`: `7e72da4775a8095872db86262a802a4d73f0e913b030e428b1f796aa05c6cb8c`
- `world-model-baseline-v1.md`: `a30f2e95b478722dbc7ab147038fb8750d1e40695771ce37c77d0728647ca619`

## Claim coverage

- Target topics represented: `24/24`
- High-impact claims with complete P0 references: `24`
- Total baseline rows: `24`

## Unresolved items

- None.
- Unresolved P0 conflicts: None.
- Non-blocking deferred claims: None.

## Legacy dispositions

- `f1_pity` -> `audit_only`: F1 Pity is historical implementation context and cannot authorize Stage 0 production behavior.
- `promotion_economy` -> `defer`: Promotion economy remains deferred until source evidence and the later economy slice are adjudicated.
- `promotion_materials` -> `defer`: Promotion materials remain deferred until source evidence and the later refinement slice are adjudicated.
- `q8g_promotion_chain` -> `audit_only`: Q8-G is retained only as an audit trail and is not a production-ready world rule.
- `school_promotion` -> `defer`: School promotion remains deferred while school-as-class semantics are under review.

## Production boundary

- Changed forbidden paths: None.
- Gate blockers: None.

## Forbidden follow-up actions before Gate approval

- Do not modify `data/`, `scripts/`, or `scenes/` from Stage 0 findings.
- Do not implement or restore Q8-G promotion or F1 Pity behavior.
- Do not migrate saves, remove legacy fields, or silently preserve deprecated behavior.
- Do not start the vertical-slice production implementation until this Gate is reviewed and approved.
