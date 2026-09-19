// 描述真实数据表里的 effect 结构，供三个面板共用。普通脚本：全局函数。
function effectText(e) {
  if (!e) return '—';
  const one = (x) => {
    switch (x.kind) {
      case 'strike': return `击伤 ${x.amount}`;
      case 'shield': return `护体 ${x.amount}`;
      case 'grant_block': return `格挡 ${x.amount}`;
      case 'heal': return `回气 ${x.amount}`;
      case 'heal_and_strike': return `回气 ${x.heal} · 击伤 ${x.amount}`;
      case 'add_temp_stat': return `${statName(x.stat)} +${x.amount}`;
      case 'support': return `助${x.support_school} +${x.support_bonus}`;
      case 'status': return `标记 ${x.amount}`;
      case 'shift': return `位移 ${x.amount}`;
      default: return x.kind;
    }
  };
  if (e.kind === 'composite') return (e.parts || []).map(one).join(' · ');
  return one(e);
}

function statName(s) {
  return { force_power: '力', speed: '速', guard: '御' }[s] || s;
}

const schoolLabel = (s) => ({ light: '光道', moon: '月道', blood: '血道', force: '力道', earth: '土道', water: '水道', qi: '气道' }[s] || s || '—');
