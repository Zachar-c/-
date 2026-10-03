"""Validate the research ledger, scan candidates, or render its inline view."""
import argparse
import copy
import hashlib
import json
import re
from collections import Counter
from functools import lru_cache
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASES = {'canon', 'session', 'design'}
ROLES = {'input', 'output', 'auxiliary', 'state', 'participant',
         'structural-reference', 'proposed-auxiliary', 'inspiration',
         'process-tool', 'intervention'}
TYPES = {'recipe', 'reverse', 'lineage', 'supports', 'precondition', 'state',
         'tradeoff', 'conflict', 'sequence', 'integration', 'candidate', 'process-record'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique(rows, label):
    counts = Counter(row['id'] for row in rows)
    require(all(n == 1 for n in counts.values()), f'{label}: duplicate IDs')
    return {row['id']: row for row in rows}


@lru_cache(maxsize=1)
def novel_paragraphs():
    result = {}
    chapter = None
    for line in (ROOT / 'source/蛊真人-epub-canon.txt').read_text().splitlines():
        match = re.match(r'^=== (chapter_\d+)｜.* ===$', line)
        if match:
            chapter = match[1]
            number = 0
        elif chapter and line.strip():
            number += 1
            result[f'EPUB:{chapter}:para_{number:03}'] = line
    return result


def validate(data):
    nodes = unique(data['nodes'], 'nodes')
    relations = unique(data['relations'], 'relations')
    evidence = unique(data['evidence'], 'evidence')
    concepts = unique(data['concepts'], 'concepts')
    manifest = json.loads((HERE / 'sources.json').read_text())
    session_paths = {s['path'] for s in manifest['files']}
    for e in evidence.values():
        require(e['basis'] in {'canon', 'session'}, f'{e["id"]}: invalid evidence basis')
        path = ROOT / e['path']
        require(path.is_file(), f'{e["id"]}: missing source {path}')
        if e['basis'] == 'canon':
            require(e['path'] == 'source/蛊真人-epub-canon.txt', f'{e["id"]}: canon source path mismatch')
            text = novel_paragraphs().get(e['locator'])
            require(text is not None, f'{e["id"]}: missing EPUB paragraph')
            require(hashlib.sha256(text.encode()).hexdigest() == e['paragraph_sha256'],
                    f'{e["id"]}: changed EPUB paragraph; review source')
            require(text.startswith(e['excerpt']) and len(e['excerpt']) <= 60,
                    f'{e["id"]}: quote mismatch or more than 60 characters')
            require(not e.get('wiki') or (ROOT / e['wiki']).is_file(),
                    f'{e["id"]}: missing Wiki pointer')
        else:
            require(e['path'] in session_paths, f'{e["id"]}: session source is outside registered attachments')
            lines = path.read_text().splitlines()
            a, b = e['line_start'], e['line_end']
            require(1 <= a <= b <= len(lines), f'{e["id"]}: invalid line range')
            text = '\n'.join(lines[a-1:b])
            require(hashlib.sha256(text.encode()).hexdigest() == e['range_sha256'],
                    f'{e["id"]}: changed session range; review source')
    for n in nodes.values():
        require(n['basis'] in BASES, f'{n["id"]}: invalid basis')
        require(n['kind'] in {'gu', 'state', 'material', 'requirement'}, f'{n["id"]}: invalid kind')
        require(n.get('rank') is None or (type(n['rank']) is int and 1 <= n['rank'] <= 9),
                f'{n["id"]}: invalid rank')
        require(n['evidence'] and all(e in evidence for e in n['evidence']),
                f'{n["id"]}: missing evidence')
        require(all(c in concepts for c in n['provides'] + n['accepts']),
                f'{n["id"]}: undefined concept')
        if n['basis'] == 'canon':
            require(all(evidence[e]['basis'] == 'canon' for e in n['evidence']),
                    f'{n["id"]}: session evidence presented as canon')
        if n['basis'] == 'session':
            require(any(evidence[e]['basis'] == 'session' for e in n['evidence']),
                    f'{n["id"]}: session record needs session evidence')
    for r in relations.values():
        require(r['basis'] in BASES and r['type'] in TYPES, f'{r["id"]}: invalid classification')
        require(r['verification'] in {'attested', 'inferred', 'unresolved'}, f'{r["id"]}: invalid verification')
        require(len(r['participants']) >= 2, f'{r["id"]}: relation needs at least two endpoints')
        for p in r['participants']:
            require(p['node'] in nodes and p['role'] in ROLES, f'{r["id"]}: unknown endpoint/role')
            require(p['quantity'] is None or (type(p['quantity']) is int and p['quantity'] >= 1),
                    f'{r["id"]}: invalid quantity')
        require(r['evidence'] and all(e in evidence for e in r['evidence']), f'{r["id"]}: missing evidence')
        require(all(r[k] for k in ['mechanism', 'conditions', 'cost', 'limits']), f'{r["id"]}: missing boundary')
        if r['basis'] == 'canon':
            require(all(evidence[e]['basis'] == 'canon' for e in r['evidence']), f'{r["id"]}: mixed canon evidence')
            require(all(nodes[p['node']]['basis'] == 'canon' for p in r['participants']),
                    f'{r["id"]}: session endpoint presented as canon')
        if r['basis'] == 'design':
            require(r['verification'] != 'attested', f'{r["id"]}: design cannot be attested')
        if r['basis'] == 'session':
            require(any(evidence[e]['basis'] == 'session' for e in r['evidence']),
                    f'{r["id"]}: session relation needs session evidence')
        if r['type'] == 'candidate':
            require(r['verification'] != 'attested', f'{r["id"]}: candidate cannot be attested')
        if r['type'] in {'recipe', 'reverse', 'lineage'}:
            require(any(p['role'] == 'input' for p in r['participants']) and
                    any(p['role'] == 'output' for p in r['participants']), f'{r["id"]}: missing recipe direction')
        require(type(r['process_complete']) is bool, f'{r["id"]}: process completeness absent')
    prior = []
    for n in data['nodes']:
        if n['kind'] != 'gu':
            continue
        review = n.get('admission', {})
        require(review.get('prior_gu_ids') == prior, f'{n["id"]}: admission must review all earlier Gu')
        linked = set()
        for rid in review.get('relation_ids', []):
            require(rid in relations, f'{n["id"]}: unknown reviewed relation')
            participants = {p['node'] for p in relations[rid]['participants']}
            require(n['id'] in participants, f'{n["id"]}: reviewed relation does not involve new Gu')
            linked.update(participants.intersection(prior))
        unlinked = []
        for group in review.get('no_link_groups', []):
            require(group.get('reason', '').strip(), f'{n["id"]}: unlinked group needs reason')
            unlinked.extend(group['gu_ids'])
        require(len(unlinked) == len(set(unlinked)), f'{n["id"]}: duplicate unlinked review')
        require(not linked.intersection(unlinked) and linked.union(unlinked) == set(prior),
                f'{n["id"]}: admission dispositions must cover exactly all earlier Gu')
        prior.append(n['id'])
    bundle = hashlib.sha256(json.dumps(manifest['files'], ensure_ascii=False, sort_keys=True).encode()).hexdigest()
    require(bundle == manifest['bundle_sha256'], 'Source manifest bundle hash changed')
    for s in manifest['files'] + [manifest['conversation'], manifest['novel']]:
        require(hashlib.sha256((ROOT / s['path']).read_bytes()).hexdigest() == s['sha256'],
                f'{s["path"]}: source snapshot hash changed')
    return dict(gu=len(prior), other_nodes=len(nodes)-len(prior), relations=len(relations),
                evidence=len(evidence), basis=dict(Counter(r['basis'] for r in relations.values())),
                earlier_pairs_reviewed=sum(range(len(prior))))


def candidates(data, new_id):
    nodes = {n['id']: n for n in data['nodes']}
    require(new_id in nodes and nodes[new_id]['kind'] == 'gu', 'Candidate scan requires a Gu node ID')
    new = nodes[new_id]
    rows = []
    for old in data['nodes']:
        if old['id'] == new_id or old['kind'] != 'gu':
            continue
        existing = [r['id'] for r in data['relations'] if
                    {new_id, old['id']} <= {p['node'] for p in r['participants']}]
        forward = sorted(set(new['provides']) & set(old['accepts']))
        backward = sorted(set(old['provides']) & set(new['accepts']))
        overlap = sorted(set(new['provides']) & set(old['provides']))
        rows.append(dict(gu_id=old['id'], name=old['name'], existing_relations=existing,
                         new_to_old=forward, old_to_new=backward, same_function=overlap,
                         disposition='待人工核查条件/成本/限制' if existing or forward or backward or overlap else
                         '概念未命中；仍须审查配方/过程/冲突，不能判不兼容'))
    return dict(new_gu=new_id, scanned_gu=len(rows), warning='所有结果只是检索候选；绝不自动新增兼容关系', rows=rows)


def self_test(data):
    mutations = []
    bad = copy.deepcopy(data); bad['nodes'].append(copy.deepcopy(bad['nodes'][0])); mutations.append(bad)
    bad = copy.deepcopy(data); bad['nodes'][1]['admission']['prior_gu_ids'] = []; mutations.append(bad)
    bad = copy.deepcopy(data); bad['relations'][0]['basis'] = 'design'; mutations.append(bad)
    bad = copy.deepcopy(data); bad['relations'][0]['participants'][0]['node'] = 'split-nest'; mutations.append(bad)
    bad = copy.deepcopy(data); bad['nodes'][2]['admission']['no_link_groups'] = []; bad['nodes'][2]['admission']['relation_ids'] = []; mutations.append(bad)
    bad = copy.deepcopy(data); bad['evidence'][0]['path'] = next(e['path'] for e in bad['evidence'] if e['basis'] == 'session'); mutations.append(bad)
    bad = copy.deepcopy(data); next(r for r in bad['relations'] if r['basis'] == 'session')['evidence'] = [bad['evidence'][0]['id']]; mutations.append(bad)
    bad = copy.deepcopy(data); next(n for n in bad['nodes'] if n['basis'] == 'session')['evidence'] = [bad['evidence'][0]['id']]; mutations.append(bad)
    for bad in mutations:
        try:
            validate(bad)
        except ValueError:
            continue
        raise ValueError('Negative self-check accepted an invalid ledger')
    scan = candidates(data, 'split-nest')
    require(scan['scanned_gu'] == sum(n['kind'] == 'gu' for n in data['nodes']) - 1,
            'Candidate scan omitted a Gu')
    return len(mutations) + 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--self-test', action='store_true')
    parser.add_argument('--candidates', metavar='GU_ID')
    parser.add_argument('--render', type=Path, metavar='ABSOLUTE_HTML_PATH')
    args = parser.parse_args()
    data = json.loads((HERE / 'graph.json').read_text())
    if args.candidates:
        print(json.dumps(candidates(data, args.candidates), ensure_ascii=False, indent=2))
        return
    result = validate(data)
    if args.self_test:
        result['negative_and_scan_checks'] = self_test(data)
    if args.render:
        require(args.render.is_absolute(), 'Use a durable absolute task-owned visualization path')
        require(args.render.resolve() not in {p.resolve() for p in HERE.iterdir()}, 'Do not overwrite research source')
        serialized = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')
        template = (HERE / 'graph-view.html').read_text()
        require(template.count('__GRAPH_JSON__') == 1, 'Visualization data placeholder is missing/ambiguous')
        args.render.parent.mkdir(parents=True, exist_ok=True)
        args.render.write_text(template.replace('__GRAPH_JSON__', serialized))
        result['rendered'] = str(args.render)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
