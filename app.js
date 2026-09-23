/* 《问真》力量循环审计 · 交互 */
(function () {
  const killMoves = [
    {
      id: "km_light_converge",
      name: "凝光",
      kind: "damage",
      tag: "光 · 伤",
      text: "击伤 5",
      plan: "击伤 4 · 光系支援闩 +2（后续回合）",
      note: "仅增伤/Setup：当次差 1，UI 按 5 误导；支援闩影响后续回合，非当次质变。",
      recipe: "月光 + 小光",
    },
    {
      id: "km_light_bulwark",
      name: "明光壁",
      kind: "solution",
      tag: "光 · 防",
      text: "护体 6",
      plan: "护体 3 · 回复 1",
      note: "改解法：盾减半并添回复——防御与续航的取舍被写进结算，卡片未反映。",
      recipe: "石皮 + 生机草",
    },
    {
      id: "km_blood_ember",
      name: "血昙",
      kind: "solution",
      tag: "血 · 伤",
      text: "回气 2 · 击伤 3",
      plan: "击伤 6 · 无回复",
      note: "改解法：混合回复+伤害 → 纯伤害；组件「气血&lt;50%」条件在合成路径丢失，满血可打。实测满血一击秒 5 血山猪。",
      recipe: "血别离 + 血滴子",
    },
    {
      id: "km_sword_double_edge_1",
      name: "双锋引",
      kind: "damage",
      tag: "剑 · 伤",
      text: "击伤 4",
      plan: "击伤 4 · 剑系支援闩 +1",
      note: "仅增伤：总量与预制一致；支援闩属 setup，不计构筑质变。",
      recipe: "剑伤 R1 ×2（非开局）",
    },
    {
      id: "km_sword_mark_seek_1",
      name: "剑痕索命",
      kind: "solution",
      tag: "剑 · 伤",
      text: "击伤 2",
      plan: "击伤 2 · 剑意 1 · 剑支援闩 +1",
      note: "改解法：隐藏剑意 setup 喂养后续剑打击——动作顺序可变，卡片未显示。",
      recipe: "剑伤 + 剑辅（非开局）",
    },
  ];

  const grid = document.getElementById("km-grid");
  if (grid) {
    grid.innerHTML = killMoves
      .map(
        (k) => `
      <article class="km-card" data-kind="${k.kind}" data-id="${k.id}" tabindex="0" role="button" aria-expanded="false">
        <h3>${k.name}</h3>
        <div class="km-sub">${k.tag} · ${k.recipe}</div>
        <div class="km-face">
          <div class="km-row">
            <div class="lbl">显示</div>
            <div class="val">${k.text}</div>
          </div>
          <div class="km-row settle">
            <div class="lbl">结算</div>
            <div class="val">${k.plan}</div>
          </div>
        </div>
        <div class="km-note">${k.note}</div>
      </article>`
      )
      .join("");

    grid.querySelectorAll(".km-card").forEach((card) => {
      const toggle = () => {
        const open = card.classList.toggle("open");
        card.setAttribute("aria-expanded", open ? "true" : "false");
      };
      card.addEventListener("click", toggle);
      card.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          toggle();
        }
      });
    });
  }

  const nodeMap = {
    "n-combat": "seg-loot",
    "n-loot": "seg-loot",
    "n-stone": "seg-econ",
    "n-mat": "seg-mat",
    "n-forge": "seg-forge",
    "n-km": "seg-km",
    "n-build": "breaks",
    "n-cult": "seg-cult",
    "n-qi": "seg-cult",
    "n-power": "runs",
  };

  Object.entries(nodeMap).forEach(([nodeId, targetId]) => {
    const node = document.getElementById(nodeId);
    if (!node) return;
    node.addEventListener("click", () => {
      const el = document.getElementById(targetId);
      if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  });
})();
