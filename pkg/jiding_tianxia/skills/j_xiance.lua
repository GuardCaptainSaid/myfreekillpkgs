-- 计桓范·献策
-- 出牌阶段限一次，你可以选择一名角色，交给其一张牌作为谋策。
-- 持有谋策的角色回合内，可以将这张谋策当作任意一张普通锦囊使用；
-- 若其回合内没有使用这张谋策，回合结束时，你收回此牌并摸X张牌。（X为该角色本回合使用牌的数量）
--
-- 【实现说明】（重要，勿改回旧写法）
-- 谋策的“印牌”必须走转化技(viewas)，且与同包【间智】保持同一套已验证写法：
--   1) 客户端可见的“手中谋策牌 id”与“可作为的锦囊牌名”都写进【玩家表标记】，
--      不在客户端读牌堆、也不靠牌标记做选牌判定（客户端判定不可靠）；
--   2) 牌名选择用 UI.CardNameBox 传【原始牌名】，它自带 default=choices[1]，
--      且前端只做显示翻译、回传的仍是原始牌名，不会出现“翻译名与原始名不一致”的死循环；
--   3) 不使用「主动技里再 askToUseVirtualCard」的嵌套写法——那条路在实测中无法真正印出牌。
local j_xiance = fk.CreateSkill {
  name = "j_xiance",
}

-- 持有者的转化子技能 j_xiance_holder 见同目录 j_xiance_holder.lua（必须单独成文件，否则不注册）
local HOLDER = "j_xiance_holder"

Fk:loadTranslationTable{
  ["j_xiance"] = "献策",
  [":j_xiance"] = "出牌阶段限一次，你可以选择一名角色，交给其一张牌作为“谋策”。持有“谋策”的角色回合内，可以将这张“谋策”当作任意一张普通锦囊牌使用；若其回合内没有使用这张“谋策”，回合结束时，你收回此牌并摸X张牌（X为该角色本回合使用牌的数量）。",

  ["#j_xiance"] = "献策：选择一张手牌与一名角色，交给其作为“谋策”",
  ["@@j_xiance_mouli"] = "谋策",
}

local MOULI_MARK = "@@j_xiance_mouli"     -- 牌标记：该牌是“谋策”（带 @ 前缀，牌面可见）
local OWNER_MARK = "j_xiance_owner"       -- 牌标记：谋策的给出者 id
local IDS_MARK = "j_xiance_mouli_ids"     -- 玩家表标记：手中谋策牌 id（客户端选牌用）
local NAMES_MARK = "j_xiance_names"       -- 玩家表标记：可作为的普通锦囊原始牌名（客户端选牌名用）
local GRANTED_MARK = "j_xiance_granted"   -- 玩家标记：是否已授予谋策子技能
local USED_MARK = "j_xiance_used-phase"   -- 玩家标记：本阶段是否已发动献策

local function hasMouliMark(card)
  return card ~= nil and card:getMark(MOULI_MARK) > 0
end

-- 某角色手中带谋策标记的牌（服务端权威判断）
local function mouliIds(p)
  local ids = {}
  for _, cid in ipairs(p:getCardIds("h")) do
    if hasMouliMark(Fk:getCardById(cid)) then
      table.insert(ids, cid)
    end
  end
  return ids
end

-- 某张牌是否为该角色手中的谋策：玩家表标记与牌标记任一成立即算（双保险，避免标记不同步导致印不出牌）
local function isMouliCard(player, cid)
  if not table.contains(player:getCardIds("h"), cid) then return false end
  if table.contains(player:getTableMark(IDS_MARK), cid) then return true end
  return hasMouliMark(Fk:getCardById(cid))
end

