-- 计桓范·献策
-- 出牌阶段限一次，你可以选择一名角色，交给其一张牌作为谋策。
-- 持有谋策的角色回合内，可以将这张谋策当作任意一张普通锦囊使用；
-- 若其回合内没有使用这张谋策，回合结束时，你收回此牌并摸X张牌。（X为该角色本回合使用牌的数量）
local j_xiance = fk.CreateSkill {
  name = "j_xiance",
}

-- 持有者的子技能：将“谋策”当作普通锦囊使用（授予/收回由标记同步管理）
local j_xiance_holder = fk.CreateSkill {
  name = "j_xiance_holder",
}

Fk:loadTranslationTable{
  ["j_xiance"] = "献策",
  [":j_xiance"] = "出牌阶段限一次，你可以选择一名角色，交给其一张牌作为“谋策”。持有“谋策”的角色回合内，可以将这张“谋策”当作任意一张普通锦囊牌使用；若其回合内没有使用这张“谋策”，回合结束时，你收回此牌并摸X张牌（X为该角色本回合使用牌的数量）。",

  ["j_xiance_holder"] = "谋策",
  [":j_xiance_holder"] = "你可以将“谋策”当作一张本局已加入游戏的普通锦囊牌使用。",

  ["#j_xiance"] = "献策：选择一名角色，交给其一张手牌作为“谋策”",
  ["#j_xiance_holder"] = "谋策：将“谋策”当作一张普通锦囊牌使用",
  ["@@j_xiance_mouli"] = "谋策",
}

local function hasMouli(p)
  for _, cid in ipairs(p:getCardIds("h")) do
    if Fk:getCardById(cid):getMark("@@j_xiance_mouli") > 0 then return true end
  end
  return false
end

-- 同步授予/收回持有者子技能：手牌中有“谋策”→授予，没有→收回
local function syncHolderGrants(room)
  for _, p in ipairs(room.players) do
    local has = hasMouli(p)
    local granted = p:getMark("j_xiance_granted")
    if has and granted == 0 then
      room:handleAddLoseSkills(p, "j_xiance_holder", nil, false, true)
      room:setPlayerMark(p, "j_xiance_granted", 1)
    elseif not has and granted == 1 then
      room:handleAddLoseSkills(p, "-j_xiance_holder", nil, false, true)
      room:setPlayerMark(p, "j_xiance_granted", 0)
    end
  end
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

-- 出牌阶段限一次：选一名角色，交给其一张手牌作为“谋策”
j_xiance:addEffect("active", {
  anim_type = "control",
  prompt = "#j_xiance",
  min_card_num = 1,
  max_card_num = 1,
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    return player:usedSkillTimes(j_xiance.name, Player.HistoryPhase) == 0
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
    -- 标记为谋策（先标记再交付，交付时仍带标记）
    room:setCardMark(Fk:getCardById(cardId), "@@j_xiance_mouli", 1)
    if target ~= player then
      room:moveCardTo(cardId, Card.PlayerHand, target, fk.ReasonGive, j_xiance.name, nil, true, player)
    end
    syncHolderGrants(room)
  end,
})

-- 牌进出角色手牌区时同步授予/收回持有者子技能
j_xiance:addEffect(fk.AfterCardsMove, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xiance.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if move.fromArea == Card.PlayerHand or move.toArea == Card.PlayerHand then
        return true
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    syncHolderGrants(player.room)
  end,
})

