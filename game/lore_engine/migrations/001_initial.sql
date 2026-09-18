CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sources (
    source_file_id TEXT PRIMARY KEY,
    path TEXT NOT NULL,
    encoding TEXT NOT NULL,
    authority TEXT NOT NULL,
    default_claim_type TEXT NOT NULL,
    bytes INTEGER NOT NULL,
    characters INTEGER NOT NULL,
    sha256 TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS chapters (
    source_id TEXT PRIMARY KEY,
    source_file_id TEXT NOT NULL REFERENCES sources(source_file_id),
    volume INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    title TEXT NOT NULL,
    sequence INTEGER NOT NULL,
    start_offset INTEGER NOT NULL,
    end_offset INTEGER NOT NULL,
    start_byte INTEGER NOT NULL,
    end_byte INTEGER NOT NULL,
    text TEXT NOT NULL,
    text_hash TEXT NOT NULL,
    diagnostics_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS chunks (
    chunk_id TEXT PRIMARY KEY,
    source_id TEXT NOT NULL REFERENCES chapters(source_id),
    source_file_id TEXT NOT NULL REFERENCES sources(source_file_id),
    volume INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    title TEXT NOT NULL,
    sequence INTEGER NOT NULL,
    chunk_sequence INTEGER NOT NULL,
    start_offset INTEGER NOT NULL,
    end_offset INTEGER NOT NULL,
    start_byte INTEGER NOT NULL,
    end_byte INTEGER NOT NULL,
    text TEXT NOT NULL,
    chunk_hash TEXT NOT NULL,
    previous_id TEXT,
    next_id TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING',
    UNIQUE(source_id, chunk_sequence)
);

CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(chunk_id UNINDEXED, text, tokenize='trigram');

CREATE TABLE IF NOT EXISTS entities (entity_key TEXT PRIMARY KEY, entity_type TEXT NOT NULL, payload_json TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS entity_aliases (entity_id TEXT NOT NULL, alias TEXT NOT NULL, match_status TEXT NOT NULL, payload_json TEXT NOT NULL, PRIMARY KEY(entity_id, alias, match_status));
CREATE TABLE IF NOT EXISTS facts (fact_key TEXT PRIMARY KEY, source_id TEXT NOT NULL, chunk_id TEXT NOT NULL, payload_json TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS events (event_key TEXT PRIMARY KEY, source_id TEXT NOT NULL, chunk_id TEXT NOT NULL, payload_json TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS relations (relation_key TEXT PRIMARY KEY, source_id TEXT NOT NULL, chunk_id TEXT NOT NULL, payload_json TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS rule_candidates (rule_key TEXT PRIMARY KEY, source_id TEXT NOT NULL, chunk_id TEXT NOT NULL, payload_json TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS conflicts (conflict_key TEXT PRIMARY KEY, source_id TEXT NOT NULL, chunk_id TEXT NOT NULL, payload_json TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS extraction_runs (run_id TEXT PRIMARY KEY, chunk_id TEXT NOT NULL, input_hash TEXT NOT NULL, backend TEXT NOT NULL, model TEXT NOT NULL, status TEXT NOT NULL, error_code TEXT, payload_json TEXT NOT NULL);
