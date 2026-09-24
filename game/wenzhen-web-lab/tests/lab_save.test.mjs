import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../js/lab_save.js', import.meta.url), 'utf8');
// Same-realm load so decode's JSON.parse yields objects deep-equal to test fixtures.
vm.runInThisContext(source);
const LabSave = globalThis.LabSave;

const CONTENT = 'test-content';

function sampleState(overrides = {}) {
  return {
    seed: 101,
    cultivation: 1,
    cultivationStage: 0,
    school: 'light',
    stones: 3,
    blood: 24,
    bloodMax: 24,
    lifeTime: 60,
    soul: 1,
    soulMax: 4,
    aptitude: 'bing',
    stage: 'one',
    owned: { moonlight_gu: 1, small_light_gu: 1 },
    wild: { small_light_gu: 2 },
    equipped: [],
    battle: null,
    qiMax: 20,
    qi: 20,
    thought: 2,
    thoughtMax: 2,
    journey: {
      difficulty: 'normal',
      graph: {
        roots: ['L1D0N0'],
        nodes: [{ id: 'L1D0N0', nextIds: ['L1D1N0'], type: 'battle', segment: 1, depth: 0, slot: 0, name: 'n0' }],
        prepPerSegment: 10,
        seed: 101,
      },
      nodeId: null,
      availableNodeIds: ['L1D0N0'],
      completed: [],
      started: true,
    },
    prepFor: null,
    reward: null,
    ending: null,
    shopSold: [],
    restUsed: false,
    journal: ['x'],
    page: 'map',
    lootPity: 0,
    globalCodexIds: [],
    knownFacts: [],
    eventLog: [{ id: 'event_0000', time: 0, action: 'run_started', reason: 'new_run', after: {}, targets: [] }],
    ...overrides,
  };
}

function memoryStorage(initial = {}) {
  const map = new Map(Object.entries(initial));
  return {
    map,
    getItem(key) {
      return map.has(key) ? map.get(key) : null;
    },
    setItem(key, value) {
      map.set(key, String(value));
    },
    removeItem(key) {
      map.delete(key);
    },
  };
}

test('encode/decode full roundtrip preserves state', () => {
  const stateBefore = sampleState();
  const raw = LabSave.encode(stateBefore, CONTENT);
  assert.equal(typeof raw, 'string');
  const restored = LabSave.decode(raw, CONTENT);
  assert.equal(restored.ok, true);
  assert.deepEqual(restored.state, stateBefore);
});

test('encode envelope shape is fixed {schemaVersion:1, contentVersion, state}', () => {
  const raw = LabSave.encode(sampleState(), CONTENT);
  const parsed = JSON.parse(raw);
  assert.equal(parsed.schemaVersion, 1);
  assert.equal(parsed.contentVersion, CONTENT);
  assert.equal(typeof parsed.state, 'object');
  assert.equal(parsed.state.seed, 101);
});

test('decode rejects bad JSON', () => {
  assert.equal(LabSave.decode('{', CONTENT).ok, false);
  assert.equal(LabSave.decode('', CONTENT).ok, false);
  assert.equal(LabSave.decode('not-json', CONTENT).ok, false);
});

test('decode rejects schemaVersion mismatch', () => {
  const envelope = { schemaVersion: 2, contentVersion: CONTENT, state: sampleState() };
  const result = LabSave.decode(JSON.stringify(envelope), CONTENT);
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'schema_mismatch');
});

test('decode rejects contentVersion mismatch', () => {
  const raw = LabSave.encode(sampleState(), 'other-content');
  const result = LabSave.decode(raw, CONTENT);
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'content_mismatch');
});

test('decode rejects missing critical state fields', () => {
  const noSeed = sampleState();
  delete noSeed.seed;
  assert.equal(LabSave.decode(LabSave.encode(noSeed, CONTENT), CONTENT).ok, false);

  const noJourney = sampleState();
  delete noJourney.journey;
  const r1 = LabSave.decode(LabSave.encode(noJourney, CONTENT), CONTENT);
  assert.equal(r1.ok, false);
  assert.equal(r1.reason, 'missing_state');

  const badGraph = sampleState();
  badGraph.journey = { ...badGraph.journey, graph: { roots: [], nodes: null } };
  const r2 = LabSave.decode(LabSave.encode(badGraph, CONTENT), CONTENT);
  assert.equal(r2.ok, false);
  assert.equal(r2.reason, 'missing_state');

  const noOwned = sampleState();
  delete noOwned.owned;
  assert.equal(LabSave.decode(LabSave.encode(noOwned, CONTENT), CONTENT).ok, false);

  const notObject = LabSave.decode(JSON.stringify({ schemaVersion: 1, contentVersion: CONTENT, state: null }), CONTENT);
  assert.equal(notObject.ok, false);
  assert.equal(notObject.reason, 'missing_state');
});

