// LabSave：局内存档信封的纯编解码与 storage 读写适配。
// 普通脚本：挂到全局 LabSave，装载顺序必须在 main.js 之前。
// 纯函数不触碰浏览器全局；storage 由调用方注入（浏览器 localStorage / 测试内存适配）。
globalThis.LabSave = (() => {
  const KEY = 'wenzhen.lab.run.v1';
  const SCHEMA_VERSION = 1;

  function isPlainObject(value) {
    return !!value && typeof value === 'object' && !Array.isArray(value);
  }

  function missingCriticalState(state) {
    if (!isPlainObject(state)) return true;
    if (!Number.isFinite(Number(state.seed))) return true;
    if (!isPlainObject(state.journey)) return true;
    const journey = state.journey;
    if (typeof journey.difficulty !== 'string' || !journey.difficulty) return true;
    if (!isPlainObject(journey.graph)) return true;
    if (!Array.isArray(journey.graph.nodes)) return true;
    if (!Array.isArray(journey.graph.roots)) return true;
    if (!Array.isArray(journey.availableNodeIds)) return true;
    if (!Array.isArray(journey.completed)) return true;
    if (typeof journey.started !== 'boolean') return true;
    if (!isPlainObject(state.owned)) return true;
    if (!Number.isFinite(Number(state.stones))) return true;
    if (!Number.isFinite(Number(state.blood))) return true;
    if (!isPlainObject(state.materials)) return true;
    if (!Array.isArray(state.shopSold)) return true;
    if (!Array.isArray(state.equipped)) return true;
    if (!Array.isArray(state.journal)) return true;
    if (!Array.isArray(state.eventLog)) return true;
    if (typeof state.page !== 'string' || !state.page) return true;
    if (state.battle != null) {
      if (!isPlainObject(state.battle)) return true;
      if (!Array.isArray(state.battle.enemies)) return true;
    }
    return false;
  }

  function encode(state, contentVersion) {
    return JSON.stringify({
      schemaVersion: SCHEMA_VERSION,
      contentVersion,
      state,
    });
  }

  function decode(text, contentVersion) {
    if (typeof text !== 'string' || text.length === 0) {
      return { ok: false, reason: 'empty' };
    }
    let envelope;
    try {
      envelope = JSON.parse(text);
    } catch {
      return { ok: false, reason: 'bad_json', raw: text };
    }
    if (!isPlainObject(envelope)) {
      return { ok: false, reason: 'bad_envelope', raw: text };
    }
    if (Number(envelope.schemaVersion) !== SCHEMA_VERSION) {
      return { ok: false, reason: 'schema_mismatch', raw: text };
    }
    if (envelope.contentVersion !== contentVersion) {
      return { ok: false, reason: 'content_mismatch', raw: text };
    }
    if (missingCriticalState(envelope.state)) {
      return { ok: false, reason: 'missing_state', raw: text };
    }
    return { ok: true, state: envelope.state };
  }

  function storageError(error) {
    if (error && error.name === 'QuotaExceededError') {
      return { ok: false, reason: 'quota', error: String(error && error.message ? error.message : error) };
    }
    return { ok: false, reason: 'storage_error', error: String(error && error.message ? error.message : error) };
  }

  function write(storage, state, contentVersion) {
    try {
      if (!storage || typeof storage.setItem !== 'function') {
        return { ok: false, reason: 'storage_error', error: 'storage unavailable' };
      }
      storage.setItem(KEY, encode(state, contentVersion));
      return { ok: true };
    } catch (error) {
      return storageError(error);
    }
  }

  function read(storage, contentVersion) {
    try {
      if (!storage || typeof storage.getItem !== 'function') {
        return { ok: false, reason: 'storage_error', error: 'storage unavailable' };
      }
      const text = storage.getItem(KEY);
      if (text == null) {
        return { ok: false, reason: 'empty', empty: true };
      }
      const decoded = decode(String(text), contentVersion);
      if (!decoded.ok) {
        return {
          ok: false,
          reason: decoded.reason,
          raw: decoded.raw != null ? decoded.raw : String(text),
        };
      }
      return { ok: true, state: decoded.state };
    } catch (error) {
      return storageError(error);
    }
  }

  function clear(storage) {
    try {
      if (!storage || typeof storage.removeItem !== 'function') {
        return { ok: false, reason: 'storage_error', error: 'storage unavailable' };
      }
      storage.removeItem(KEY);
      return { ok: true };
    } catch (error) {
      return storageError(error);
    }
  }

  return {
    KEY,
    SCHEMA_VERSION,
    encode,
    decode,
    write,
    read,
    clear,
    missingCriticalState,
  };
})();
