# 《蛊真人》视觉知识库 V1 — Consolidated

# 《蛊真人》可追溯视觉知识库 V1

这是给 Codex / AI 生图 / 游戏美术资产使用的结构化知识库。它不是“总结文档”，而是**保留细节的可追溯知识树**。

## 核心 Doctrine

**大道具象，人行其间。**

《蛊真人》的艺术不是让图像象征一个道理，而是让道理成为现实：抽象规则可以被炼成蛊、身体、建筑、地貌和运行机制；人的选择在真实限制与代价中获得重量。

## 使用顺序

1. 先读 `doctrine.md`：了解跨对象原则。
2. 通过 `INDEX.md` 找对象 dossier。
3. 生成图片时读取该 dossier 的 `Visual Thesis`、`Canon Appearance`、`Asset Roles`、`Must Keep`、`Avoid`。
4. `Evidence` 决定某条信息是否能当硬约束。
5. 批量任务直接读取 `machine/dossiers.json` 与 `machine/tokens.json`。

## 不允许的压缩

- 不得只保留一句“东方暗黑仙侠”。
- 不得只保留颜色/材质/光效。
- 不得删除对象级反差、状态、尺度、资产角色、网络漂移和证据状态。
- 不得把社区高频形象自动升级为原著 Canon。
- 不得为了补齐 schema 而捏造原著未明确的形态。

## 文件结构

```text
reverend_insanity_visual_kb_v1/
├─ README.md
├─ doctrine.md
├─ INDEX.md
├─ STATUS.md
├─ schema.yaml
├─ sources.json
├─ dossiers/
│  ├─ gu/
│  ├─ characters/
│  ├─ houses/
│  └─ scenes/
└─ machine/
   ├─ dossiers.json
   ├─ tokens.json
   ├─ doctrine.json
   └─ rejected_conventions.json
```

## 当前规模

- 44 个对象级 dossier
- 42 条来源记录
- 10 个跨对象视觉 Token

## 数据哲学

**总结只做索引，不删除细节。**

如果一个条目只有前序调查结论、尚未在本轮补到来源，它会被保留，但明确标记 `prior_research_needs_source_refresh` / `pending_primary_source`。这比删除有价值的研究、或把未核信息冒充 Canon 都更安全。


---

# 《蛊真人》视觉 Doctrine V1

## 一句话

**大道具象，人行其间。**

《蛊真人》的艺术不是用图像象征道理，而是让道理成为现实：抽象规则被炼成蛊、身体、建筑、地貌和可运行的机制；人在这些真实限制中选择、付出代价、留下痕迹。

## 三条不可压缩的真理

- 让不可见的“道”成为可触摸、可炼化、可使用、可损坏、可付出代价的现实。
- 世界的规则必须足够真实，人的意志才有意义。
- 总结只负责建立索引，不负责删除细节。

## 原则

### P01 规则具象
先问“这个不可见的道理如何成为物质或运行规则”，再问颜色和特效。

### P02 反差成义
对象常以身体悖论承载内核：寿命像枯根、坚持前进炼成不动巨碑、宿命极小却无处不在。

### P03 代价与痕迹
力量必须留下磨损、枯荣、伤痕、残渣、资源消耗或不可逆后果。

### P04 大道可极简
越根本、越压缩的规则不必越华丽；慧剑只是气泡，规矩只是圆方，希望只是微光。

### P05 尺度即叙事
尺度不是展示强弱的装饰，而是表达关系：宿命小而支配世界、幽魂大到成为地貌、坚持蛊需人体作尺度。

### P06 人是选择主体
蛊、杀招、蛊屋是规则与工具；画面最终要让人的选择在真实限制中获得重量。

### P07 资产角色优先
同一对象的 Object Art、Icon、Activation、Lore、Narrative 可以承担不同信息，不强迫单张图讲完整世界观。

### P08 颜色不裁决善恶
白可代表压迫秩序，血红可代表活着的意志；不让固定调色盘替文本做道德判断。


---

# 态度蛊

- ID: `attitude_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

态度是心呈现给外界的面具；面具本身不应替佩戴者固定一种态度。

## Canon Appearance / 硬锚点

- 面具形

## Asset Roles

### object_art
中性面具特写；可通过角度/光线让表情似乎变化，但不锁死邪笑。

### character_use
佩戴者的“心”与外界认知变化才是重点。

## Must Keep

- 面具
- 中性/可投射性

## Avoid

- 固定鬼脸
- 妖邪笑面作为唯一Canon
- 把它画成昆虫+面具纹

## Community Drift / 网络漂移

- 社区喜欢白色邪笑面，辨识高但过度规定了“态度”内容

## Evidence

- `S008` [Attitude Gu | Fandom](https://reverend-insanity.fandom.com/wiki/Attitude_Gu) — chapter-referenced secondary
- `S009` [Reverend Insanity ch.948 - Attitude Gu](https://jordan11.org/novel11/reverend-insanity-2/chapter-948) — novel mirror

## Generation Prompt Skeleton

- 核心命题：态度是心呈现给外界的面具；面具本身不应替佩戴者固定一种态度。
- 必保留：面具；中性/可投射性
- 禁止：固定鬼脸；妖邪笑面作为唯一Canon；把它画成昆虫+面具纹


---

# 血颅蛊

- ID: `blood_skull_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

血脉力量被灌入一个干净、透明、幼小而残酷的容器。

## Canon Appearance / 硬锚点

- 掌心大小儿童水晶头骨
- 半透明
- 内部淡红血丝
- 血从空眼眶进入
- 充满后血丝/整体更鲜红

## Asset Roles

### object_art
微距材质型；做 Empty/Feeding/Full 状态。

### state_art
让本体自身显示储存状态，而非依赖UI血条。

## Must Keep

- 透明水晶
- 儿童头骨
- 内部血丝
- 状态变化

## Avoid

- 骷髅冒火
- 魔王头骨
- 红黑烟雾盖住透明材质

## Community Drift / 网络漂移

- 血道二创易堆血浆；原著更像精致工艺品被血侵染

## Evidence