test('repeated restore is idempotent and stable', () => {
  const stateBefore = sampleState();
  const raw = LabSave.encode(stateBefore, CONTENT);
  const first = LabSave.decode(raw, CONTENT);
  const second = LabSave.decode(raw, CONTENT);
  assert.equal(first.ok, true);
  assert.equal(second.ok, true);
  assert.deepEqual(first.state, second.state);
  assert.deepEqual(first.state, stateBefore);

  const storage = memoryStorage();
  assert.equal(LabSave.write(storage, stateBefore, CONTENT).ok, true);
  const r1 = LabSave.read(storage, CONTENT);
  const r2 = LabSave.read(storage, CONTENT);
  assert.equal(r1.ok, true);
  assert.equal(r2.ok, true);
  assert.deepEqual(r1.state, r2.state);
  assert.deepEqual(r1.state, stateBefore);
});

test('write/read via storage adapter roundtrips', () => {
  const storage = memoryStorage();
  const stateBefore = sampleState();
  const writeResult = LabSave.write(storage, stateBefore, CONTENT);
  assert.equal(writeResult.ok, true);
  assert.ok(storage.map.has(LabSave.KEY));
  const readResult = LabSave.read(storage, CONTENT);
  assert.equal(readResult.ok, true);
  assert.deepEqual(readResult.state, stateBefore);
});

test('read on empty storage reports empty and does not invent a run', () => {
  const storage = memoryStorage();
  const result = LabSave.read(storage, CONTENT);
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'empty');
  assert.equal(result.empty, true);
  assert.equal(result.state, undefined);
});

test('bad save keeps raw text and does not overwrite', () => {
  const storage = memoryStorage({ [LabSave.KEY]: '{corrupt' });
  const result = LabSave.read(storage, CONTENT);
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'bad_json');
  assert.equal(result.raw, '{corrupt');
  assert.equal(storage.map.get(LabSave.KEY), '{corrupt');

  const envelopeRaw = LabSave.encode(sampleState(), 'stale-content');
  const storage2 = memoryStorage({ [LabSave.KEY]: envelopeRaw });
  const mismatch = LabSave.read(storage2, CONTENT);
  assert.equal(mismatch.ok, false);
  assert.equal(mismatch.reason, 'content_mismatch');
  assert.equal(mismatch.raw, envelopeRaw);
  assert.equal(storage2.map.get(LabSave.KEY), envelopeRaw);
});

test('storage rejection is captured and does not throw', () => {
  const denied = {
    getItem() {
      throw new Error('access denied');
    },
    setItem() {
      throw new Error('access denied');
    },
    removeItem() {
      throw new Error('access denied');
    },
  };
  const writeResult = LabSave.write(denied, sampleState(), CONTENT);
  assert.equal(writeResult.ok, false);
  assert.equal(writeResult.reason, 'storage_error');
  const readResult = LabSave.read(denied, CONTENT);
  assert.equal(readResult.ok, false);
  assert.equal(readResult.reason, 'storage_error');
});

test('storage capacity exception is captured as quota', () => {
  const quota = memoryStorage();
  quota.setItem = () => {
    const err = new Error('quota exceeded');
    err.name = 'QuotaExceededError';
    throw err;
  };
  const writeResult = LabSave.write(quota, sampleState(), CONTENT);
  assert.equal(writeResult.ok, false);
  assert.equal(writeResult.reason, 'quota');
});

test('missing storage interface is captured and does not throw', () => {
  const writeResult = LabSave.write(null, sampleState(), CONTENT);
  assert.equal(writeResult.ok, false);
  assert.equal(writeResult.reason, 'storage_error');
  const readResult = LabSave.read(undefined, CONTENT);
  assert.equal(readResult.ok, false);
  assert.equal(readResult.reason, 'storage_error');
});

test('clear removes the run key and tolerates storage errors', () => {
  const storage = memoryStorage({ [LabSave.KEY]: 'raw' });
  assert.equal(LabSave.clear(storage).ok, true);
  assert.equal(storage.map.has(LabSave.KEY), false);
  const denied = {
    getItem: () => null,
    setItem() {
      throw new Error('nope');
    },
    removeItem() {
      throw new Error('nope');
    },
  };
  assert.equal(LabSave.clear(denied).ok, false);
});

test('KEY is the contracted local run key', () => {
  assert.equal(LabSave.KEY, 'wenzhen.lab.run.v1');
});
