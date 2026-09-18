# Complete Source Index Audit

This report audits and normalizes the index only. It does not modify or copy the complete source.

## Source statistics

- Source path: `C:\DevEnv\05_Downloads\蛊真人.txt`
- Encoding: CP936 / GBK
- Bytes: 16576824
- Lines: 437060
- Decoded characters excluding newlines: 8320079
- User-stated character count: 14577005
- Existing raw index rows: 724
- Reparsed heading candidates: 724
- Duplicate section numbers: 208
- Sequence runs: 25
- Rows requiring review: 41

## Rules

- Keep every recognizable section-heading candidate; never delete a duplicate silently.
- Mark site, author, page, and directory candidates in noise_flags instead of treating them as clean story facts.
- Mark only a clean, strictly increasing run of at least three candidates as canonical_candidate=true.
- Keep duplicates, gaps, decreases, and noisy rows as review_required=true until an editor approves a source range.

## Sequence runs

| Run | Count | First line | Last line | First section | Last section | Canonical candidates | Review rows |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 207 | 426 | 34410 | 1 | 199 | 198 | 9 |
| 2 | 214 | 34590 | 75004 | 1 | 206 | 205 | 9 |
| 3 | 127 | 75384 | 97626 | 1 | 127 | 126 | 1 |
| 4 | 1 | 97796 | 97796 | 124 | 124 | 0 | 1 |
| 5 | 116 | 97968 | 120866 | 129 | 244 | 115 | 1 |
| 6 | 36 | 121058 | 126684 | 1 | 36 | 35 | 1 |
| 7 | 1 | 165164 | 165164 | 261 | 261 | 0 | 1 |
| 8 | 1 | 167914 | 167914 | 274 | 274 | 0 | 1 |
| 9 | 1 | 168316 | 168316 | 276 | 276 | 0 | 1 |
| 10 | 1 | 170712 | 170712 | 288 | 288 | 0 | 1 |
| 11 | 1 | 171536 | 171536 | 292 | 292 | 0 | 1 |
| 12 | 1 | 174456 | 174456 | 306 | 306 | 0 | 1 |
| 13 | 1 | 174982 | 174982 | 308 | 308 | 0 | 1 |
| 14 | 1 | 195908 | 195908 | 39 | 39 | 0 | 1 |
| 15 | 1 | 203362 | 203362 | 78 | 78 | 0 | 1 |
| 16 | 1 | 204724 | 204724 | 85 | 85 | 0 | 1 |
| 17 | 1 | 208742 | 208742 | 104 | 104 | 0 | 1 |
| 18 | 2 | 237672 | 237884 | 255 | 256 | 0 | 1 |
| 19 | 1 | 239270 | 239270 | 263 | 263 | 0 | 1 |
| 20 | 1 | 240798 | 240798 | 270 | 270 | 0 | 1 |
| 21 | 1 | 274432 | 274432 | 445 | 445 | 0 | 1 |
| 22 | 2 | 278346 | 278504 | 467 | 468 | 0 | 1 |
| 23 | 2 | 289108 | 289266 | 533 | 534 | 0 | 1 |
| 24 | 2 | 289398 | 289554 | 533 | 534 | 0 | 1 |
| 25 | 1 | 386824 | 386824 | 70 | 70 | 0 | 1 |

## Raw index comparison

- Reparsed lines absent from the existing raw index: 0
- Existing raw-index lines not reparsed by this script: 0

## Manual review boundary

- canonical_candidate=true is a candidate only, not a final volume or arc boundary.
- Later outlines may cite only source ranges that have been manually approved from source context.
- Computed source statistics and the user-stated character count are kept as separate values.
