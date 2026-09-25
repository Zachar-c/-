// Canon 查询层：只读 DATA.canon（build_data.mjs 从 lore/runtime 注入的 Wiki 编译投影）。
// Canon 层不含游戏数值；这里是"游戏引用 Canon、不手抄原著口径"的唯一运行时入口。
// DATA.canon 为 null 时（未编译 runtime）全部查询降级为空，游戏行为不变。
const Canon = (() => {
  const data = typeof DATA !== 'undefined' ? DATA.canon : null;
  const STATUS_LABEL = {
    verified: '',
    divergence: '转数分叉待裁',
    rank_cap: '品阶上限压缩',
    name_reuse: '原著同名重用',
    collision: '命名碰撞待核',
    timepoint: '多时点口径',
    unverified: '转数未核',
  };
  const entry = (id) => (data && data.entities[id]) || null;
  const relationsOf = (id) => {
    if (!data) return [];
    return data.relations.filter((r) => r.from === id || r.to === id
      || (r.inputs || []).includes(id) || r.output === id);
  };
  // canon 与游戏口径的偏差提示：仅在不一致或状态非 verified 时返回文案（一致时保持静默，不加噪）。
  const canonAlert = (id, gameRank) => {
    const e = entry(id);
    if (!e || e.rank == null) return '';
    const label = STATUS_LABEL[e.rankStatus] || '原著口径待核';
    if (e.rankStatus === 'verified' && Number(e.rank) === Number(gameRank)) return '';
    return `原著 ${e.rank} 转${label ? ` · ${label}` : ''}`;
  };
  return {
    entry, relationsOf, canonAlert,
    relationLine: (id) => relationsOf(id).map((r) => r.statement).join('；'),
    enabled: !!data,
    contentVersion: data ? data.contentVersion : null,
  };
})();