- `S015` [Blood Skull Gu | Saga of Gu](https://sagaofgu.com/gu/demonic-blood-skull-gu/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：血脉力量被灌入一个干净、透明、幼小而残酷的容器。
- 必保留：透明水晶；儿童头骨；内部血丝；状态变化
- 禁止：骷髅冒火；魔王头骨；红黑烟雾盖住透明材质


---

# 宿命蛊

- ID: `fate_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

极致的小，与无处不在的支配形成反差；世界秩序甚至会在这只小蜘蛛身上留下伤口。

## Canon Appearance / 硬锚点

- 黑白蜘蛛
- 受损时期有几乎将身体切成两半的猩红伤口
- 本体尺度小

## Asset Roles

### object_art
不要传统放大英雄化；允许90%留白/苍白空间，蜘蛛仅占5–15%，蛛丝延伸出画框。

### narrative
宿命大战强调“连接→切断”，不是巨型蜘蛛Boss。

### lore
塔顶小蜘蛛与巨大的监天塔形成尺度反差。

## Must Keep

- 小
- 黑白
- 蛛丝关系
- 伤口在受损时期
- 影响尺度远大于实体尺度

## Avoid

- 巨型恐怖Boss蜘蛛
- 把蜘蛛画成装甲神器
- 只画白光而丢掉关系网络

## Community Drift / 网络漂移

- 网络常把宿命概念拟人化或放大神器化；应回到极小本体+无尽关系

## Evidence

- `S006` [Fate Gu | Fandom](https://reverend-insanity.fandom.com/wiki/Fate_Gu) — chapter-referenced secondary
- `S007` [Reverend Insanity ch.780 - Fate Immortal Gu](https://www.pyg-kit.com/en/books/reverend-insanity/chapters/78734) — novel mirror

## Generation Prompt Skeleton

- 核心命题：极致的小，与无处不在的支配形成反差；世界秩序甚至会在这只小蜘蛛身上留下伤口。
- 必保留：小；黑白；蛛丝关系；伤口在受损时期；影响尺度远大于实体尺度
- 禁止：巨型恐怖Boss蜘蛛；把蜘蛛画成装甲神器；只画白光而丢掉关系网络


---

# 定仙游

- ID: `fixed_immortal_travel`
- 类别: 蛊虫
- 成熟度: `stable`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

极小、极轻的生命，无视极大的空间距离。

## Canon Appearance / 硬锚点

- 翠玉蝴蝶
- 绿色光点/如花粉般微光
- 轻盈

## Asset Roles

### object_art
完美翠玉蝶，清爽、轻盈；空间感只用轻微折射/错位暗示。

### narrative
三王山炼成时作为毁灭环境中的一个极小绿色焦点。

## Must Keep

- 翠玉蝴蝶
- 轻盈
- 绿光微粒

## Avoid

- 大型传送门
- 蓝紫科幻空间裂缝
- 过度复杂机械结构

## Community Drift / 网络漂移

- 社区视觉共识较成熟，可利用但不必加重空间UI

## Evidence

- `S005` [Fixed Immortal Travel | Saga of Gu](https://sagaofgu.com/gu/fixed-immortal-travel/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：极小、极轻的生命，无视极大的空间距离。
- 必保留：翠玉蝴蝶；轻盈；绿光微粒
- 禁止：大型传送门；蓝紫科幻空间裂缝；过度复杂机械结构


---

# 自由蛊

- ID: `freedom_gu`
- 类别: 蛊虫
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `prior_research_needs_source_refresh`

## Visual Thesis

真正的自由不仅轻盈，而且不能被稳定占有。

## Canon Appearance / 硬锚点

- 小型五彩光萤/光虫；野生个体难以抓住；可聚合成更大形态

## Asset Roles

### object_art
逃逸型构图：不必居中，像正要飞出卡框。

## Must Keep

- 五彩
- 小
- 运动/逃逸

## Avoid

- 羽毛/翅膀作为本体
- 断锁链图标化

## Community Drift / 网络漂移

- 社区易把“自由”直接画成翅膀符号

## Evidence

- **待补原文/章节来源。** 当前条目保留自前序调查，不升级为 locked canon。

## Generation Prompt Skeleton

- 核心命题：真正的自由不仅轻盈，而且不能被稳定占有。
- 必保留：五彩；小；运动/逃逸
- 禁止：羽毛/翅膀作为本体；断锁链图标化


---

# 天元宝皇莲

- ID: `heavenly_essence_treasure_imperial_lotus`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

资源生产过程本身就是美术：天地元气经过完整循环被炼成仙元。

## Canon Appearance / 硬锚点

- 九转：碧绿釉质荷叶
- 中央白玉花苞
- 透明露珠沿叶流入花苞
- 白→粉→鲜红开花
- 翡翠莲蓬
- 八十一颗黄杏仙元莲子

## Asset Roles

### object_art
可做静态花苞形态。

### cycle_art
强烈建议动画/状态序列，完整展示白→粉→红→莲蓬→回白循环。

## Must Keep

- 循环
- 釉绿荷叶
- 白玉花苞
- 81莲子

## Avoid

- 仅“发光仙莲”
- 把生产机制藏掉

## Community Drift / 网络漂移

- 网络常只画漂亮莲花，损失其“自动炼元”机制

## Evidence

- `S018` [Heavenly Essence Treasure Lotus | Saga of Gu](https://sagaofgu.com/gu/heavenly-essence-treasure-lotus/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：资源生产过程本身就是美术：天地元气经过完整循环被炼成仙元。
- 必保留：循环；釉绿荷叶；白玉花苞；81莲子
- 禁止：仅“发光仙莲”；把生产机制藏掉


---

# 希望蛊

- ID: `hope_gu`
- 类别: 蛊虫
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `prior_research_needs_source_refresh`

## Visual Thesis

希望最初不因强大而成立；它可以弱到只剩一点光，却让人继续走。

## Canon Appearance / 硬锚点

- 极小微白光点；激活/承载希望后可扩张成强光

## Asset Roles

### object_art
80%低信息/黑暗背景，小白点核心10–15%；不要靠大光晕假装强。

### activation
由微弱到吞没画面的白光。

## Must Keep

- 微弱
- 白点
- 状态反差

## Avoid

- 金色天使
- 圣洁大光球
- 神圣翅膀

## Community Drift / 网络漂移

- 网络方向大体正确但容易过度神圣化

## Evidence

- **待补原文/章节来源。** 当前条目保留自前序调查，不升级为 locked canon。

## Generation Prompt Skeleton

- 核心命题：希望最初不因强大而成立；它可以弱到只剩一点光，却让人继续走。
- 必保留：微弱；白点；状态反差
- 禁止：金色天使；圣洁大光球；神圣翅膀


---

# 江山如故

- ID: `landscape_as_before`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

山河本身以生物天然纹理长进甲壳，而非作为贴花装饰。

## Canon Appearance / 硬锚点

- 拳头大小瓢虫
- 玉质身体
- 圆背
- 背甲一半江河湖海、一半山丘峰峦

## Asset Roles

### object_art
近距离看甲壳天然山水纹，不做“贴在背上的地图”。

## Must Keep

- 玉质瓢虫
- 天然山河纹

## Avoid

- 普通瓢虫+地图贴纸
- 过度山水卷轴特效

## Community Drift / 网络漂移

- 网络独立形象较少，文本锚点强

## Evidence

- `S016` [Landscape As Before ch.611](https://jordan11.org/novel11/reverend-insanity-2/chapter-611) — novel mirror

## Generation Prompt Skeleton

- 核心命题：山河本身以生物天然纹理长进甲壳，而非作为贴花装饰。
- 必保留：玉质瓢虫；天然山河纹
- 禁止：普通瓢虫+地图贴纸；过度山水卷轴特效


---

# 寿蛊

- ID: `lifespan_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

所有人争夺的更多生命，偏偏长得最像衰老与枯死。

## Canon Appearance / 硬锚点

- 人参/老树根状
- 粗糙
- 沧桑
- 可盘曲如蛇

## Asset Roles

### object_art
材质型微距；真的像没人会捡的枯根，珍贵不靠金绿神光。

## Must Keep

- 枯根
- 粗糙
- 老化质感

## Avoid

- 仙桃
- 翡翠灵根
- 金绿生命圣光

## Community Drift / 网络漂移

- 网络常“美化”为生命系神器，违背反差

## Evidence

- `S017` [Three-hundred-year Lifespan Gu | Saga of Gu](https://sagaofgu.com/gu/three-hundred-year-lifespan-gu/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：所有人争夺的更多生命，偏偏长得最像衰老与枯死。
- 必保留：枯根；粗糙；老化质感
- 禁止：仙桃；翡翠灵根；金绿生命圣光


---

# 酒虫

- ID: `liquor_worm`
- 类别: 蛊虫
- 成熟度: `stable`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

关键资源型蛊可以可爱、柔软、日常，不需要用威严证明价值。

## Canon Appearance / 硬锚点

- 白色/珍珠白蚕宝宝
- 略胖
- 可爱
- 飞行时可团成球
- 带酒香

## Asset Roles

### object_art
干净软体特写，保留珍珠光与胖蚕体型。

## Must Keep

- 珍珠白
- 蚕宝宝
- 胖
- 酒香

## Avoid

- 硬甲虫
- 酒壶造型
- 把可爱感去掉

## Community Drift / 网络漂移

- 社区共识与文本较一致

## Evidence

- `S019` [Liquor Worm ch.14](https://novelmulti.com/novel/reverend-insanity/chapter/14) — novel mirror

## Generation Prompt Skeleton

- 核心命题：关键资源型蛊可以可爱、柔软、日常，不需要用威严证明价值。
- 必保留：珍珠白；蚕宝宝；胖；酒香
- 禁止：硬甲虫；酒壶造型；把可爱感去掉


---

# 爱情蛊

- ID: `love_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

爱情没有客观稳定的统一外形；观察者如何理解爱情，会改变他所看见的爱情蛊。

## Canon Appearance / 硬锚点

- 外观依观察者而变化：彩霞/灰石/清水/桃花等均有文本实例

## Asset Roles

### object_art
不设唯一标准皮肤；数据库层应支持 observer_dependent skins。

### game_system
同一对象可因角色/存档/观察者显示不同形态。

## Must Keep

- 观察者依赖
- 多合法外形
- 不可控性

## Avoid

- 粉红爱心作为唯一Canon
- 单一标准模型

## Community Drift / 网络漂移

- 网络大量爱心、红线、拟人女性；只能算某一视角二创

## Evidence

- `S010` [Reverend Insanity ch.1230 - Love Gu](https://good88888.org/goodnovel/reverend-insanity-2/chapter-1230) — novel mirror

## Generation Prompt Skeleton

- 核心命题：爱情没有客观稳定的统一外形；观察者如何理解爱情，会改变他所看见的爱情蛊。
- 必保留：观察者依赖；多合法外形；不可控性
- 禁止：粉红爱心作为唯一Canon；单一标准模型


---

# 人如故

- ID: `man_as_before`
- 类别: 蛊虫
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

人的复原被具身为蝴蝶与“人身从蝶中生长”的生命形态。

## Canon Appearance / 硬锚点

- 仙蛊炼成时破茧成彩蝶
- 高阶描述中身体中央可呈现白嫩人身元素

## Asset Roles

### object_art
以蝴蝶为主体，避免钟表/沙漏。

### activation
身体损伤倒流复原，突出“回到过去的肉身”而非绿色治疗。

## Must Keep

- 蝴蝶
- 复原/肉身回归

## Avoid

- 钟表
- 沙漏
- 普通治疗光

## Community Drift / 网络漂移

- 社区图少，需后续继续核高阶具体外观

## Evidence

- `S016` [Landscape As Before ch.611](https://jordan11.org/novel11/reverend-insanity-2/chapter-611) — novel mirror

## Generation Prompt Skeleton

- 核心命题：人的复原被具身为蝴蝶与“人身从蝶中生长”的生命形态。
- 必保留：蝴蝶；复原/肉身回归
- 禁止：钟表；沙漏；普通治疗光


---

# 月光蛊

- ID: `moonlight_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

月光第一次获得可握住的实体。

## Canon Appearance / 硬锚点

- 掌心尺度
- 弯月形
- 淡蓝/蓝水晶般半透明
- 极轻，近似纸片重量
- 炼化后可形成淡蓝弯月印记

## Asset Roles

### object_art
主体60–75%，微距特写；让实体中心有晶体感、边缘趋向月晕，强调“凝固的光”而非首饰。

### icon
极简淡蓝新月。

### activation
掌心月华凝聚并形成月刃。

### lore
古月山寨蛊室：银盘中成排近乎相同的月光蛊，展示规则被家族制度化培育。

## Must Keep

- 必须看成“凝固月光”而非普通宝石
- 单体图优先辨识度
- 群体培育是 Lore Art 而非主 Object Art

## Avoid

- 飞蛾/蝴蝶化
- 金纹珠宝化
- 复杂法阵喧宾夺主
- 把家族文明强塞进单体卡图

## Community Drift / 网络漂移

- 网络/AI易把它画成蓝色飞蛾或月亮饰品

## Evidence

- `S001` [Moonlight Gu | Saga of Gu](https://sagaofgu.com/gu/moonlight-gu/) — chapter-indexed secondary
- `S002` [Reverend Insanity ch.10 - refining Moonlight Gu](https://www.webnovel.com/book/reverend-insanity_7996858406002505/a-storm-may-arise-from-a-clear-sky-refining-gu-is-full-of-hardships_21545169354548857) — novel mirror

## Generation Prompt Skeleton

- 核心命题：月光第一次获得可握住的实体。
- 必保留：必须看成“凝固月光”而非普通宝石；单体图优先辨识度；群体培育是 Lore Art 而非主 Object Art
- 禁止：飞蛾/蝴蝶化；金纹珠宝化；复杂法阵喧宾夺主；把家族文明强塞进单体卡图


---

# 坚持蛊

- ID: `perseverance_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

不断前进最终凝结成不可推动的重量；过程是前进，结果是绝对不动。

## Canon Appearance / 硬锚点

- 巨鲸大小
- 碑/巨型石碑形
- 底宽上窄
- 方正
- 金属黑/黑铁色
- 边线笔直

## Asset Roles

### object_art
必须加人体/地貌尺度尺；本体不写“坚持”大字。

### narrative
逆流河一步一步前进，脚印/历程逐渐炼成巨碑。

## Must Keep

- 尺度巨大
- 黑铁碑
- 直
- 无文字也能表达“不倒”

## Avoid

- 发光小甲虫
- 普通黑色石头无尺度参照
- 碑面写“坚持”

## Community Drift / 网络漂移

- 网络常误画成小虫或光团，是严重偏离

## Evidence

- `S011` [Perseverance Gu | Fandom](https://reverend-insanity.fandom.com/wiki/Perseverance_Gu) — chapter-referenced secondary

## Generation Prompt Skeleton

- 核心命题：不断前进最终凝结成不可推动的重量；过程是前进，结果是绝对不动。
- 必保留：尺度巨大；黑铁碑；直；无文字也能表达“不倒”
- 禁止：发光小甲虫；普通黑色石头无尺度参照；碑面写“坚持”


---

# 悔蛊

- ID: `regret_gu`
- 类别: 蛊虫
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `prior_research_needs_source_refresh`

## Visual Thesis

后悔让行动器官退化成只能触碰过去的感受器官。

## Canon Appearance / 硬锚点

- 苍白如纸的蜈蚣体
- 正常足位被半透明飘荡须毛取代

## Asset Roles

### object_art
65%主体，纸白节肢+半透明百须；背景低饱和。

## Must Keep

- 苍白
- 蜈蚣节肢
- 须替代足

## Avoid

- 拟人少女作为本体
- 补回正常蜈蚣足
- 红莲红色污染本体配色

## Community Drift / 网络漂移

- 网络拟人化明显增加，需避免混淆实体

## Evidence

- **待补原文/章节来源。** 当前条目保留自前序调查，不升级为 locked canon。

## Generation Prompt Skeleton

- 核心命题：后悔让行动器官退化成只能触碰过去的感受器官。
- 必保留：苍白；蜈蚣节肢；须替代足
- 禁止：拟人少女作为本体；补回正常蜈蚣足；红莲红色污染本体配色


---

# 矩蛊

- ID: `regulation_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

规制不是装饰，而是给世界划定可执行边界的方。

## Canon Appearance / 硬锚点

- 方

## Asset Roles

### object_art
方就是方，极简。

### activation
方扩大覆盖大世界，与规蛊组成巨网。

## Must Keep

- 纯方
- 极简

## Avoid

- 机械方块
- 金色符文立方体

## Community Drift / 网络漂移

- AI易把“方”做成高科技几何神器

## Evidence

- `S020` [Rules & Regulations | Saga of Gu](https://sagaofgu.com/legends/rules-and-regulations/) — chapter-indexed secondary
- `S021` [Rules and Regulations ch.58](https://good88888.org/goodnovel/reverend-insanity-2/chapter-58) — novel mirror

## Generation Prompt Skeleton

- 核心命题：规制不是装饰，而是给世界划定可执行边界的方。
- 必保留：纯方；极简
- 禁止：机械方块；金色符文立方体


---

# 规蛊

- ID: `rules_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

规则不是世界表面的符文，而是决定边界关系的几何本身。

## Canon Appearance / 硬锚点

- 圆

## Asset Roles

### object_art
圆就是圆，极简。

### activation
圆扩大到囊括宇宙，并与矩蛊方形共同成网。

## Must Keep

- 纯圆
- 极简

## Avoid

- 机械圆环
- 太极盘
- 符文星盘

## Community Drift / 网络漂移

- AI易装饰过度

## Evidence

- `S020` [Rules & Regulations | Saga of Gu](https://sagaofgu.com/legends/rules-and-regulations/) — chapter-indexed secondary
- `S021` [Rules and Regulations ch.58](https://good88888.org/goodnovel/reverend-insanity-2/chapter-58) — novel mirror

## Generation Prompt Skeleton

- 核心命题：规则不是世界表面的符文，而是决定边界关系的几何本身。
- 必保留：纯圆；极简
- 禁止：机械圆环；太极盘；符文星盘


---

# 第二空窍蛊

- ID: `second_aperture_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

第二个修行中心被直接做成一只“背上长眼”的超现实器官生物。

## Canon Appearance / 硬锚点

- 甲虫形
- 两头尖、中段肥
- 青玉材质
- 拳头大小
- 背部一颗金色眼珠
- 金瞳如闪电游动

## Asset Roles

### object_art
青玉甲虫与背部金眼为唯一主视觉；材质温润清凉。

### evolution
可另存炼制前胎/壳阶段，不与完成体混淆。

## Must Keep

- 青玉甲虫
- 背上金眼

## Avoid

- 普通双头虫
- 把眼睛改成纹章
- 机械义眼

## Community Drift / 网络漂移

- 网络缺稳定共识，原著反而非常明确

## Evidence

- `S013` [Second Aperture Gu | Fandom](https://reverend-insanity.fandom.com/wiki/Second_Aperture_Gu) — chapter-referenced secondary
- `S014` [Reverend Insanity ch.487 - Second Aperture Gu](https://www.pyg-kit.com/en/books/reverend-insanity/chapters/78441) — novel mirror

## Generation Prompt Skeleton

- 核心命题：第二个修行中心被直接做成一只“背上长眼”的超现实器官生物。
- 必保留：青玉甲虫；背上金眼
- 禁止：普通双头虫；把眼睛改成纹章；机械义眼


---

# 自己蛊

- ID: `self_gu`
- 类别: 蛊虫
- 成熟度: `seed`
- 置信度: `low`
- 核验状态: `pending_primary_source`

## Visual Thesis

对整个天地而言，“自己”极小；认识世界的尺度越大，越发现自身渺小。

## Canon Appearance / 硬锚点

- 当前研究仅能可靠保留“极小”；具体种属/材质不锁死

## Asset Roles

### object_art
Shape: OPEN。可临时用不可判定的小生命剪影，但不得升级为原著Canon。

## Must Keep

- 极小
- 形态开放

## Avoid

- 擅自固定黑甲虫/小人/水晶球

## Community Drift / 网络漂移

- 最重要的知识是“这里没有足够证据，不能装成有答案”

## Evidence

- **待补原文/章节来源。** 当前条目保留自前序调查，不升级为 locked canon。

## Generation Prompt Skeleton

- 核心命题：对整个天地而言，“自己”极小；认识世界的尺度越大，越发现自身渺小。
- 必保留：极小；形态开放
- 禁止：擅自固定黑甲虫/小人/水晶球


---

# 春秋蝉

- ID: `spring_autumn_cicada`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

时间直接写进同一生命的枯荣状态。

## Canon Appearance / 硬锚点

- 棕黄色头腹
- 木质/掌木般躯体
- 表面年轮纹
- 两片宽大半透明叶翼
- 健康时嫩绿叶翼
- 虚弱/重生后枯黄卷损

## Asset Roles

### object_art
标本式清晰特写，突出木纹与叶脉。

### state_art
至少健康/枯萎两套，不以额外时钟符号表现时间。

### activation
与光阴长河/逆流时间相关，允许时空环境但不遮本体。

## Must Keep

- 年轮
- 叶脉
- 枯荣状态变化
- 棕木本体而非翡翠虫

## Avoid

- 整只做成翡翠绿水晶蝉
- 加钟表/齿轮代替本体设计

## Community Drift / 网络漂移

- 网络常用强荧光绿，容易把棕木与年轮信息丢掉

## Evidence

- `S003` [Spring Autumn Cicada | Fandom](https://reverend-insanity.fandom.com/wiki/Spring_Autumn_Cicada) — chapter-referenced secondary
- `S004` [Reverend Insanity ch.19 - Spring Autumn Cicada](https://www.webnovel.com/book/reverend-insanity_7996858406002505/rank-six-vital-gu-the-spring-autumn-cicada%21_21567889714767824) — novel mirror

## Generation Prompt Skeleton

- 核心命题：时间直接写进同一生命的枯荣状态。
- 必保留：年轮；叶脉；枯荣状态变化；棕木本体而非翡翠虫
- 禁止：整只做成翡翠绿水晶蝉；加钟表/齿轮代替本体设计


---

# 智慧蛊

- ID: `wisdom_gu`
- 类别: 蛊虫
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `prior_research_needs_source_refresh`

## Visual Thesis

智慧最强的视觉不一定在本体，而在它改变周围思考环境的“场”。

## Canon Appearance / 硬锚点

- 本体可飞行，有翼；五彩华光；形成球形五彩智慧光晕

## Asset Roles

### object_art
本体清楚但不擅自锁昆虫种类。

### field_art
球形五彩智慧光晕是关键能力视觉。

## Must Keep

- 五彩场域
- 小型活物
- 场比形更重要

## Avoid

- 巨大脑
- 金眼神虫
- 皇冠式“聪明”图标

## Community Drift / 网络漂移

- 网络常人形化/圣化，本体未形成稳定共识

## Evidence

- **待补原文/章节来源。** 当前条目保留自前序调查，不升级为 locked canon。

## Generation Prompt Skeleton

- 核心命题：智慧最强的视觉不一定在本体，而在它改变周围思考环境的“场”。
- 必保留：五彩场域；小型活物；场比形更重要
- 禁止：巨大脑；金眼神虫；皇冠式“聪明”图标


---

# 慧剑蛊

- ID: `wisdom_sword_gu`
- 类别: 蛊虫
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

真正被压缩到极致的锋利，不必再长得像剑。

## Canon Appearance / 硬锚点

- 其貌不扬的普通漂浮气泡

## Asset Roles

### object_art
就画气泡；精细材质，几乎脆弱。异常可藏在“经过它的背景被无声切断”。

## Must Keep

- 气泡
- 极简
- 看似脆弱

## Avoid

- 剑形神器
- 金色剑纹
- 符箓光轮
- 为了八转而堆装饰

## Community Drift / 网络漂移

- AI/同人易本能“升级视觉复杂度”，应明确禁止

## Evidence

- `S012` [Wisdom Sword Gu | Fandom](https://reverend-insanity.fandom.com/wiki/Wisdom_Sword_Gu) — chapter-referenced secondary

## Generation Prompt Skeleton

- 核心命题：真正被压缩到极致的锋利，不必再长得像剑。
- 必保留：气泡；极简；看似脆弱
- 禁止：剑形神器；金色剑纹；符箓光轮；为了八转而堆装饰


---

# 白凝冰

- ID: `bai_ning_bing`
- 类别: 人物
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

最冷的身体里有最强烈的生命欲；死亡逼近使“活着”本身变得浓烈。

## Canon Appearance / 硬锚点

- 白衣
- 银白长发
- 深/淡蓝眼
- 雪白皮肤
- 龙人阶段小型红色龙角与淡蓝龙瞳

## Asset Roles

### portrait
冷色肉身+极有生命感/兴味的眼睛；不必靠冰裂纹。

### dragon_form
龙人阶段再加入红角。

## Must Keep

- 白+冰蓝
- 眼神要活
- 龙角只在对应阶段

## Avoid

- 甜美冰雪仙女
- 常态暖色
- 所有阶段都带龙角

## Community Drift / 网络漂移

- 社区共识稳定，但容易只剩“冰美人”

## Evidence

- `S028` [Bai Ning Bing | Fandom](https://reverend-insanity.fandom.com/wiki/Bai_Ning_Bing) — chapter-referenced secondary

## Generation Prompt Skeleton

- 核心命题：最冷的身体里有最强烈的生命欲；死亡逼近使“活着”本身变得浓烈。
- 必保留：白+冰蓝；眼神要活；龙角只在对应阶段
- 禁止：甜美冰雪仙女；常态暖色；所有阶段都带龙角


---

# 龙公

- ID: `duke_long`
- 类别: 人物
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

漫长历史中的老朽之物重新启动后仍可拥有恐怖力量；恢复力量不等于恢复青春。

## Canon Appearance / 硬锚点

- 极高大
- 恢复形态有龙角、龙瞳/龙类特征、强健躯体；早期/沉睡形态极衰弱老朽

## Asset Roles

### portrait
至少双状态：Dormant/Restored。Restored保留老者脸+极强龙躯。

## Must Keep

- 老
- 龙角
- 恢复后强壮但不年轻化

## Avoid

- 紫发年轻帅哥
- 把恢复理解为返老还童

## Community Drift / 网络漂移

- 网络年轻化偏差很大

## Evidence

- `S041` [Duke Long | Fandom](https://reverend-insanity.fandom.com/wiki/Duke_Long) — chapter-referenced secondary

## Generation Prompt Skeleton

- 核心命题：漫长历史中的老朽之物重新启动后仍可拥有恐怖力量；恢复力量不等于恢复青春。
- 必保留：老；龙角；恢复后强壮但不年轻化
- 禁止：紫发年轻帅哥；把恢复理解为返老还童


---

# 方源

- ID: `fang_yuan`
- 类别: 人物
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `prior_research_needs_source_refresh`

## Visual Thesis

世界在动，他的方向不动；角色辨识的根不是“魔气”，而是极少表情与稳定选择。

## Canon Appearance / 硬锚点

- 早期与方正高度相似
- 黑/深色视觉是社区稳定二创语言而非所有阶段硬设定
- 深黑/稳定眼神是高频文本与社区锚点

## Asset Roles

### portrait
Minimal Portrait：极少表情、稳定眼神、简洁轮廓。

### narrative
环境越乱、越巨大，他越克制；逆流/崩坏世界中继续行动。

## Must Keep

- 克制
- 稳定目光
- 不依赖魔纹/邪笑

## Avoid

- 血眼魔纹
- 满身邪气
- 把“魔尊”画成表面邪恶符号

## Community Drift / 网络漂移

- 社区黑发黑衣共识强，但不能把其当唯一硬Canon

## Evidence

- **待补原文/章节来源。** 当前条目保留自前序调查，不升级为 locked canon。

## Generation Prompt Skeleton

- 核心命题：世界在动，他的方向不动；角色辨识的根不是“魔气”，而是极少表情与稳定选择。
- 必保留：克制；稳定目光；不依赖魔纹/邪笑
- 禁止：血眼魔纹；满身邪气；把“魔尊”画成表面邪恶符号


---

# 凤九歌

- ID: `feng_jiu_ge`
- 类别: 人物
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

力量不依赖乐器道具；人本身像枪剑一样挺拔，音乐存在于环境与关系中。

## Canon Appearance / 硬锚点

- 红白长袍
- 身姿笔直如枪/剑
- 剑眉
- 眼有神光
- 温和笑意与支配感并存

## Asset Roles

### portrait
不拿乐器也成立；突出挺拔与红白。

### skill_art
音律让环境自身成为乐器。

## Must Keep

- 红白
- 挺拔
- 剑眉
- 温和+压迫

## Avoid

- 固定“白衣笛仙”
- 乐器喧宾夺主

## Community Drift / 网络漂移

- 横笛是强社区惯例，但不是必须Canon

## Evidence

- `S022` [Feng Jiu Ge | Fandom](https://reverend-insanity.fandom.com/wiki/Feng_Jiu_Ge) — chapter-referenced secondary
- `S023` [Reverend Insanity ch.1388 - This is Feng Jiu Ge](https://jordan11.org/novel11/reverend-insanity-2/chapter-1388) — novel mirror

## Generation Prompt Skeleton

- 核心命题：力量不依赖乐器道具；人本身像枪剑一样挺拔，音乐存在于环境与关系中。
- 必保留：红白；挺拔；剑眉；温和+压迫
- 禁止：固定“白衣笛仙”；乐器喧宾夺主


---

# 巨阳仙尊

- ID: `giant_sun`
- 类别: 人物
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

运不是金色幸运光，而是资源与可能性的重新分配。

## Canon Appearance / 硬锚点

- 英俊
- 口鼻眼眉均粗厚、端正、笔直

## Asset Roles

### portrait
面部硬锚点优先。

### narrative
无数细小运势光流从世界各处汇聚到一人，同时其他区域变暗。

## Must Keep

- 粗厚笔直五官
- 运的“流动/汇聚”关系

## Avoid

- 只画金甲太阳皇帝
- 把好运做成无成本圣光

## Community Drift / 网络漂移

- 金色帝王是社区强惯例，但原著外观硬锚点更少

## Evidence

- `S033` [Giant Sun | Saga of Gu](https://sagaofgu.com/characters/giant-sun-immortal-venerable/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：运不是金色幸运光，而是资源与可能性的重新分配。
- 必保留：粗厚笔直五官；运的“流动/汇聚”关系
- 禁止：只画金甲太阳皇帝；把好运做成无成本圣光


---

# 黑楼兰

- ID: `hei_lou_lan`
- 类别: 人物
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `prior_research_needs_source_refresh`

## Visual Thesis

隐藏力量：伪装与真身必须是两套身体，而真身不是“揭下面具变美女”，而是力量更真实。

## Canon Appearance / 硬锚点

- 伪装：臃肿如黑熊、三角眼、牙齿不齐
- 真身：女性、漂亮但强健、眉眼锋锐、霸气

## Asset Roles

### portrait
双身份资产。真身强调宽肩/力量，不走纤细古风美女。

## Must Keep

- 伪装/真身反差
- 真身力量感

## Avoid

- 单一红衣美女
- 真身纤弱
- 伪装仅靠面具

## Community Drift / 网络漂移

- 网络高度美型化

## Evidence

- **待补原文/章节来源。** 当前条目保留自前序调查，不升级为 locked canon。

## Generation Prompt Skeleton

- 核心命题：隐藏力量：伪装与真身必须是两套身体，而真身不是“揭下面具变美女”，而是力量更真实。
- 必保留：伪装/真身反差；真身力量感
- 禁止：单一红衣美女；真身纤弱；伪装仅靠面具


---

# 无极魔尊

- ID: `limitless`
- 类别: 人物
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

事实、推演结果与肉身之间可以无缝转换；真理不是口号，而能冻成“事实浮冰”。

## Canon Appearance / 硬锚点

- 后期可由人形事实浮冰转为血肉之躯；外貌硬描写相对少

## Asset Roles

### portrait
不要用八卦/数学符号硬装饰。

### narrative
人形事实浮冰→血肉；手直接伸入混沌验证；失败后碎回事实浮冰。

## Must Keep

- 事实浮冰
- 极简人物
- 实验/验证姿态

## Avoid

- 黑白太极仙人
- 公式符文覆盖全身

## Community Drift / 网络漂移

- 社区倾向用规则几何补空白，需与文本证据分层

## Evidence

- `S032` [Truthful Floating Ice | Fandom](https://reverend-insanity.fandom.com/wiki/Truthful_Floating_Ice) — chapter-referenced secondary
- `S042` [Limitless Demon Venerable | NovelWiki](https://novelwiki.net/reverend-insanity/characters/limitless-demon-venerable/) — secondary; verify against chapters

## Generation Prompt Skeleton

- 核心命题：事实、推演结果与肉身之间可以无缝转换；真理不是口号，而能冻成“事实浮冰”。
- 必保留：事实浮冰；极简人物；实验/验证姿态
- 禁止：黑白太极仙人；公式符文覆盖全身


---

# 紫山真君

- ID: `purple_mountain`
- 类别: 人物
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

身份反差本身就是视觉：邋遢乞丐老人只是放大的外表，真身是拇指大小的紫翼小人。

## Canon Appearance / 硬锚点

- 紫红乱发老乞丐
- 不整洁
- 参差黄牙
- 真身成人拇指大小
- 两只薄紫翼
- 深紫眼

## Asset Roles

### portrait
双形态资产：beggar/enlarged 与 miniman true form。

## Must Keep

- 紫红乱发
- 黄牙
- 真身极小
- 紫翼

## Avoid

- 紫衣仙风老爷爷
- 把真身信息完全删掉

## Community Drift / 网络漂移

- 网络更爱“紫衣智道老祖”，应纠偏

## Evidence

- `S030` [Purple Mountain True Monarch | Saga of Gu](https://sagaofgu.com/characters/purple-mountain-true-monarch/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：身份反差本身就是视觉：邋遢乞丐老人只是放大的外表，真身是拇指大小的紫翼小人。
- 必保留：紫红乱发；黄牙；真身极小；紫翼
- 禁止：紫衣仙风老爷爷；把真身信息完全删掉


---

# 红莲魔尊

- ID: `red_lotus`
- 类别: 人物
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

肉身可以回到过去，经历却不能真正被抹掉；年轻身体承载被重复磨老的姿态与眼睛。

## Canon Appearance / 硬锚点

- 年轻俊美
- 黑发及腰
- 额头九瓣红莲胎记
- 红衣/流动红袍是常见且相容的表层语言
- 目光沧桑

## Asset Roles

### portrait
至少半身/3/4身，保留年轻脸与老人般姿态的反差。

## Must Keep

- 九瓣红莲胎记
- 年轻身体
- 沧桑眼神/姿态

## Avoid

- 只剩红衣帅哥
- 用老人皱纹直接替代精神磨损

## Community Drift / 网络漂移

- 社区抓住红莲与红衣，却常弱化“年轻身体/老去姿态”

## Evidence

- `S029` [Red Lotus | Saga of Gu](https://sagaofgu.com/characters/red-lotus-demon-venerable/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：肉身可以回到过去，经历却不能真正被抹掉；年轻身体承载被重复磨老的姿态与眼睛。
- 必保留：九瓣红莲胎记；年轻身体；沧桑眼神/姿态
- 禁止：只剩红衣帅哥；用老人皱纹直接替代精神磨损


---

# 幽魂魔尊

- ID: `spectral_soul`
- 类别: 人物
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

走到极端后，“人”这个尺度与完整肖像已经不足以描述他；本体应被当作地貌。

## Canon Appearance / 硬锚点

- 三头
- 千臂千掌
- 正面头：龙角/狮鬃/蛇眼/象牙
- 另两头各有异形器官
- 数千米尺度
- 胸入云层/腿如山峰

## Asset Roles

### portrait
青年/人形阶段可单独人物立绘。

### boss_art
本体不强塞全身；允许只见脚、腹、云中三头、横跨画面的手臂。

## Must Keep

- 非人尺度
- 三头千臂
- 局部入画

## Avoid

- 把终极形态画成黑发俊美男
- 完整全身塞进1:1角色卡

## Community Drift / 网络漂移

- 网络“黑发苍白俊男”只能用于人形阶段

## Evidence

- `S026` [Spectral Soul | Saga of Gu](https://sagaofgu.com/characters/spectral-soul-demon-venerable/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：走到极端后，“人”这个尺度与完整肖像已经不足以描述他；本体应被当作地貌。
- 必保留：非人尺度；三头千臂；局部入画
- 禁止：把终极形态画成黑发俊美男；完整全身塞进1:1角色卡


---

# 星宿仙尊

- ID: `star_constellation`
- 类别: 人物
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

一个人的边界可以消失并进入天道运行；不是“站在星空前”，而是天地暂时长成她的样子。

## Canon Appearance / 硬锚点

- 深蓝长袍/长裙
- 长发可呈银河感或黑发垂腰
- 高挑
- 浓长眉
- 眼含星光/深邃智慧
- 有抚琴形象

## Asset Roles

### portrait
蓝衣、星眼、琴可保留。

### narrative
头发→银河→天幕→星点再组成她，表达以身合道。

## Must Keep

- 蓝
- 星眼
- 智慧感
- 边界消融的叙事层

## Avoid

- 只画普通星空女仙
- 把星星当贴花

## Community Drift / 网络漂移

- 社区易与紫薇撞模板

## Evidence

- `S027` [Star Constellation | Saga of Gu](https://sagaofgu.com/characters/star-constellation-immortal-venerable/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：一个人的边界可以消失并进入天道运行；不是“站在星空前”，而是天地暂时长成她的样子。
- 必保留：蓝；星眼；智慧感；边界消融的叙事层
- 禁止：只画普通星空女仙；把星星当贴花


---

# 吴帅

- ID: `wu_shuai`
- 类别: 人物
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

龙人英雄性与帝王事业通过“金龙”身体直接具身。

## Canon Appearance / 硬锚点

- 强健英俊
- 高鼻梁
- 坚毅嘴唇
- 金色龙鳞
- 黄玉/琥珀龙眼
- 金色珊瑚状龙角

## Asset Roles

### portrait
明确金龙，不默认黑龙/蓝龙；英雄体型。

## Must Keep

- 金鳞
- 黄玉眼
- 金珊瑚角

## Avoid

- 黑龙默认
- 普通美型男只加两只角

## Community Drift / 网络漂移

- 社区已形成“长发龙角美男”模板，但颜色常漂移

## Evidence

- `S031` [Wu Shuai | Saga of Gu](https://sagaofgu.com/characters/wu-shuai/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：龙人英雄性与帝王事业通过“金龙”身体直接具身。
- 必保留：金鳞；黄玉眼；金珊瑚角
- 禁止：黑龙默认；普通美型男只加两只角


---

# 武庸

- ID: `wu_yong`
- 类别: 人物
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

危险不必长得危险；越不起眼，致命行为越有反差。

## Canon Appearance / 硬锚点

- 中年
- 外貌普通
- 强健身体
- 锐眉
- 暗沉朦胧气质

## Asset Roles

### portrait
主动压低Boss感。

### skill_art
送友风等技能通过“普通日常动作突然致命”建立恐怖。

## Must Keep

- 普通
- 中年
- 锐眉
- 强健

## Avoid

- 帝王冠
- 金甲
- 巨大肩甲
- 狂暴王者表情

## Community Drift / 网络漂移

- 社区和AI易把南疆领袖做成“霸主”而丢普通感

## Evidence

- `S024` [Wu Yong | Fandom](https://reverend-insanity.fandom.com/wiki/Wu_Yong) — chapter-referenced secondary
- `S025` [Reverend Insanity ch.1706 - Wu Yong](https://wuxiaworld.eu/chapter/reverend-insanity-1709) — novel mirror

## Generation Prompt Skeleton

- 核心命题：危险不必长得危险；越不起眼，致命行为越有反差。
- 必保留：普通；中年；锐眉；强健
- 禁止：帝王冠；金甲；巨大肩甲；狂暴王者表情


---

# 紫薇仙子

- ID: `zi_wei`
- 类别: 人物
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

智慧与责任长期运算留下的不是“星星”，而是眉眼里的忧思。

## Canon Appearance / 硬锚点

- 紫色华袍
- 雪白皮肤
- 黑长发及腰
- 深潭般眼睛
- 脸上常带一层忧愁

## Asset Roles

### portrait
紫袍可用；关键是“总在想”的眉眼，不与星宿做同一套星空仙女。

## Must Keep

- 紫
- 忧思
- 深眼
- 黑长发

## Avoid

- 紫衣+星星模板
- 强势邪魅替代忧思

## Community Drift / 网络漂移

- 社区易与星宿撞脸

## Evidence

- `S034` [Zi Wei ch.1052](https://roliascan.com/read/reverend-insanity/ch1052-98512/) — novel mirror

## Generation Prompt Skeleton

- 核心命题：智慧与责任长期运算留下的不是“星星”，而是眉眼里的忧思。
- 必保留：紫；忧思；深眼；黑长发
- 禁止：紫衣+星星模板；强势邪魅替代忧思


---

# 龙宫

- ID: `dragon_palace`
- 类别: 仙蛊屋
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

最诱人的梦境也是最温柔的牢笼；华丽不是装饰，而是捕获机制的一部分。

## Canon Appearance / 硬锚点

- 雄阔宫殿
- 橙金微光
- 雕梁画栋
- 亭台楼阁
- 华丽
- 梦境/梦雾关联

## Asset Roles

### object_art
橙金东方宫殿，梦雾围绕。

### narrative
宫门诱人敞开；空间可重复嵌套，梦中之梦；让观者分不清进入龙宫还是龙宫进入梦。

## Must Keep

- 橙金
- 宫殿
- 梦雾
- 诱惑性牢笼

## Avoid

- 默认海蓝水晶龙宫
- 纯霸气战舰
- 只做皇权不做梦境捕获

## Community Drift / 网络漂移

- 网络常按海底龙宫惯性画蓝

## Evidence

- `S036` [Dragon Palace | Fandom](https://reverend-insanity.fandom.com/wiki/Dragon_Palace) — chapter-referenced secondary

## Generation Prompt Skeleton

- 核心命题：最诱人的梦境也是最温柔的牢笼；华丽不是装饰，而是捕获机制的一部分。
- 必保留：橙金；宫殿；梦雾；诱惑性牢笼
- 禁止：默认海蓝水晶龙宫；纯霸气战舰；只做皇权不做梦境捕获


---

# 八十八角真阳楼

- ID: `eighty_eight_true_yang_building`
- 类别: 仙蛊屋
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

分散在北原的资源、血脉与权限被逐层汇聚并稳定到中心。

## Canon Appearance / 硬锚点

- 初生时如春笋， tall/slender
- 塔体像七彩墨水液体持续晃动
- 随小塔沉入地下而逐层稳定

## Asset Roles

### object_art
优先恢复“液体彩墨春笋塔”而非普通金塔。

### process_art
小塔沉降→彩墨汇流→中央逐层凝固。

## Must Keep

- 春笋轮廓
- 七彩墨液态
- 逐层稳定

## Avoid

- 普通黄金古塔
- 只靠金色说明巨阳

## Community Drift / 网络漂移

- 网络建筑还原常金塔化，丢失初生态

## Evidence

- `S039` [Reverend Insanity ch.554 - Eighty-Eight True Yang Building](https://www.pyg-kit.com/en/books/reverend-insanity/chapters/78508) — novel mirror

## Generation Prompt Skeleton

- 核心命题：分散在北原的资源、血脉与权限被逐层汇聚并稳定到中心。
- 必保留：春笋轮廓；七彩墨液态；逐层稳定
- 禁止：普通黄金古塔；只靠金色说明巨阳


---

# 监天塔

- ID: `heaven_overseeing_tower`
- 类别: 仙蛊屋
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

秩序不是无瑕神殿，而是几百万年不断修补维持的旧系统；静态是历史，发动时才成为绝对规则。

## Canon Appearance / 硬锚点

- 古老白塔
- 塔身有瑕疵/伤痕
- 高耸
- 核心为宿命蛊
- 发动命败/相关能力时天地可被白光充满

## Asset Roles

### object_art
白塔但保留历史伤痕与修补层。

### activation
白光吞没建筑细节，塔先成为一束不可直视的规则之光。

### narrative
与血袍/小人物构成尺度与色彩对撞。

## Must Keep

- 旧白塔
- 伤痕
- 白光状态
- 宿命核心

## Avoid

- 完美无瑕商城白塔
- 雕梁画栋细节压过“光”
- 暖黄灯火主导

## Community Drift / 网络漂移

- 社区常把它当普通华丽白塔

## Evidence

- `S007` [Reverend Insanity ch.780 - Fate Immortal Gu](https://www.pyg-kit.com/en/books/reverend-insanity/chapters/78734) — novel mirror
- `S035` [Heaven Overseeing Tower | Fandom](https://reverend-insanity.fandom.com/wiki/Heaven_Overseeing_Tower) — chapter-referenced secondary

## Generation Prompt Skeleton

- 核心命题：秩序不是无瑕神殿，而是几百万年不断修补维持的旧系统；静态是历史，发动时才成为绝对规则。
- 必保留：旧白塔；伤痕；白光状态；宿命核心
- 禁止：完美无瑕商城白塔；雕梁画栋细节压过“光”；暖黄灯火主导


---

# 镇运天宫

- ID: `luck_suppression_heavenly_palace`
- 类别: 仙蛊屋
- 成熟度: `seed`
- 置信度: `low`
- 核验状态: `needs_primary_source`

## Visual Thesis

作为运道中心应表达“万运归一/镇运”，但当前网络造型未稳定，暂不锁具体环形特效。

## Canon Appearance / 硬锚点

- 宫殿型仙蛊屋；网络常见暗金/大型能量环，但证据层级不足

## Asset Roles

### object_art
暂保持低锁定；优先研究运势汇聚关系而非红色科幻同心环。

## Must Keep

- 运势中心
- 宫殿
- 北原/长生天关系

## Avoid

- 把社区红橙科幻圆环锁成Canon

## Community Drift / 网络漂移

- 网络视觉有传播但未稳定，当前资料源低信任

## Evidence

- `S040` [Luck Suppression Heavenly Palace explainer](https://basicutils.com/learn/gu-house/luck-suppression-heavenly-palace-reverend-insanity) — secondary explainer; low trust

## Generation Prompt Skeleton

- 核心命题：作为运道中心应表达“万运归一/镇运”，但当前网络造型未稳定，暂不锁具体环形特效。
- 必保留：运势中心；宫殿；北原/长生天关系
- 禁止：把社区红橙科幻圆环锁成Canon


---

# 疯魔窟

- ID: `crazed_demon_cave`
- 类别: 场景
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

不是“地下魔窟”，而是世界规则互相污染、试错、重写的实验器官。

## Canon Appearance / 硬锚点

- 九层结构
- 魔音导致道痕混乱
- 地形会随道痕混乱变化
- 深层道痕密到近似战场
- 核心目标与衍化/新道痕有关

## Asset Roles

### environment_art
不要默认紫晶洞穴；画规则失效：重力方向、物态、影子、声音等在边界处互相改写。

## Must Keep

- 规则冲突
- 地形被重写
- 新规则生成

## Avoid

- 紫色晶洞+骷髅+魔气
- 普通秘境

## Community Drift / 网络漂移

- 网络若只画“邪洞穴”会丢掉核心

## Evidence

- `S037` [Crazed Demon Cave | Saga of Gu](https://sagaofgu.com/locations/crazed-demon-cave/) — chapter-indexed secondary
- `S038` [Reverend Insanity ch.1176 - Crazed Demon Cave purpose](https://freewebnovel.com/novel/reverend-insanity/chapter-1176) — novel mirror

## Generation Prompt Skeleton

- 核心命题：不是“地下魔窟”，而是世界规则互相污染、试错、重写的实验器官。
- 必保留：规则冲突；地形被重写；新规则生成
- 禁止：紫色晶洞+骷髅+魔气；普通秘境


---

# 宿命大战

- ID: `fate_war`
- 类别: 场景
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

人的有限选择与巨大既定秩序发生正面碰撞；最强视觉不是爆炸，而是“连接→切断”。

## Canon Appearance / 硬锚点

- 监天塔/天庭白光
- 宿命关系网络/丝线
- 方源/个体作为破坏连接的主体
- 黑/白/血红常形成高效对撞，但非固定道德色

## Asset Roles

### narrative
白光秩序场+关系线+手/人去切断节点。

## Must Keep

- 关系网络
- 切断
- 尺度差
- 白光压迫

## Avoid

- 圣光正派vs黑魔王俗套
- 只画群战爆炸

## Community Drift / 网络漂移

- 高传播同人已形成“血袍对白光/命线”的视觉簇

## Evidence

- `S006` [Fate Gu | Fandom](https://reverend-insanity.fandom.com/wiki/Fate_Gu) — chapter-referenced secondary
- `S007` [Reverend Insanity ch.780 - Fate Immortal Gu](https://www.pyg-kit.com/en/books/reverend-insanity/chapters/78734) — novel mirror
- `S035` [Heaven Overseeing Tower | Fandom](https://reverend-insanity.fandom.com/wiki/Heaven_Overseeing_Tower) — chapter-referenced secondary

## Generation Prompt Skeleton

- 核心命题：人的有限选择与巨大既定秩序发生正面碰撞；最强视觉不是爆炸，而是“连接→切断”。
- 必保留：关系网络；切断；尺度差；白光压迫
- 禁止：圣光正派vs黑魔王俗套；只画群战爆炸


---

# 逆流河

- ID: `reverse_flow_river`
- 类别: 场景
- 成熟度: `observed`
- 置信度: `medium`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

世界全部朝一个方向流，只有一个人反向；重要的不是一帧“帅”，而是让人看见他已经走了很久还会继续。

## Canon Appearance / 硬锚点

- 巨大河流/水势
- 孤身逆行
- 持续性与路程感

## Asset Roles

### narrative
长构图/残影/磨损/足迹/上游无尽；环境大，人小。

## Must Keep

- 逆向关系
- 持续时间
- 人的尺度小

## Avoid

- 干净摆Pose
- 只靠巨浪和发光眼

## Community Drift / 网络漂移

- 网络青绿巨河+孤人共识强，但常缺“已走很久”的痕迹

## Evidence

- `S011` [Perseverance Gu | Fandom](https://reverend-insanity.fandom.com/wiki/Perseverance_Gu) — chapter-referenced secondary

## Generation Prompt Skeleton

- 核心命题：世界全部朝一个方向流，只有一个人反向；重要的不是一帧“帅”，而是让人看见他已经走了很久还会继续。
- 必保留：逆向关系；持续时间；人的尺度小
- 禁止：干净摆Pose；只靠巨浪和发光眼


---

# 三王山炼定仙游

- ID: `san_cha_refinement`
- 类别: 场景
- 成熟度: `canon_candidate`
- 置信度: `high`
- 核验状态: `verified_secondary_or_mirror`

## Visual Thesis

毁灭并不阻止创造，危机甚至成为炼制条件；最小的绿色仙蛊成为崩坏世界中的唯一新生焦点。

## Canon Appearance / 硬锚点

- 崩坏/暗金或压抑大环境
- 人物尺度相对小
- 定仙游翠绿小焦点
- 炼成/破茧

## Asset Roles

### narrative
大片压抑底色+极小纯绿焦点；不要满屏同强度特效。

## Must Keep

- 毁灭中的创造
- 小绿焦点
- 世界崩坏

## Avoid

- 把蝴蝶放大成主角而丢场景关系
- 所有元素同亮度

## Community Drift / 网络漂移

- 高传播二创已形成成熟构图语法

## Evidence

- `S005` [Fixed Immortal Travel | Saga of Gu](https://sagaofgu.com/gu/fixed-immortal-travel/) — chapter-indexed secondary

## Generation Prompt Skeleton

- 核心命题：毁灭并不阻止创造，危机甚至成为炼制条件；最小的绿色仙蛊成为崩坏世界中的唯一新生焦点。
- 必保留：毁灭中的创造；小绿焦点；世界崩坏
- 禁止：把蝴蝶放大成主角而丢场景关系；所有元素同亮度


---
