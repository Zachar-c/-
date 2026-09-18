# World Model Baseline v1

- 生成时间（显式 UTC）：`2026-09-16T08:20:35Z`
- 生成器：`lore_engine.reports@1`
- 实现审计：`3405` 条，规范化 SHA-256 `361332d556ae16ed353169da61a6c58631f58392f5c4ce2f3c2cf9cee36478fb`
- 本报告只保存证据 ID 与定位，不复制原文段落；详细登记见 [适配登记](../adaptation-register.md)、[正典索引](../canon-index.md) 与 [规则登记](../game-rule-register.md)。

| Claim | 已核验事实 | Evidence IDs | Source locations | 偏差候选 | 冲突与未知 | 当前实现映射 | 玩家后果 | 迁移/废止说明 |
|---|---|---|---|---|---|---|---|---|
| aptitude_capacity | “十步以下，是没有修行资质。十步到二十步之间，是丁<br>，往往最高能修行到一转二转。丙等资质，元海是空窍的四五成，通 | stage0_aptitude_capacity_m01<br>stage0_aptitude_capacity_m02 | gu_zhenren_main:stage0_recall/容纳@23764:23794<br>gu_zhenren_main:stage0_recall/容纳@27551:27581 | — | — | 83 findings | No aptitude-derived capacity or recovery rule is authorized. | Defer production work and record the verified scope before proposing a model. Do not promote current aptitude fields into world truth. |
| body_and_blood | 该是没有问题的。我检查了二长老的血统、魂魄、肉身，都是如假包<br>疲惫的样子，心中则在思索：“我的肉身本就是房睇长的肉身，因此 | stage0_body_and_blood_m01<br>stage0_body_and_blood_m02 | gu_zhenren_main:stage0_recall/血统@6841246:6841276<br>gu_zhenren_main:stage0_recall/血统@6846405:6846435 | — | — | 0 findings | No new body, bloodline, or injury rule is authorized. | Defer production work pending source verification. Do not infer rules from current data labels. |
| cultivator_aperture | 元对冲。对冲引发的剧烈波动，会对空窍造成损伤。 空<br>望蛊便答道：“人啊，我可以帮助你开窍。” 希望能让 | stage0_cultivator_aperture_m06<br>stage0_cultivator_aperture_t01 | gu_zhenren_main:stage0_recall/窍[^。！？]{0,3}破碎@167895:167925<br>gu_zhenren_main:stage0_recall/窍[^。！？]{0,3}破碎@8186110:8186140 | — | — | 0 findings | No aperture rule change is authorized by Stage 0. | Defer production work and collect exact P0 support, conditions, and counter-evidence. Keep current behavior unchanged while evidence is unresolved. |
| dao_marks | 紧一切机会，开始全力收集这些天道道痕。 每一根天道<br>是兽力虚影，究其本质，就是力量的道纹天地大道的痕迹！ | stage0_dao_marks_m01<br>stage0_dao_marks_m04 | gu_zhenren_main:stage0_recall/痕迹@7261678:7261708<br>gu_zhenren_main:stage0_recall/痕迹@1075764:1075794 | — | — | 16 findings | If approved later, players will not receive unsupported universal dao-mark experience for routine actions. | Mark generalized mortal dao-mark progression for deprecation; do not delete fields or migrate saves in Stage 0. Exact P0 exceptions must be preserved before any later removal. |
| economy_and_primeval_stones | 后，方源再不强求。最终他以两块仙元石，买下春星雨，以及足够十<br>存在，而你不行。不过我们可以再做交易，你把你的青年给我，我就 | stage0_economy_and_primeval_stones_m01<br>stage0_economy_and_primeval_stones_t01 | gu_zhenren_main:stage0_recall/货币@2498512:2498542<br>gu_zhenren_main:stage0_recall/货币@196619:196649 | — | — | 42 findings | If verified later, players can buy ordinary goods but must use relationships, knowledge, or risk for non-fungible assets. | Keep promotion economy audit-only and defer any pricing or inventory migration. Do not change shops, prices, materials, or saves in Stage 0. |
| force_and_social_order | 和中洲大异。 南疆正道势力中，武家独占鳌头。历史上<br>和利益。漠颜找我麻烦，已经是坏了规矩，为了维护家族名誉，他必 | stage0_force_and_social_order_m04<br>stage0_force_and_social_order_m06 | gu_zhenren_main:stage0_recall/秩序@4546567:4546597<br>gu_zhenren_main:stage0_recall/秩序@128371:128401 | — | — | 65 findings | If verified later, coercion and status choices leave visible future protection, hostility, or pursuit consequences. | Audit existing NPC and faction outcomes only; defer production changes. One-off current outcomes do not prove the proposed model. |
| gu_activation | 低劣，真元极其有限。方源之前连续催动蛊虫，已经差不多耗尽了。<br>候，步骤简略，效率更高。导致原本催动一两次万蛟的时间，此时他 | stage0_gu_activation_m01<br>stage0_gu_activation_m03 | gu_zhenren_main:stage0_recall/耗尽@5579257:5579287<br>gu_zhenren_main:stage0_recall/耗尽@5843155:5843185 | — | — | 806 findings | No activation-cost or fallback change is authorized. | Defer production work and verify support plus exceptions. Do not treat role fallbacks as source facts. |
| gu_feeding | 价值在于它能和一些食物搭配起来，喂养蛊虫。 比方说<br>数越高，喂养的代价就越大，但同时喂养的间隔时间也大幅度地拉长 | stage0_gu_feeding_m01<br>stage0_gu_feeding_m06 | gu_zhenren_main:stage0_recall/进食@131840:131870<br>gu_zhenren_main:stage0_recall/进食@1516243:1516273 | — | — | 158 findings | If verified later, upkeep choices expose specific food, timing, and failure consequences. | Audit feeding fields only; defer any data or runtime migration. Promotion materials remain deferred. |
| gu_is_independent_entity | 感受到春秋蝉的气息，月光蛊的意志，立即缴械投降，畏惧得只能龟缩到<br>，只要是知道了我们的名字，我们就听命于他。人啊，你既然已经知道 | stage0_gu_is_independent_entity_m06<br>stage0_gu_is_independent_entity_t01 | gu_zhenren_main:stage0_recall/听命于@71110:71142<br>gu_zhenren_main:stage0_recall/听命于@127098:127129 | — | — | 0 findings | If verified later, ownership, transfer, feeding, and loss remain attached to individual Gu. | Audit instance identity only; make no production change before P0 verification. Do not infer independence from existing instance fields. |
| gu_is_life | 间变得十分精彩。 一只活蛊和一只死蛊之间的价值差距<br>十赌八输。剩下的两成赢面中，还分死蛊和活蛊。 死蛊 | stage0_gu_is_life_m01<br>stage0_gu_is_life_m02 | gu_zhenren_main:stage0_recall/有灵性@140444:140474<br>gu_zhenren_main:stage0_recall/有灵性@142866:142896 | — | — | 0 findings | If verified later, players must treat Gu as maintained living entities rather than disposable skill tokens. | Audit current lifecycle behavior only; make no production change before P0 verification. Existing implementation is not evidence for retention. |
| gu_ownership | ，从严格意义上来讲，智慧蛊并不归属于方源。 武家的<br>喜，这样一来，天下所有的蛊虫都归属自己了，从此以后他将是世界之主！ | stage0_gu_ownership_m05<br>stage0_gu_ownership_t01 | gu_zhenren_main:stage0_recall/归属@4566335:4566365<br>gu_zhenren_main:stage0_recall/归属@196137:196170 | — | — | 0 findings | No ownership or transfer behavior changes are authorized. | Defer and gather P0 support, conditions, and counterexamples. Current inventory representation is observation only. |
| gu_recipe | 宙道、智道等等杀招，之后又是各种蛊方，蛊方越老越稀少便越好。<br>。 当即，方源用了三张秘方，获得了十万只星萤虫。只 | stage0_gu_recipe_m02<br>stage0_gu_recipe_m03 | gu_zhenren_main:stage0_recall/丹方@2847288:2847318<br>gu_zhenren_main:stage0_recall/丹方@1725691:1725721 | — | — | 0 findings | No recipe unlock or execution rule change is authorized. | Defer and verify source-backed knowledge and execution boundaries. Current recipe data cannot prove the world rule. |
| gu_refinement | 他正在构思并完善和稀泥仙蛊的炼制秘方。 和之前<br>则拍着大腿喊叫起来：“我知道如何炼制成功蛊了，就是通过失败啊 | stage0_gu_refinement_m01<br>stage0_gu_refinement_t02 | gu_zhenren_main:stage0_recall/秘方@2452388:2452418<br>gu_zhenren_main:stage0_recall/秘方@3154163:3154193 | — | — | 582 findings | If verified later, players can distinguish knowledge-backed refinement from explicitly risky experimentation. | Audit current refinement paths; defer production redesign and migration. Do not modify recipes, materials, or success logic in Stage 0. |
| information_leak | ，只有让你自己炼制出来，才会掩人耳目，不让人发现我。”沙枭又<br>太上三长老……” 这种情报，捂不住，南疆蛊仙界已经 | stage0_information_leak_m02<br>stage0_information_leak_m06 | gu_zhenren_main:stage0_recall/消息灵通@5540867:5540897<br>gu_zhenren_main:stage0_recall/消息灵通@5666098:5666128 | — | — | 0 findings | No leak, secrecy, or enemy-learning mechanic is authorized yet. | Defer until exact support, conditions, and representative cases are recorded. Do not infer a mechanic from design prose alone. |
| inheritance | 上立碑之后，还在此时留下了一道隐秘传承。 这传承隐<br>对于方源而言，他掌握着海量传承内容，自然也就拥有无数资 | stage0_inheritance_m01<br>stage0_inheritance_m06 | gu_zhenren_main:stage0_recall/继承@917762:917792<br>gu_zhenren_main:stage0_recall/继承@5447481:5447511 | — | — | 0 findings | No inheritance reward or access rule change is authorized. | Defer and verify P0 support and exceptions. Current reward rooms are not authoritative. |
| kill_move | ：“诸位可知道我东方家有一个三人合击的杀招，名为三心合魂？”<br>人的胸膛上。 这是仙道连招！ 所谓仙道连 | stage0_kill_move_m02<br>stage0_kill_move_m06 | gu_zhenren_main:stage0_recall/招式@1875658:1875688<br>gu_zhenren_main:stage0_recall/招式@3515096:3515126 | — | — | 36 findings | If verified later, players must acquire, prepare, and expose a combination instead of pressing an unexplained universal action. | Audit existing kill-move surfaces only; defer production redesign. Do not modify combat runtime in Stage 0. |
| lifespan | 代价，请万寿娘子出手，为他们延长阳寿。 久而久之，<br>。只要你抓住寿蛊，你就能增添新的寿命。” 人祖早就 | stage0_lifespan_m02<br>stage0_lifespan_t02 | gu_zhenren_main:stage0_recall/短寿@3462829:3462859<br>gu_zhenren_main:stage0_recall/短寿@125360:125390 | — | — | 76 findings | If verified later, lifespan spending is exceptional, previewed, and irreversible rather than routine shopping currency. | Audit lifespan payment surfaces only; defer runtime and economy migration. No production price or cost changes in Stage 0. |
| mortal_immortal_boundary | 己无能为力！ 方源已经成仙！若是过去，铁若男不知道<br>在，方源的计划里，并非是一人敢干蛊仙。他要借助八十八角真阳楼 | stage0_mortal_immortal_boundary_m01<br>stage0_mortal_immortal_boundary_m03 | gu_zhenren_main:stage0_recall/长生@5669544:5669574<br>gu_zhenren_main:stage0_recall/长生@2019668:2019698 | — | — | 0 findings | No ascension boundary or immortal-stage production behavior is authorized. | Defer until exact P0 evidence and conditions are complete. Do not approximate the boundary from rank fields. |
| natal_gu | “若是找到那酒虫，炼化为本命蛊，比家族中的月光蛊要好多<br>化的第一只蛊虫，意义重大，称之为本命蛊，性命交修。一旦灭亡，蛊 | stage0_natal_gu_m01<br>stage0_natal_gu_m03 | gu_zhenren_main:stage0_recall/命蛊@29530:29561<br>gu_zhenren_main:stage0_recall/命蛊@30561:30592 | — | — | 0 findings | If later approved, players will not choose a consequence-free core slot detached from cultivation history. | Deprecate the arbitrary-slot hypothesis in future design; preserve current saves and runtime until a separately approved migration exists. No production field or save migration occurs in Stage 0. |
| primeval_essence | 蛊师的青铜元海，每一滴海水，都是真元。是方源的生命元力，是方<br>。每过一段时间，元海就会自动补充真元。像方源这种丙等资质，大 | stage0_primeval_essence_m05<br>stage0_primeval_essence_m06 | gu_zhenren_main:stage0_recall/催动真元@37868:37898<br>gu_zhenren_main:stage0_recall/催动真元@39122:39152 | — | — | 114 findings | If verified later, players see combat cost as a view of one world resource rather than two unrelated currencies. | Audit dual-resource semantics only; defer any migration until evidence and a later slice are approved. Do not alter essence or true-qi runtime state in Stage 0. |
| rank_and_subrank | 一共有九大境界，从下到上，分别是一转、二转、三转直至九转。每<br>，刚刚起步，战力孱弱，最为常见。二转，则是骨干、基石，十分普 | stage0_rank_and_subrank_m03<br>stage0_rank_and_subrank_m05 | gu_zhenren_main:stage0_recall/转阶@27399:27429<br>gu_zhenren_main:stage0_recall/转阶@2121664:2121694 | — | — | 1011 findings | No new rank gate, multiplier, or promotion rule is authorized. | Collect exact support and exceptions before adjudicating progression semantics. F1 and Q8-G remain audit-only. |
| soul | 灵，只要进入荡魂山的范围，它们的魂魄就要受到震荡。越接近峰巅<br>单纯的比拼战力，而是比较意志力，魂力。有为师的魂魄暗中辅助你 | stage0_soul_m01<br>stage0_soul_m04 | gu_zhenren_main:stage0_recall/魂飞魄散@1351979:1352009<br>gu_zhenren_main:stage0_recall/魂飞魄散@1252041:1252071 | — | — | 147 findings | No soul-derived action-point or capacity rule is authorized. | Defer and collect exact P0 support, conditions, and counterexamples. Current soul fields are implementation observations only. |
| tribulation_or_ascension | 念。 但是当他成功渡过天劫，成为蛊仙之后，他站在全<br>地灾已经没有。但每隔十年就是一场天劫，五十年一次浩劫，百年一 | stage0_tribulation_or_ascension_m03<br>stage0_tribulation_or_ascension_m04 | gu_zhenren_main:stage0_recall/劫难@2304551:2304581<br>gu_zhenren_main:stage0_recall/劫难@2765279:2765309 | — | — | 0 findings | No tribulation, ascension, or boss-gate production rule is authorized. | Defer until exact P0 evidence and a later-stage design are approved. Do not equate current boss gates with ascension. |
| world_scope_and_compression | 至尊仙窍中。 至尊仙窍广袤无比，内分五域九天的格局<br>他发现：至尊仙窍中的五域九天，不仅格局方面和外界 | stage0_world_scope_and_compression_m01<br>stage0_world_scope_and_compression_m04 | gu_zhenren_main:stage0_recall/格局@3953772:3953802<br>gu_zhenren_main:stage0_recall/格局@3986539:3986569 | — | — | 269 findings | Players receive a finite run structure without being told that compressed layers are literal world geography or universal law. | Retain as an audit hypothesis only; defer production authorization until source boundaries are verified. Five-layer structure is not source evidence. |