-- 只收集“本局已加入游戏”的普通锦囊牌名（项目约定：不可印牌）
local function inGameCommonTricks(room)
  local names = {}
  local function add(ids)
    for _, id in ipairs(ids or {}) do
      local card = Fk:getCardById(id)
      if card and card.trueName and card.trueName ~= ""
        and Fk.all_card_types[card.trueName]
        and card.type == Card.TypeTrick and card.sub_type ~= Card.SubtypeDelayedTrick then
        table.insertIfNeed(names, card.trueName)
      end
    end
  end
  add(room.draw_pile)
  add(room.discard_pile)
  add(room.processing_area)
  for _, p in ipairs(room.players) do
    add(p:getCardIds("hej"))
  end
  return names
end

local function tableEq(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

local function setTableMarkIfChanged(room, player, mark, value)
  if not tableEq(player:getTableMark(mark), value or {}) then
    room:setPlayerMark(player, mark, value or {})
  end
end

-- 同步“手中谋策牌 id”与“可转化牌名”，并按需授予/收回谋策子技能
local function syncHolderGrants(room)
  for _, p in ipairs(room.players) do
    local ids = p.dead and {} or mouliIds(p)
    local has = #ids > 0
    local granted = p:getMark(GRANTED_MARK) > 0

    setTableMarkIfChanged(room, p, IDS_MARK, ids)

    if has and not granted then
      room:setPlayerMark(p, NAMES_MARK, inGameCommonTricks(room))
      room:handleAddLoseSkills(p, HOLDER, nil, false, true)
      room:setPlayerMark(p, GRANTED_MARK, 1)
    elseif (not has) and granted then
      room:handleAddLoseSkills(p, "-" .. HOLDER, nil, false, true)
      room:setPlayerMark(p, GRANTED_MARK, 0)
      room:setPlayerMark(p, NAMES_MARK, {})
    elseif has and granted then
      -- 牌名候选随本局牌堆变化刷新（仅在变化时广播，避免每次移牌都刷屏）
      setTableMarkIfChanged(room, p, NAMES_MARK, inGameCommonTricks(room))
    end
  end
end

-- 出牌阶段限一次：选一名角色，交给其一张手牌作为“谋策”
j_xiance:addEffect("active", {
  anim_type = "control",
  prompt = "#j_xiance",
  min_card_num = 1,
  max_card_num = 1,
  target_num = 1,
  -- 限一次用自己写入的 -phase 标记（阶段结束由引擎自动清零），不依赖技能历史同步
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:getMark(USED_MARK) > 0 then return false end
    return #player:getCardIds("h") > 0
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and table.contains(player:getCardIds("h"), to_select)
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    return #selected == 0 and not to_select.dead and #selected_cards > 0
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_targets == 1 and #selected_cards == 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local cardId = effect.cards and effect.cards[1]
    if not target or target.dead or not cardId then return end
    room:setPlayerMark(player, USED_MARK, 1)
    -- 先打标记再交付，交付后牌仍带标记
    local card = Fk:getCardById(cardId)
    if not card then return end
    room:setCardMark(card, MOULI_MARK, 1)
    room:setCardMark(card, OWNER_MARK, player.id)
    if target ~= player then
      room:moveCardTo(cardId, Card.PlayerHand, target, fk.ReasonGive, j_xiance.name, nil, true, player)
    end
    syncHolderGrants(room)
  end,
})

-- 谋策子技能的转化实现见 j_xiance_holder.lua

-- 牌进出角色手牌区 / 谋策牌进入弃牌堆时同步
j_xiance:addEffect(fk.AfterCardsMove, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xiance.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if move.fromArea == Card.PlayerHand or move.toArea == Card.PlayerHand
        or move.toArea == Card.DiscardPile then
        return true
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 谋策标记只在牌进入弃牌堆时销毁
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = Fk:getCardById(info.cardId)
          if card and card:getMark(MOULI_MARK) > 0 then
            room:setCardMark(card, MOULI_MARK, 0)
            room:setCardMark(card, OWNER_MARK, 0)
          end
        end
      end
    end
    -- 牌只是进入处理区（正在被使用）时不收回技能，避免使用过程中被剥夺技能
    for _, move in ipairs(data) do
      if move.toArea ~= Card.Processing then
        syncHolderGrants(room)
        break
      end
    end
  end,
})

