// 描述真实数据表里的 effect 结构，供三个面板共用。普通脚本：全局函数。
function effectText(e) {
  if (!e) return '—';
  const one = (x) => {
    switch (x.kind) {
      case 'strike': {
        const consume = x.consume_status
          ? ` · 消耗${statusLabel(x.consume_status.name)}每层+${x.consume_status.per_stack}`
          : '';
        return `击伤 ${x.amount}${consume}`;
      }
      case 'production': return '整备耗真元催生生机叶 · 每节点一次 · 本体保留 · 试玩时间适配';
      case 'body_training': return '整备时逐步锻体 · 已得力量永久保留 · 同型不能重复叠加';
      case 'maintained': if ((x.modifiers || []).some(m => m.attribute === 'attackDelay')) return `石臂防御 ${x.amount} · 成形后不付维持或承击费 · 拳脚+1，晚1回合结算 · 可主动停止 · 试玩参数`; return `持续防御 ${x.amount ?? (x.modifiers || []).filter(m => m.attribute === 'defense').reduce((n, m) => n + m.amount, 0)} · 每回合真元 ${x.upkeep_qi || 0} · 每次承击真元 ${x.hit_qi || 0} · 跨回合占操控 ${x.focus_cost || 0} · 可主动停止 · 试玩参数`;
      case 'shield': return `护体 ${x.amount}`;
      case 'grant_block': return `格挡 ${x.amount}`;
      case 'heal': return `恢复气血 ${x.amount}${x.consumable ? ' · 用后消失 · 每节点一次有效疗伤 · 试玩时间适配' : ''}`;
      case 'heal_and_strike': return `恢复气血 ${x.heal} · 击伤 ${x.amount}`;
      case 'add_temp_stat': return `${statName(x.stat)} +${x.amount}`;
      case 'support': return x.target_gu_id
        ? `本回合下一次${GU_BY_ID[x.target_gu_id]?.name || x.target_gu_id} ×${x.multiplier}${x.nonStacking ? ' · 同类不叠加' : ''} · 同催准备，不占行动`
        : `助${x.support_school} +${x.support_bonus}`;
      case 'status': return `标记 ${x.amount}`;
      case 'shift': return `位移 ${x.amount}`;
      case 'sword_intent': return `剑意 +${x.amount}`;
      case 'weaken_intent': return `弱化敌方意图 ${x.amount}`;
      case 'aptitude_up': return '使用后资质提升一档';
      case 'breakthrough_material': return '同阶舍利蛊 · 可用于小突破';
      default: return x.kind;
    }
  };
  let text = e.kind === 'composite' ? (e.parts || []).map(one).join(' · ') : one(e);
  if (e.delay) text += ` · 延迟 ${e.delay.turns || 1} 回合`;
  if (e.condition?.type === 'self_hp_below') {
    text += ` · 条件：气血低于 ${Math.round(Number(e.condition.threshold || 0.5) * 100)}%`;
  }
  return text;
}

function statName(s) {
  return { force_power: '力', speed: '速', guard: '御' }[s] || s;
}

function statusLabel(s) {
  return { marked: '刻痕', sealed: '封印' }[s] || s;
}

function guReasonLabel(reason) {
  return {
    production_visit_used: '本次整备已催生',
    not_preparing: '整备时可催生',
    gu_unavailable: '未持有该蛊',
    healing_recovery: '本节点已用生机叶，尚在疗伤间隔',
    health_full: '气血已满，不消耗叶片',
    resource_component_unsupported: '产叶或消耗蛊须单独使用',
    already_active: '正在催动',
    defense_group_active: '已有皮甲形态，请先停止',
    insufficient_essence: '真元不足',
    maintained_component_unsupported: '持续蛊须单独催动',
    unknown_gu: '未找到该蛊',
    gu_consumed: '本场已消耗',
    gu_sealed: '已封印',
    gu_used_this_turn: '本回合已用',
    insufficient_qi_quality: '真元质量不足',
    action_limit_reached: '本回合行动数已尽',
    insufficient_thought: '本回合操控余量不足',
    insufficient_true_qi: '真元不足',
    condition_miss: '条件未满足',
    consume_status_missing: '缺少可消耗的状态层数',
    delay_shape_rejected: '延迟效果结构非法',
    trigger_unsupported: '触发方式未实现',
  }[reason] || reason || '';
}

// 杀招展示必须从组件 battleEffect 合成结果生成（L0 2026-09-25 权威语义）。
// 预制 m.effect 只作兼容元数据，不再直接上屏。
function killMoveEffectText(move, guById = {}) {
  if (typeof GuRules === 'undefined' || !GuRules.killMoveEffectPlan) {
    return effectText(move?.effect);
  }
  const plan = GuRules.killMoveEffectPlan(move, guById, {});
  if (plan.unavailableReason) return guReasonLabel(plan.unavailableReason);
  const parts = [];
  if (plan.heal) parts.push(`恢复气血 ${plan.heal}`);
  if (plan.block) parts.push(`护体 ${plan.block}`);
  if (plan.damage) parts.push(`击伤 ${plan.damage}`);
  if (plan.swordIntent) parts.push(`剑意 +${plan.swordIntent}`);
  if (plan.intentWeaken) parts.push(`弱化敌方意图 ${plan.intentWeaken}`);
  for (const st of plan.statuses || []) parts.push(`标记 ${st.amount || 1}`);
  if (plan.support) parts.push(`助${plan.support.school} +${plan.support.bonus}`);
  if (plan.inspect) parts.push('查验');
  if (plan.suppressCounter) parts.push('压制反制');
  if (plan.armorBreak) parts.push(`破甲 ${plan.armorBreak}`);
  if (plan.ignoreEvasion) parts.push('必中');
  if (plan.delayTurns) parts.push(`延迟 ${plan.delayTurns} 回合`);
  let text = parts.length ? parts.join(' · ') : '—';
  const conditions = [];
  for (const definitionId of move?.recipe || []) {
    const gu = guById[definitionId] || {};
    const effect = gu.v1_effect || gu.battleEffect || null;
    if (effect?.condition?.type === 'self_hp_below') {
      conditions.push(`${gu.name || definitionId}：气血低于 ${Math.round(Number(effect.condition.threshold || 0.5) * 100)}%`);
    }
  }
  if (conditions.length && !move?.componentConditionOverride) {
    text += ` · 继承条件：${conditions.join('；')}`;
  }
  if (move?.componentConditionOverride) {
    text += ' · 已覆盖组件条件';
  }
  return text;
}

const schoolLabel = (s) => ({
  light: '光道', moon: '月道', blood: '血道', force: '力道', earth: '土道',
  water: '水道', qi: '气道', wood: '木道', fire: '火道', wisdom: '智道',
  human: '人道', sword: '剑道', gold: '金道', bone: '骨道', wind: '风道',
}[s] || s || '—');

// 构筑角色有两套键：buildRole/DEFAULT_BUILD_ROLE 的大写键与数据表 role 的小写键，
// 只在上屏时翻译；规则层（GuRules.buildRoleOf）保持原始键，测试按原始键断言。
const buildRoleLabel = (role) => ({
  attack: '攻击', healing: '治疗', defense: '防御', recon: '侦查',
  movement: '机动', support: '辅助', logistics: '后勤',
  Core: '核心', Information: '情报', Support: '辅助', Transform: '蜕变',
  Finisher: '终结', Resource: '资源',
}[role] || role || '—');