## 已核验事实

- `aptitude_capacity`：事实：“十步以下，是没有修行资质。十步到二十步之间，是丁<br>，往往最高能修行到一转二转。丙等资质，元海是空窍的四五成，通；证据：stage0_aptitude_capacity_m01<br>stage0_aptitude_capacity_m02；定位：gu_zhenren_main:stage0_recall/容纳@23764:23794<br>gu_zhenren_main:stage0_recall/容纳@27551:27581
- `body_and_blood`：事实：该是没有问题的。我检查了二长老的血统、魂魄、肉身，都是如假包<br>疲惫的样子，心中则在思索：“我的肉身本就是房睇长的肉身，因此；证据：stage0_body_and_blood_m01<br>stage0_body_and_blood_m02；定位：gu_zhenren_main:stage0_recall/血统@6841246:6841276<br>gu_zhenren_main:stage0_recall/血统@6846405:6846435
- `cultivator_aperture`：事实：元对冲。对冲引发的剧烈波动，会对空窍造成损伤。 空<br>望蛊便答道：“人啊，我可以帮助你开窍。” 希望能让；证据：stage0_cultivator_aperture_m06<br>stage0_cultivator_aperture_t01；定位：gu_zhenren_main:stage0_recall/窍[^。！？]{0,3}破碎@167895:167925<br>gu_zhenren_main:stage0_recall/窍[^。！？]{0,3}破碎@8186110:8186140
- `dao_marks`：事实：紧一切机会，开始全力收集这些天道道痕。 每一根天道<br>是兽力虚影，究其本质，就是力量的道纹天地大道的痕迹！；证据：stage0_dao_marks_m01<br>stage0_dao_marks_m04；定位：gu_zhenren_main:stage0_recall/痕迹@7261678:7261708<br>gu_zhenren_main:stage0_recall/痕迹@1075764:1075794
- `economy_and_primeval_stones`：事实：后，方源再不强求。最终他以两块仙元石，买下春星雨，以及足够十<br>存在，而你不行。不过我们可以再做交易，你把你的青年给我，我就；证据：stage0_economy_and_primeval_stones_m01<br>stage0_economy_and_primeval_stones_t01；定位：gu_zhenren_main:stage0_recall/货币@2498512:2498542<br>gu_zhenren_main:stage0_recall/货币@196619:196649
- `force_and_social_order`：事实：和中洲大异。 南疆正道势力中，武家独占鳌头。历史上<br>和利益。漠颜找我麻烦，已经是坏了规矩，为了维护家族名誉，他必；证据：stage0_force_and_social_order_m04<br>stage0_force_and_social_order_m06；定位：gu_zhenren_main:stage0_recall/秩序@4546567:4546597<br>gu_zhenren_main:stage0_recall/秩序@128371:128401
- `gu_activation`：事实：低劣，真元极其有限。方源之前连续催动蛊虫，已经差不多耗尽了。<br>候，步骤简略，效率更高。导致原本催动一两次万蛟的时间，此时他；证据：stage0_gu_activation_m01<br>stage0_gu_activation_m03；定位：gu_zhenren_main:stage0_recall/耗尽@5579257:5579287<br>gu_zhenren_main:stage0_recall/耗尽@5843155:5843185
- `gu_feeding`：事实：价值在于它能和一些食物搭配起来，喂养蛊虫。 比方说<br>数越高，喂养的代价就越大，但同时喂养的间隔时间也大幅度地拉长；证据：stage0_gu_feeding_m01<br>stage0_gu_feeding_m06；定位：gu_zhenren_main:stage0_recall/进食@131840:131870<br>gu_zhenren_main:stage0_recall/进食@1516243:1516273
- `gu_is_independent_entity`：事实：感受到春秋蝉的气息，月光蛊的意志，立即缴械投降，畏惧得只能龟缩到<br>，只要是知道了我们的名字，我们就听命于他。人啊，你既然已经知道；证据：stage0_gu_is_independent_entity_m06<br>stage0_gu_is_independent_entity_t01；定位：gu_zhenren_main:stage0_recall/听命于@71110:71142<br>gu_zhenren_main:stage0_recall/听命于@127098:127129
- `gu_is_life`：事实：间变得十分精彩。 一只活蛊和一只死蛊之间的价值差距<br>十赌八输。剩下的两成赢面中，还分死蛊和活蛊。 死蛊；证据：stage0_gu_is_life_m01<br>stage0_gu_is_life_m02；定位：gu_zhenren_main:stage0_recall/有灵性@140444:140474<br>gu_zhenren_main:stage0_recall/有灵性@142866:142896
- `gu_ownership`：事实：，从严格意义上来讲，智慧蛊并不归属于方源。 武家的<br>喜，这样一来，天下所有的蛊虫都归属自己了，从此以后他将是世界之主！；证据：stage0_gu_ownership_m05<br>stage0_gu_ownership_t01；定位：gu_zhenren_main:stage0_recall/归属@4566335:4566365<br>gu_zhenren_main:stage0_recall/归属@196137:196170
- `gu_recipe`：事实：宙道、智道等等杀招，之后又是各种蛊方，蛊方越老越稀少便越好。<br>。 当即，方源用了三张秘方，获得了十万只星萤虫。只；证据：stage0_gu_recipe_m02<br>stage0_gu_recipe_m03；定位：gu_zhenren_main:stage0_recall/丹方@2847288:2847318<br>gu_zhenren_main:stage0_recall/丹方@1725691:1725721
- `gu_refinement`：事实：他正在构思并完善和稀泥仙蛊的炼制秘方。 和之前<br>则拍着大腿喊叫起来：“我知道如何炼制成功蛊了，就是通过失败啊；证据：stage0_gu_refinement_m01<br>stage0_gu_refinement_t02；定位：gu_zhenren_main:stage0_recall/秘方@2452388:2452418<br>gu_zhenren_main:stage0_recall/秘方@3154163:3154193
- `information_leak`：事实：，只有让你自己炼制出来，才会掩人耳目，不让人发现我。”沙枭又<br>太上三长老……” 这种情报，捂不住，南疆蛊仙界已经；证据：stage0_information_leak_m02<br>stage0_information_leak_m06；定位：gu_zhenren_main:stage0_recall/消息灵通@5540867:5540897<br>gu_zhenren_main:stage0_recall/消息灵通@5666098:5666128
- `inheritance`：事实：上立碑之后，还在此时留下了一道隐秘传承。 这传承隐<br>对于方源而言，他掌握着海量传承内容，自然也就拥有无数资；证据：stage0_inheritance_m01<br>stage0_inheritance_m06；定位：gu_zhenren_main:stage0_recall/继承@917762:917792<br>gu_zhenren_main:stage0_recall/继承@5447481:5447511
- `kill_move`：事实：：“诸位可知道我东方家有一个三人合击的杀招，名为三心合魂？”<br>人的胸膛上。 这是仙道连招！ 所谓仙道连；证据：stage0_kill_move_m02<br>stage0_kill_move_m06；定位：gu_zhenren_main:stage0_recall/招式@1875658:1875688<br>gu_zhenren_main:stage0_recall/招式@3515096:3515126
- `lifespan`：事实：代价，请万寿娘子出手，为他们延长阳寿。 久而久之，<br>。只要你抓住寿蛊，你就能增添新的寿命。” 人祖早就；证据：stage0_lifespan_m02<br>stage0_lifespan_t02；定位：gu_zhenren_main:stage0_recall/短寿@3462829:3462859<br>gu_zhenren_main:stage0_recall/短寿@125360:125390
- `mortal_immortal_boundary`：事实：己无能为力！ 方源已经成仙！若是过去，铁若男不知道<br>在，方源的计划里，并非是一人敢干蛊仙。他要借助八十八角真阳楼；证据：stage0_mortal_immortal_boundary_m01<br>stage0_mortal_immortal_boundary_m03；定位：gu_zhenren_main:stage0_recall/长生@5669544:5669574<br>gu_zhenren_main:stage0_recall/长生@2019668:2019698
- `natal_gu`：事实：“若是找到那酒虫，炼化为本命蛊，比家族中的月光蛊要好多<br>化的第一只蛊虫，意义重大，称之为本命蛊，性命交修。一旦灭亡，蛊；证据：stage0_natal_gu_m01<br>stage0_natal_gu_m03；定位：gu_zhenren_main:stage0_recall/命蛊@29530:29561<br>gu_zhenren_main:stage0_recall/命蛊@30561:30592
- `primeval_essence`：事实：蛊师的青铜元海，每一滴海水，都是真元。是方源的生命元力，是方<br>。每过一段时间，元海就会自动补充真元。像方源这种丙等资质，大；证据：stage0_primeval_essence_m05<br>stage0_primeval_essence_m06；定位：gu_zhenren_main:stage0_recall/催动真元@37868:37898<br>gu_zhenren_main:stage0_recall/催动真元@39122:39152
- `rank_and_subrank`：事实：一共有九大境界，从下到上，分别是一转、二转、三转直至九转。每<br>，刚刚起步，战力孱弱，最为常见。二转，则是骨干、基石，十分普；证据：stage0_rank_and_subrank_m03<br>stage0_rank_and_subrank_m05；定位：gu_zhenren_main:stage0_recall/转阶@27399:27429<br>gu_zhenren_main:stage0_recall/转阶@2121664:2121694
- `soul`：事实：灵，只要进入荡魂山的范围，它们的魂魄就要受到震荡。越接近峰巅<br>单纯的比拼战力，而是比较意志力，魂力。有为师的魂魄暗中辅助你；证据：stage0_soul_m01<br>stage0_soul_m04；定位：gu_zhenren_main:stage0_recall/魂飞魄散@1351979:1352009<br>gu_zhenren_main:stage0_recall/魂飞魄散@1252041:1252071
- `tribulation_or_ascension`：事实：念。 但是当他成功渡过天劫，成为蛊仙之后，他站在全<br>地灾已经没有。但每隔十年就是一场天劫，五十年一次浩劫，百年一；证据：stage0_tribulation_or_ascension_m03<br>stage0_tribulation_or_ascension_m04；定位：gu_zhenren_main:stage0_recall/劫难@2304551:2304581<br>gu_zhenren_main:stage0_recall/劫难@2765279:2765309
- `world_scope_and_compression`：事实：至尊仙窍中。 至尊仙窍广袤无比，内分五域九天的格局<br>他发现：至尊仙窍中的五域九天，不仅格局方面和外界；证据：stage0_world_scope_and_compression_m01<br>stage0_world_scope_and_compression_m04；定位：gu_zhenren_main:stage0_recall/格局@3953772:3953802<br>gu_zhenren_main:stage0_recall/格局@3986539:3986569