-- 持有者回合结束时：未使用的“谋策”被收回，桓范摸X张牌（X为该角色本回合使用牌数量）
j_xiance:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "control",
  -- 技能文本无“可以”，自动执行
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xiance.name) or player.dead then return false end
    -- 谋策已在自己手里（已收回）时不再重复收回
    if not target or target.dead or target == player then return false end
    return #mouliIds(target) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- X = 该角色本回合使用牌的数量
    local x = 0
    for _, times in pairs(target.cardUsedHistory) do
      x = x + (times[Player.HistoryTurn] or 0)
    end
    local ids = table.filter(mouliIds(target), function(cid)
      return Fk:getCardById(cid):getMark(OWNER_MARK) == player.id
    end)
    for _, cid in ipairs(ids) do
      -- 收回后标记保留，桓范可继续把它当作普通锦囊使用，直到该牌进入弃牌堆
      room:moveCardTo(cid, Card.PlayerHand, player, fk.ReasonGive, j_xiance.name, nil, true, target)
    end
    syncHolderGrants(room)
    if x > 0 then
      room:drawCards(player, x, j_xiance.name)
    end
  end,
})

-- 测试：献策交付 → 目标获得带谋策标记的牌、谋策子技能与客户端用的表标记
j_xiance:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiance.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    -- 保证场上有可用的普通锦囊牌名（牌堆里放一张无中生有）
    local trick = room:printCard("ex_nihilo", Card.Heart, 5)
    table.insert(room.draw_pile, 1, trick.id)
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_xiance.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")
    lu.assertTrue(spec:can_use(me), "出牌阶段且未发动过应可发动")
    spec:on_use(room, { from = me, tos = { comp2 }, cards = { c1.id } })

    lu.assertTrue(table.contains(comp2:getCardIds("h"), c1.id), "目标应获得谋策牌")
    lu.assertTrue(Fk:getCardById(c1.id):getMark("@@j_xiance_mouli") > 0, "该牌应带谋策标记")
    lu.assertTrue(comp2:hasSkill("j_xiance_holder"), "持有者应获得谋策技能")
    lu.assertTrue(table.contains(comp2:getTableMark("j_xiance_mouli_ids"), c1.id),
      "客户端选牌用的谋策 id 表标记应已同步")
    lu.assertTrue(#comp2:getTableMark("j_xiance_names") > 0, "客户端选牌名用的牌名表标记应已同步")
    lu.assertFalse(spec:can_use(me), "本阶段已发动过，不能再发动")
  end)
end)

-- （谋策本身的选牌/转化单测见 j_xiance_holder.lua，此处只测献策与其联动）

