// 新跑局流程的确定性规则。节点图先生成、玩家只选择当前可见后继；
// 页面层只负责展示，不在 journey.js/main.js 里另算图形。
globalThis.RunFlow = (() => {
  const STAGE_LABELS = ['初阶', '中阶', '高阶', '巅峰'];
  const DEFAULT_DIFFICULTIES = {
    easy: { label: '简单', prepPerSegment: 15 },
    normal: { label: '普通', prepPerSegment: 10 },
    hard: { label: '困难', prepPerSegment: 5 },
  };

  const nodeId = (segment, depth, slot) => `L${segment}D${depth}N${slot}`;
  const bossId = (segment) => `L${segment}B`;

  function stageLabel(rank, stageIndex) {
    const safeRank = Math.max(1, Math.min(5, Number(rank) || 1));
    const safeStage = Math.max(0, Math.min(3, Number(stageIndex) || 0));
    return `${safeRank} 转${STAGE_LABELS[safeStage]}`;
  }

  function stageIndexFor(rank) {
    return Math.max(0, Math.min(3, Number(rank) || 0));
  }

  function pickId(items, seed, salt, tick = 0) {
    const pool = [...(items || [])].filter(Boolean);
    if (!pool.length) return '';
    return String(pool[RunRules.seededIndex(pool.length, seed, salt, tick)]);
  }

  function pickEnemyIds(pool, count, seed, salt) {
    const available = [...new Set((pool || []).map(String).filter(Boolean))];
    const wanted = Math.max(1, Math.min(available.length, Math.floor(Number(count) || 1)));
    const picked = [];
    for (let i = 0; i < wanted; i += 1) {
      const candidates = available.filter((id) => !picked.includes(id));
      if (!candidates.length) break;
      picked.push(pickId(candidates, seed, `${salt}.${i}`, i));
    }
    return picked;
  }

  function poolsForSegment(pools, segment) {
    const row = pools?.[String(segment)] || pools?.[segment] || {};
    return {
      battle: row.battle || row.common || [],
      elite: row.elite || row.battle || [],
      boss: row.boss || row.elite || row.battle || [],
    };
  }

  function generateGraph({
    seed = 1,
    difficulty = 'normal',
    difficulties = DEFAULT_DIFFICULTIES,
    pools = {},
    enemyById = {},
  } = {}) {
    const difficultyKey = difficulties[difficulty] ? difficulty : 'normal';
    const preset = difficulties[difficultyKey] || DEFAULT_DIFFICULTIES.normal;
    const prepPerSegment = Math.max(1, Number(preset.prepPerSegment || 10));
    const nodes = [];
    const roots = [];

    for (let segment = 1; segment <= 5; segment += 1) {
      const segmentPools = poolsForSegment(pools, segment);
      const rows = [];
      for (let depth = 0; depth < prepPerSegment; depth += 1) {
        const row = [];
        for (let slot = 0; slot < 3; slot += 1) {
          const id = nodeId(segment, depth, slot);
          const elite = (depth + slot) % 4 === 3;
          const type = elite ? 'elite' : 'battle';
          const enemyIds = pickEnemyIds(
            elite ? segmentPools.elite : segmentPools.battle,
            elite ? 2 : 1,
            seed,
            `${id}.enemy`,
          );
          const firstEnemy = enemyById[enemyIds[0]] || {};
          row.push({
            id,
            segment,
            layer: segment,
            depth,
            slot,
            type,
            tier: elite ? 'elite' : 'common',
            enemyIds,
            name: elite
              ? `精英 · ${firstEnemy.name || '未知敌手'}`
              : `遭遇 · ${firstEnemy.name || '未知敌手'}`,
            summary: elite
              ? '可取得更丰厚的战利品，也会面对更完整的敌群。'
              : '沿固定节点图推进，胜利后进入统一整备。',
            nextIds: [],
          });
        }
        rows.push(row);
      }

      for (let depth = 0; depth < rows.length; depth += 1) {
        const nextIds = depth + 1 < rows.length
          ? rows[depth + 1].map((node) => node.id)
          : [bossId(segment)];
        for (const node of rows[depth]) node.nextIds = [...nextIds];
      }

      const bossEnemyId = pickId(segmentPools.boss, seed, `${bossId(segment)}.enemy`, segment);
      const bossEnemy = enemyById[bossEnemyId] || {};
      const boss = {
        id: bossId(segment),
        segment,
        layer: segment,
        depth: prepPerSegment,
        slot: 0,
        type: 'boss',
        tier: 'boss',
        enemyIds: bossEnemyId ? [bossEnemyId] : [],
        name: `层主 · ${bossEnemy.name || '未知层主'}`,
        summary: '层主战后仍会进入统一整备；第五段层主是终局。',
        nextIds: [],
      };
      rows.push([boss]);

      if (segment === 1) roots.push(...rows[0].map((node) => node.id));
      if (segment > 1) {
        const previousBoss = nodes.find((node) => node.id === bossId(segment - 1));
        if (previousBoss) previousBoss.nextIds = rows[0].map((node) => node.id);
      }
      for (const row of rows) nodes.push(...row);
    }

    return {
      seed: Number(seed) || 1,
      difficulty: difficultyKey,
      prepPerSegment,
      segmentCount: 5,
      maxDepth: prepPerSegment,
      roots,
      nodes,
    };
  }

  function nodeById(graph, id) {
    return (graph?.nodes || []).find((node) => node.id === id) || null;
  }

  function nextNodes(graph, id) {
    const node = nodeById(graph, id);
    if (!node) return [];
    return (node.nextIds || []).map((nextId) => nodeById(graph, nextId)).filter(Boolean);
  }

  function visibleRows(graph, segment) {
    return (graph?.nodes || [])
      .filter((node) => node.segment === Number(segment))
      .sort((a, b) => a.depth - b.depth || a.slot - b.slot);
  }

  function nextBreakthrough({
    rank = 1,
    stageIndex = 0,
    stones = 0,
    aptitude = 'bing',
    owned = {},
  } = {}, config = {}) {
    const safeRank = Math.max(1, Math.min(5, Number(rank) || 1));
    const safeStage = Math.max(0, Math.min(3, Number(stageIndex) || 0));
    const aptitudeOrder = config.aptitudeOrder || ['ding', 'bing', 'yi', 'jia'];
    const currentApt = aptitudeOrder.indexOf(String(aptitude));
    const smallCosts = config.smallBreakthroughCosts || {};

    if (safeRank >= 5 && safeStage >= 3) {
      return { ok: false, kind: 'max', reason: 'cultivation_already_max' };
    }

    if (safeStage < 3) {
      const cost = Number(smallCosts[String(safeRank)]?.[safeStage] || 0);
      const sariId = String(config.sariByRank?.[String(safeRank)] || '');
      const hasSari = !!sariId && Number(owned?.[sariId] || 0) > 0;
      return {
        ok: stones >= cost || hasSari,
        kind: 'small',
        targetStageIndex: safeStage + 1,
        targetLabel: stageLabel(safeRank, safeStage + 1),
        stoneCost: cost,
        sariId,
        canStone: stones >= cost,
        canSari: hasSari,
        missing: !hasSari && stones < cost ? 'insufficient_stone' : '',
      };
    }

    const targetRank = safeRank + 1;
    const cost = Number(config.bigStoneCosts?.[String(targetRank)] || 0);
    const requiredApt = String(config.aptitudeGateByTargetRank?.[String(targetRank)] || 'ding');
    const requiredIndex = aptitudeOrder.indexOf(requiredApt);
    const aptitudeOk = requiredIndex >= 0 && currentApt >= requiredIndex;
    const stoneOk = stones >= cost;
    return {
      ok: aptitudeOk && stoneOk,
      kind: 'big',
      targetRank,
      targetLabel: stageLabel(targetRank, 0),
      stoneCost: cost,
      requiredApt,
      aptitudeOk,
      stoneOk,
      missing: !aptitudeOk ? 'insufficient_aptitude' : !stoneOk ? 'insufficient_stone' : '',
    };
  }

  const sellValue = (value) => Math.floor(Math.max(0, Number(value) || 0) * 0.5);

  return Object.freeze({
    STAGE_LABELS,
    DEFAULT_DIFFICULTIES,
    nodeId,
    bossId,
    stageLabel,
    stageIndexFor,
    generateGraph,
    nodeById,
    nextNodes,
    visibleRows,
    nextBreakthrough,
    sellValue,
  });
})();