## 偏差候选

| Claim | Preliminary | Effective | Confidence |
|---|---|---|---|
| `aptitude_capacity` | — | retain | unknown |
| `body_and_blood` | — | retain | unknown |
| `cultivator_aperture` | — | retain | unknown |
| `dao_marks` | — | remove | unknown |
| `economy_and_primeval_stones` | — | revise | unknown |
| `force_and_social_order` | — | revise | unknown |
| `gu_activation` | — | retain | unknown |
| `gu_feeding` | — | revise | unknown |
| `gu_is_independent_entity` | — | retain | unknown |
| `gu_is_life` | — | retain | unknown |
| `gu_ownership` | — | retain | unknown |
| `gu_recipe` | — | retain | unknown |
| `gu_refinement` | — | revise | unknown |
| `information_leak` | — | retain | unknown |
| `inheritance` | — | retain | unknown |
| `kill_move` | — | revise | unknown |
| `lifespan` | — | revise | unknown |
| `mortal_immortal_boundary` | — | retain | unknown |
| `natal_gu` | — | remove | unknown |
| `primeval_essence` | — | revise | unknown |
| `rank_and_subrank` | — | retain | unknown |
| `soul` | — | retain | unknown |
| `tribulation_or_ascension` | — | retain | unknown |
| `world_scope_and_compression` | — | retain | unknown |