-- 持有者回合内可将“谋策”当作普通锦囊使用
j_xiance_holder:addEffect("active", {
  anim_type = "control",
  prompt = "#j_xiance_holder",
  min_card_num = 1,
  max_card_num = 1,
  target_num = 0,
  can_use = function(self, player)
    -- 仅持有者回合内（出牌阶段）可用
    return player.phase == Player.Play and #player:getCardIds("h") > 0
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and table.contains(player:getCardIds("h"), to_select)
      and Fk:getCardById(to_select):getMark("@@j_xiance_mouli") > 0
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_cards == 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local cardId = effect.cards and effect.cards[1]
    if not cardId then return end
    -- 当作本局已加入游戏的普通锦囊使用（namebox 只列出当前有合法目标的）
    local use = room:askToUseVirtualCard(player, {
      name = inGameCommonTricks(room),
      skill_name = j_xiance_holder.name,
      subcards = { cardId },
      cancelable = true,
      prompt = "#j_xiance_holder",
    })
    if use then
      -- 使用后不再是“谋策”
      room:setCardMark(Fk:getCardById(cardId), "@@j_xiance_mouli", 0)
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
    if not target or target.dead then return false end
    return hasMouli(target)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- X = 该角色本回合使用牌的数量
    local x = 0
    for _, times in pairs(target.cardUsedHistory) do
      x = x + (times[Player.HistoryTurn] or 0)
    end
    local mouliIds = table.filter(target:getCardIds("h"), function(cid)
      return Fk:getCardById(cid):getMark("@@j_xiance_mouli") > 0
    end)
    for _, cid in ipairs(mouliIds) do
      -- 收回（移动时仍带谋策标记，可供矫出响应）
      room:moveCardTo(cid, Card.PlayerHand, player, fk.ReasonGive, j_xiance.name, nil, true, target)
      -- 收回后不再是谋策
      room:setCardMark(Fk:getCardById(cid), "@@j_xiance_mouli", 0)
    end
    syncHolderGrants(room)
    if x > 0 then
      room:drawCards(player, x, j_xiance.name)
    end
  end,
})

-- 测试：献策交付 → 目标获得带谋策标记的牌并获得持有者技能
j_xiance:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiance.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_xiance.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")
    spec:on_use(room, { from = me, tos = { comp2 }, cards = { c1.id } })

    lu.assertTrue(table.contains(comp2:getCardIds("h"), c1.id), "目标应获得谋策牌")
    lu.assertTrue(Fk:getCardById(c1.id):getMark("@@j_xiance_mouli") > 0, "该牌应带谋策标记")
    lu.assertTrue(comp2:hasSkill("j_xiance_holder"), "持有者应获得谋策使用技能")
  end)
end)

-- 测试：持有者回合结束未使用 → 收回、清标记、桓范摸X（X=其本回合用牌数）
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
    -- 标记并交付
    room:setCardMark(Fk:getCardById(c1.id), "@@j_xiance_mouli", 1)
    room:moveCardTo(c1.id, Card.PlayerHand, comp2, fk.ReasonGive, j_xiance.name, nil, true, me)
  end)
  FkTest.runInRoom(function()
    -- 目标本回合使用了 2 张牌
    comp2:addCardUseHistory("slash", 2)
    local myHand = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, comp2, {})

    lu.assertTrue(table.contains(me:getCardIds("h"), c1.id), "未使用的谋策应被收回")
    lu.assertTrue(Fk:getCardById(c1.id):getMark("@@j_xiance_mouli") == 0, "收回后应不再是谋策")
    lu.assertEquals(#me:getCardIds("h"), myHand + 1 + 2, "收回1张并摸X(=2)张")
    lu.assertFalse(comp2:hasSkill("j_xiance_holder"), "失去谋策后应收回持有者技能")
  end)
end)

-- 测试：持有者使用谋策后（离开手牌）回合结束不再收回
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
    room:moveCardTo(c1.id, Card.PlayerHand, comp2, fk.ReasonGive, j_xiance.name, nil, true, me)
    -- 模拟其回合内当作锦囊使用：离开手牌并清标记
    room:moveCardTo(c1.id, Card.DiscardPile, nil, fk.ReasonUse, j_xiance_holder.name)
    room:setCardMark(Fk:getCardById(c1.id), "@@j_xiance_mouli", 0)
  end)
  FkTest.runInRoom(function()
    local myHand = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(#me:getCardIds("h"), myHand, "已使用的谋策回合结束不应收回")
  end)
end)

return j_xiance