-- 测试：客户端能看到【谋策】按钮与牌名框，且服务端能真正把谋策牌当锦囊用出去
j_xiance:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiance.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    local trick = room:printCard("ex_nihilo", Card.Heart, 5)
    table.insert(room.draw_pile, 1, trick.id)
  end)
  -- 走真实的献策 on_use，把谋策交给自己（桓范收回后自己也能用）
  FkTest.runInRoom(function()
    local spec
    for _, sp in ipairs(Fk.skills[j_xiance.name]:getSkeleton().effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    spec:on_use(room, { from = me, tos = { me }, cards = { c1.id } })
  end)
  FkTest.runInRoom(function()
    lu.assertTrue(me:hasSkill(HOLDER), "交付谋策后应获得谋策技能")
    lu.assertTrue(#me:getTableMark("j_xiance_names") > 0, "服务端应写入候选牌名")
  end)
  -- 客户端视角：按钮可点、牌名框有候选、能生成虚拟牌（这一层此前完全没被验证过）
  FkTest.runInClient(function()
    local vs = Fk.skills[HOLDER]
    lu.assertTrue(Self:hasSkill(HOLDER), "客户端应看到谋策技能")
    lu.assertTrue(vs:enabledAtPlay(Self), "客户端【谋策】按钮应可用")
    local inter = vs.interaction(vs, Self)
    lu.assertNotNil(inter, "客户端应能取到牌名选择框")
    lu.assertEquals(inter.type, "cardname", "应为牌名选择框")
    lu.assertTrue(#inter.choices > 0, "候选牌名不应为空")
    lu.assertTrue(vs:cardFilter(Self, c1.id, {}, {}), "客户端谋策牌应可选中")
    vs.interaction.data = inter.choices[1]
    local card = vs:viewAs(Self, { c1.id })
    lu.assertNotNil(card, "客户端应能生成虚拟锦囊牌")
    lu.assertEquals(card.skillName, HOLDER, "虚拟牌应记谋策技能名")
  end)
  -- 服务端视角：走真实的回复处理，把谋策当【无中生有】用出去
  FkTest.runInRoom(function()
    local hand = #me:getCardIds("h")
    room:handleUseCardReply(me, {
      card = { skill = HOLDER, subcards = { c1.id }, interaction_data = "ex_nihilo" },
      targets = {},
    })
    -- 谋策牌（c1）离手进入处理区/弃牌堆，同时【无中生有】摸两张 → 净 +1
    lu.assertEquals(#me:getCardIds("h"), hand - 1 + 2, "谋策当【无中生有】使用后应摸两张牌")
    lu.assertFalse(table.contains(me:getCardIds("h"), c1.id), "谋策牌应已离开手牌")
  end)
end)

-- 测试：持有者回合结束未使用 → 收回、标记保留（可自己用）、桓范摸X（X=其本回合用牌数）
j_xiance:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, s1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiance.name)
    room.current = comp2
    comp2.phase = Player.Play
    c1 = room:printCard("jink", Card.Heart, 3)
    s1 = room:printCard("slash", Card.Club, 4)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { s1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(Fk:getCardById(c1.id), "@@j_xiance_mouli", 1)
    room:setCardMark(Fk:getCardById(c1.id), "j_xiance_owner", me.id)
    room:moveCardTo(c1.id, Card.PlayerHand, comp2, fk.ReasonGive, j_xiance.name, nil, true, me)
  end)
  FkTest.runInRoom(function()
    comp2:addCardUseHistory("slash", 2)
    local myHand = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, comp2, {})

    lu.assertTrue(table.contains(me:getCardIds("h"), c1.id), "未使用的谋策应被收回")
    lu.assertTrue(Fk:getCardById(c1.id):getMark("@@j_xiance_mouli") > 0, "收回后标记应保留到进入弃牌堆")
    lu.assertEquals(#me:getCardIds("h"), myHand + 1 + 2, "收回1张并摸X(=2)张")
    lu.assertFalse(comp2:hasSkill("j_xiance_holder"), "失去谋策后应收回谋策技能")
    lu.assertTrue(me:hasSkill("j_xiance_holder"), "收回后桓范本人也能使用谋策")
  end)
end)

-- 测试：持有者使用谋策后（进入弃牌堆）标记销毁、回合结束不再收回
j_xiance:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiance.name)
    room.current = comp2
    comp2.phase = Player.Play
    c1 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(Fk:getCardById(c1.id), "@@j_xiance_mouli", 1)
    room:setCardMark(Fk:getCardById(c1.id), "j_xiance_owner", me.id)
    room:moveCardTo(c1.id, Card.PlayerHand, comp2, fk.ReasonGive, j_xiance.name, nil, true, me)
    room:moveCardTo(c1.id, Card.DiscardPile, nil, fk.ReasonUse, HOLDER)
  end)
  FkTest.runInRoom(function()
    lu.assertEquals(Fk:getCardById(c1.id):getMark("@@j_xiance_mouli"), 0, "进入弃牌堆后谋策标记应销毁")
    local myHand = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(#me:getCardIds("h"), myHand, "已使用的谋策回合结束不应收回")
  end)
end)

return j_xiance