## 冲突与未知


## 当前实现映射

以下仅为只读实现观察，不构成世界事实。每条 claim 最多展示 12 个定位；完整审计由上方规范化哈希冻结。

- `aptitude_capacity`：83 条；data/balance.json#/aptitude_recovery_multiplier<br>docs/lore/adaptation-register.md#line:14<br>docs/lore/canon-index.md#line:20<br>docs/lore/canon-index.md#line:21<br>docs/lore/canon-index.md#line:22<br>docs/lore/content-source-schema.md#line:82<br>docs/lore/content-source-schema.md#line:83<br>docs/lore/content-source-schema.md#line:90<br>docs/wiki/concepts/resource-model.md#line:19<br>docs/wiki/concepts/resource-model.md#line:5<br>scripts/domain/action_preview_service.gd#line:1079<br>scripts/domain/action_preview_service.gd#line:1080（另省略 71 条）
- `body_and_blood`：0 条；—
- `cultivator_aperture`：0 条；—
- `dao_marks`：16 条；scripts/domain/blood_qi_rules.gd#line:7<br>scripts/domain/content_catalog.gd#line:14<br>scripts/domain/content_catalog.gd#line:26<br>scripts/domain/content_catalog.gd#line:39<br>scripts/domain/content_catalog.gd#line:870<br>scripts/domain/core_gu_rules.gd#line:87<br>scripts/domain/cultivator_rules.gd#line:16<br>scripts/domain/gu_instance.gd#line:28<br>scripts/domain/soul_rules.gd#line:5<br>scripts/domain/sword_mark_rules.gd#line:103<br>scripts/domain/sword_mark_rules.gd#line:110<br>scripts/domain/sword_mark_rules.gd#line:116（另省略 4 条）
- `economy_and_primeval_stones`：42 条；docs/lore/content-source-schema.md#line:55<br>docs/lore/game-rule-register.md#line:19<br>docs/lore/game-rule-register.md#line:20<br>docs/lore/game-rule-register.md#line:21<br>docs/wiki/concepts/economy.md#line:5<br>docs/wiki/concepts/gameplay-loop.md#line:38<br>scripts/domain/action_preview_service.gd#line:401<br>scripts/domain/action_preview_service.gd#line:409<br>scripts/domain/action_preview_service.gd#line:976<br>scripts/domain/blood_qi_rules.gd#line:89<br>scripts/domain/blood_qi_rules.gd#line:90<br>scripts/domain/blood_qi_rules.gd#line:92（另省略 30 条）
- `force_and_social_order`：65 条；docs/lore/content-source-schema.md#line:183<br>docs/lore/content-source-schema.md#line:67<br>docs/wiki/concepts/world-model-translation.md#line:26<br>scripts/domain/action_preview_service.gd#line:384<br>scripts/domain/action_preview_service.gd#line:398<br>scripts/domain/action_preview_service.gd#line:409<br>scripts/domain/action_preview_service.gd#line:420<br>scripts/domain/content_catalog.gd#line:1033<br>scripts/domain/content_catalog.gd#line:1034<br>scripts/domain/content_catalog.gd#line:121<br>scripts/domain/content_catalog.gd#line:1363<br>scripts/domain/content_catalog.gd#line:1365（另省略 53 条）
- `gu_activation`：806 条；data/gu.json#/0/v1_effect<br>data/gu.json#/1/v1_effect<br>data/gu.json#/10/role<br>data/gu.json#/100/role<br>data/gu.json#/101/role<br>data/gu.json#/102/role<br>data/gu.json#/103/role<br>data/gu.json#/104/role<br>data/gu.json#/105/role<br>data/gu.json#/106/role<br>data/gu.json#/107/role<br>data/gu.json#/108/role（另省略 794 条）
- `gu_feeding`：158 条；data/gu.json#/0/feeding_cost<br>data/gu.json#/0/feeding_need<br>data/gu.json#/1/feeding_cost<br>data/gu.json#/1/feeding_need<br>data/gu.json#/10/feeding_cost<br>data/gu.json#/10/feeding_need<br>data/gu.json#/11/feeding_cost<br>data/gu.json#/11/feeding_need<br>data/gu.json#/12/feeding_cost<br>data/gu.json#/12/feeding_need<br>data/gu.json#/13/feeding_cost<br>data/gu.json#/13/feeding_need（另省略 146 条）
- `gu_is_independent_entity`：0 条；—
- `gu_is_life`：0 条；—
- `gu_ownership`：0 条；—
- `gu_recipe`：0 条；—
- `gu_refinement`：582 条；data/balance.json#/material_refine_efficiency<br>data/balance.json#/stone_per_t1_material<br>docs/lore/content-source-schema.md#line:102<br>docs/lore/content-source-schema.md#line:114<br>docs/lore/content-source-schema.md#line:13<br>docs/lore/content-source-schema.md#line:23<br>docs/lore/content-source-schema.md#line:51<br>docs/lore/content-source-schema.md#line:94<br>docs/lore/content-source-schema.md#line:99<br>docs/lore/game-rule-register.md#line:27<br>docs/lore/game-rule-register.md#line:28<br>docs/lore/game-rule-register.md#line:29（另省略 570 条）
- `information_leak`：0 条；—
- `inheritance`：0 条；—
- `kill_move`：36 条；docs/lore/adaptation-register.md#line:13<br>docs/lore/game-rule-register.md#line:10<br>docs/lore/game-rule-register.md#line:11<br>docs/lore/game-rule-register.md#line:8<br>docs/lore/game-rule-register.md#line:9<br>docs/wiki/concepts/combat-system.md#line:41<br>docs/wiki/concepts/combat-system.md#line:5<br>docs/wiki/concepts/gameplay-loop.md#line:15<br>docs/wiki/concepts/gameplay-loop.md#line:30<br>docs/wiki/concepts/gameplay-loop.md#line:38<br>docs/wiki/concepts/gu-and-synthesis.md#line:38<br>docs/wiki/concepts/gu-and-synthesis.md#line:42（另省略 24 条）
- `lifespan`：76 条；docs/wiki/concepts/resource-model.md#line:29<br>docs/wiki/concepts/resource-model.md#line:5<br>scripts/domain/action_preview_service.gd#line:1086<br>scripts/domain/action_preview_service.gd#line:1089<br>scripts/domain/action_preview_service.gd#line:1097<br>scripts/domain/action_preview_service.gd#line:635<br>scripts/domain/action_preview_service.gd#line:636<br>scripts/domain/action_preview_service.gd#line:637<br>scripts/domain/action_preview_service.gd#line:638<br>scripts/domain/action_preview_service.gd#line:646<br>scripts/domain/action_preview_service.gd#line:647<br>scripts/domain/action_preview_service.gd#line:656（另省略 64 条）
- `mortal_immortal_boundary`：0 条；—
- `natal_gu`：0 条；—
- `primeval_essence`：114 条；data/balance.json#/stone_to_essence_per_stone<br>data/gu.json#/0<br>data/gu.json#/0/essence_cost<br>data/gu.json#/1<br>data/gu.json#/1/essence_cost<br>data/gu.json#/10/essence_cost<br>data/gu.json#/11/essence_cost<br>data/gu.json#/12/essence_cost<br>data/gu.json#/13/essence_cost<br>data/gu.json#/14/essence_cost<br>data/gu.json#/15/essence_cost<br>data/gu.json#/2/essence_cost（另省略 102 条）
- `rank_and_subrank`：1011 条；data/balance.json#/rank_step_ratio<br>data/gu.json#/0/rank<br>data/gu.json#/1/rank<br>data/gu.json#/10/rank<br>data/gu.json#/100/rank<br>data/gu.json#/101/rank<br>data/gu.json#/102/rank<br>data/gu.json#/103/rank<br>data/gu.json#/104/rank<br>data/gu.json#/105/rank<br>data/gu.json#/106/rank<br>data/gu.json#/107/rank（另省略 999 条）
- `soul`：147 条；data/balance.json#/soul_burst_capacity_ratio<br>data/balance.json#/soul_calm_beast_below<br>data/balance.json#/soul_calm_departure_below<br>data/balance.json#/soul_calm_emotional_below<br>docs/wiki/concepts/combat-system.md#line:31<br>docs/wiki/concepts/resource-model.md#line:27<br>docs/wiki/concepts/resource-model.md#line:5<br>scripts/domain/action_points.gd#line:11<br>scripts/domain/action_points.gd#line:14<br>scripts/domain/action_points.gd#line:15<br>scripts/domain/action_points.gd#line:16<br>scripts/domain/action_preview_service.gd#line:4（另省略 135 条）
- `tribulation_or_ascension`：0 条；—
- `world_scope_and_compression`：269 条；data/schools.json#/blood/starter_gu_ids<br>data/schools.json#/bone/starter_gu_ids<br>data/schools.json#/dream/starter_gu_ids<br>data/schools.json#/earth/starter_gu_ids<br>data/schools.json#/fire/starter_gu_ids<br>data/schools.json#/force/starter_gu_ids<br>data/schools.json#/gold/starter_gu_ids<br>data/schools.json#/heaven/starter_gu_ids<br>data/schools.json#/human/starter_gu_ids<br>data/schools.json#/light/starter_gu_ids<br>data/schools.json#/luck/starter_gu_ids<br>data/schools.json#/qi/starter_gu_ids（另省略 257 条）

## 玩家后果

- `aptitude_capacity`：No aptitude-derived capacity or recovery rule is authorized.
- `body_and_blood`：No new body, bloodline, or injury rule is authorized.
- `cultivator_aperture`：No aperture rule change is authorized by Stage 0.
- `dao_marks`：If approved later, players will not receive unsupported universal dao-mark experience for routine actions.
- `economy_and_primeval_stones`：If verified later, players can buy ordinary goods but must use relationships, knowledge, or risk for non-fungible assets.
- `force_and_social_order`：If verified later, coercion and status choices leave visible future protection, hostility, or pursuit consequences.
- `gu_activation`：No activation-cost or fallback change is authorized.
- `gu_feeding`：If verified later, upkeep choices expose specific food, timing, and failure consequences.
- `gu_is_independent_entity`：If verified later, ownership, transfer, feeding, and loss remain attached to individual Gu.
- `gu_is_life`：If verified later, players must treat Gu as maintained living entities rather than disposable skill tokens.
- `gu_ownership`：No ownership or transfer behavior changes are authorized.
- `gu_recipe`：No recipe unlock or execution rule change is authorized.
- `gu_refinement`：If verified later, players can distinguish knowledge-backed refinement from explicitly risky experimentation.
- `information_leak`：No leak, secrecy, or enemy-learning mechanic is authorized yet.
- `inheritance`：No inheritance reward or access rule change is authorized.
- `kill_move`：If verified later, players must acquire, prepare, and expose a combination instead of pressing an unexplained universal action.
- `lifespan`：If verified later, lifespan spending is exceptional, previewed, and irreversible rather than routine shopping currency.
- `mortal_immortal_boundary`：No ascension boundary or immortal-stage production behavior is authorized.
- `natal_gu`：If later approved, players will not choose a consequence-free core slot detached from cultivation history.
- `primeval_essence`：If verified later, players see combat cost as a view of one world resource rather than two unrelated currencies.
- `rank_and_subrank`：No new rank gate, multiplier, or promotion rule is authorized.
- `soul`：No soul-derived action-point or capacity rule is authorized.
- `tribulation_or_ascension`：No tribulation, ascension, or boss-gate production rule is authorized.
- `world_scope_and_compression`：Players receive a finite run structure without being told that compressed layers are literal world geography or universal law.

## 迁移/废止说明

- `aptitude_capacity`：Defer production work and record the verified scope before proposing a model. Do not promote current aptitude fields into world truth.
- `body_and_blood`：Defer production work pending source verification. Do not infer rules from current data labels.
- `cultivator_aperture`：Defer production work and collect exact P0 support, conditions, and counter-evidence. Keep current behavior unchanged while evidence is unresolved.
- `dao_marks`：Mark generalized mortal dao-mark progression for deprecation; do not delete fields or migrate saves in Stage 0. Exact P0 exceptions must be preserved before any later removal.
- `economy_and_primeval_stones`：Keep promotion economy audit-only and defer any pricing or inventory migration. Do not change shops, prices, materials, or saves in Stage 0.
- `force_and_social_order`：Audit existing NPC and faction outcomes only; defer production changes. One-off current outcomes do not prove the proposed model.
- `gu_activation`：Defer production work and verify support plus exceptions. Do not treat role fallbacks as source facts.
- `gu_feeding`：Audit feeding fields only; defer any data or runtime migration. Promotion materials remain deferred.
- `gu_is_independent_entity`：Audit instance identity only; make no production change before P0 verification. Do not infer independence from existing instance fields.
- `gu_is_life`：Audit current lifecycle behavior only; make no production change before P0 verification. Existing implementation is not evidence for retention.
- `gu_ownership`：Defer and gather P0 support, conditions, and counterexamples. Current inventory representation is observation only.
- `gu_recipe`：Defer and verify source-backed knowledge and execution boundaries. Current recipe data cannot prove the world rule.
- `gu_refinement`：Audit current refinement paths; defer production redesign and migration. Do not modify recipes, materials, or success logic in Stage 0.
- `information_leak`：Defer until exact support, conditions, and representative cases are recorded. Do not infer a mechanic from design prose alone.
- `inheritance`：Defer and verify P0 support and exceptions. Current reward rooms are not authoritative.
- `kill_move`：Audit existing kill-move surfaces only; defer production redesign. Do not modify combat runtime in Stage 0.
- `lifespan`：Audit lifespan payment surfaces only; defer runtime and economy migration. No production price or cost changes in Stage 0.
- `mortal_immortal_boundary`：Defer until exact P0 evidence and conditions are complete. Do not approximate the boundary from rank fields.
- `natal_gu`：Deprecate the arbitrary-slot hypothesis in future design; preserve current saves and runtime until a separately approved migration exists. No production field or save migration occurs in Stage 0.
- `primeval_essence`：Audit dual-resource semantics only; defer any migration until evidence and a later slice are approved. Do not alter essence or true-qi runtime state in Stage 0.
- `rank_and_subrank`：Collect exact support and exceptions before adjudicating progression semantics. F1 and Q8-G remain audit-only.
- `soul`：Defer and collect exact P0 support, conditions, and counterexamples. Current soul fields are implementation observations only.
- `tribulation_or_ascension`：Defer until exact P0 evidence and a later-stage design are approved. Do not equate current boss gates with ascension.
- `world_scope_and_compression`：Retain as an audit hypothesis only; defer production authorization until source boundaries are verified. Five-layer structure is not source evidence.

Legacy dispositions:

- `f1_pity` → `audit_only`：F1 Pity is historical implementation context and cannot authorize Stage 0 production behavior.
- `promotion_economy` → `defer`：Promotion economy remains deferred until source evidence and the later economy slice are adjudicated.
- `promotion_materials` → `defer`：Promotion materials remain deferred until source evidence and the later refinement slice are adjudicated.
- `q8g_promotion_chain` → `audit_only`：Q8-G is retained only as an audit trail and is not a production-ready world rule.
- `school_promotion` → `defer`：School promotion remains deferred while school-as-class semantics are under review.

## Stage 0 Gate

- 结果：**GO**
- Claims：24（high impact: 24）
- 未解决高影响项：0
- Blockers：—
- 生产改动授权：否。Stage 0 未通过前不得将候选裁定写入运行时代码或数据。
