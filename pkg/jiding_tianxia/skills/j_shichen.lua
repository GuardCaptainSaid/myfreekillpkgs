-- 计杨修·识谶
-- 出牌阶段限一次，你可以观看一名角色的手牌，选择其中一张牌标记为“谶”。
-- 本轮内，你可以弃置一张与“谶”花色相同的手牌，视为使用该“谶”牌；
-- 若你一回合未以此法发动转化，回合结束时你摸一张牌（每名角色回合限一次）。
-- 当标记为“谶”的牌进入弃牌堆时，你视为使用该“谶”牌；若你无法使用此牌，则改为摸两张牌。
local j_shichen = fk.CreateSkill {
  name = "j_shichen",
}

Fk:loadTranslationTable{
  ["j_shichen"] = "识谶",
  [":j_shichen"] = "出牌阶段限一次，你可以观看一名角色的手牌，选择其中一张牌标记为“谶”。本轮内，你可以弃置一张与“谶”花色相同的手牌，视为使用该“谶”牌；若你一回合未以此法发动转化，回合结束时你摸一张牌（每名角色回合限一次）。当标记为“谶”的牌进入弃牌堆时，你视为使用该“谶”牌；若你无法使用此牌，则改为摸两张牌。",

  ["#j_shichen"] = "识谶：观看一名角色的手牌，标记其中一张为“谶”",
  ["#j_shichen-mark"] = "识谶：请选择其中一张牌标记为“谶”",
  ["#j_shichen-invoke"] = "识谶：是否弃置一张与“谶”花色相同的手牌，视为使用“谶”？",
  ["#j_shichen-discard"] = "识谶：请弃置一张与“谶”花色相同的手牌",
  ["#j_shichen-use"] = "识谶：视为使用“谶”（若无法使用则改为摸两张牌）",
  ["j_shichen_cand"] = "手牌",
  ["@@j_shichen_chen"] = "谶",
}

-- 查找当前带“谶”标记的牌（全场各区域）
local function findChenCard(room)
  local function try(ids)
    for _, id in ipairs(ids) do
      local c = Fk:getCardById(id)
      if c and c:getMark("@@j_shichen_chen") > 0 then return c end
    end
  end
  local c = try(room.draw_pile) or try(room.discard_pile) or try(room.processing_area)
  if c then return c end
  for _, p in ipairs(room.players) do
    c = try(p:getCardIds("hej"))
    if c then return c end
  end
  return nil
end

-- 出牌阶段限一次：观看一名角色的手牌，标记其中一张为“谶”
j_shichen:addEffect("active", {
  anim_type = "control",
  prompt = "#j_shichen",
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    return player:usedSkillTimes(j_shichen.name, Player.HistoryPhase) == 0
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player and not to_select.dead
      and #to_select:getCardIds("h") > 0
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_targets == 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if not target or target.dead then return end
    room:showCards(target:getCardIds("h"), player, j_shichen.name)
    local pick = room:askToChooseCard(player, {
      target = target,
      flag = "h",
      skill_name = j_shichen.name,
      prompt = "#j_shichen-mark",
    })
    if not pick or pick <= 0 then return end
    room:setCardMark(Fk:getCardById(pick), "@@j_shichen_chen", 1)
  end,
})

-- 本轮内（每回合开始时询问）：弃置一张与“谶”花色相同的手牌，视为使用该“谶”牌
j_shichen:addEffect(fk.TurnStart, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_shichen.name) or player.dead then return false end
    -- 每名角色回合限一次
    if player:getMark("j_shichen_conv-turn") > 0 then return false end
    local chen = findChenCard(player.room)
    if not chen then return false end
    for _, cid in ipairs(player:getCardIds("h")) do
      if Fk:getCardById(cid).suit == chen.suit then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_shichen.name,
      prompt = "#j_shichen-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local chen = findChenCard(room)
    if not chen then return end
    local candidates = table.filter(player:getCardIds("h"), function(cid)
      return Fk:getCardById(cid).suit == chen.suit
    end)
    if #candidates == 0 then return end
    local pick = room:askToChooseCards(player, {
      target = player,
      flag = { card_data = { { "j_shichen_cand", candidates } } },
      min = 1,
      max = 1,
      cancelable = true,
      skill_name = j_shichen.name,
      prompt = "#j_shichen-discard",
    })
    if not pick or #pick == 0 then return end
    -- 弃置的手牌作为转化牌的副牌，使用后进入弃牌堆（同“典律”的处理）
    local use = room:askToUseVirtualCard(player, {
      name = chen.trueName,
      subcards = { pick[1] },
      skill_name = j_shichen.name,
      cancelable = true,
      prompt = "#j_shichen-use",
    })
    if use then
      room:setPlayerMark(player, "j_shichen_conv-turn", 1)
    end
  end,
})

-- 若你一回合未以此法发动转化，回合结束时你摸一张牌（自动执行）
j_shichen:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "drawcard",
  -- 技能文本无“可以”，自动执行
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_shichen.name) or player.dead then return false end
    if player:getMark("j_shichen_conv-turn") > 0 then return false end
    return findChenCard(player.room) ~= nil
  end,
  on_use = function(self, event, target, player, data)
    player.room:drawCards(player, 1, j_shichen.name)
  end,
})

-- 当标记为“谶”的牌进入弃牌堆时：视为使用该“谶”牌；无法使用则改为摸两张牌
j_shichen:addEffect(fk.AfterCardsMove, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_shichen.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local c = Fk:getCardById(info.cardId)
          if c and c:getMark("@@j_shichen_chen") > 0 then return true end
        end
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local c = Fk:getCardById(info.cardId)
          if c and c:getMark("@@j_shichen_chen") > 0 then
            -- “谶”已被消耗，先清除标记（防止再次进入弃牌堆时重复触发）
            room:setCardMark(c, "@@j_shichen_chen", 0)
            local use = room:askToUseVirtualCard(player, {
              name = c.trueName,
              skill_name = j_shichen.name,
              cancelable = true,
              prompt = "#j_shichen-use",
            })
            if not use and not player.dead then
              room:drawCards(player, 2, j_shichen.name)
            end
          end
        end
      end
    end
  end,
})

-- 新的一轮开始时，清除上一轮遗留的“谶”标记
j_shichen:addEffect(fk.RoundStart, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_shichen.name) and not player.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local c = findChenCard(room)
    if c then
      room:setCardMark(c, "@@j_shichen_chen", 0)
    end
  end,
})

-- 测试：出牌阶段标记“谶” → 手牌中的牌获得标记
j_shichen:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shichen.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)
    c2 = room:printCard("jink", Card.Heart, 8)
    room:obtainCard(comp2, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local origChooseCard = room.askToChooseCard
    room.askToChooseCard = function(self, who, params)
      if who == me and params.target == comp2 then return c1.id end
      return origChooseCard(self, who, params)
    end
    local skel = Fk.skills[j_shichen.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")
    spec:on_use(room, { from = me, tos = { comp2 }, cards = {} })
    room.askToChooseCard = origChooseCard

    lu.assertTrue(Fk:getCardById(c1.id):getMark("@@j_shichen_chen") > 0, "所选牌应带“谶”标记")
    lu.assertEquals(Fk:getCardById(c2.id):getMark("@@j_shichen_chen"), 0, "未选牌不应带标记")
  end)
end)

-- 测试：回合开始转化（弃同花色手牌视为使用“谶”）→ 回合结束不摸牌
j_shichen:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shichen.name)
    room.current = comp2
    comp2.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)   -- 谶：黑桃
    c2 = room:printCard("slash", Card.Spade, 9)   -- 同花色手牌
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(me, { c2 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_shichen_chen", 1)
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChooseCards = room.askToChooseCards
    local origUseVirtual = room.askToUseVirtualCard
    room.askToSkillInvoke = function(self, who, params)
      if who == me then return true end
      return origInvoke(self, who, params)
    end
    room.askToChooseCards = function(self, who, params)
      if who == me then return { c2.id } end
      return origChooseCards(self, who, params)
    end
    local usedNames = {}
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then
        table.insert(usedNames, type(params.name) == "table" and params.name[1] or params.name)
        return true
      end
      return origUseVirtual(self, who, params)
    end

    room.logic:trigger(fk.TurnStart, comp2, {})
    room.logic:trigger(fk.TurnEnd, comp2, {})

    room.askToSkillInvoke = origInvoke
    room.askToChooseCards = origChooseCards
    room.askToUseVirtualCard = origUseVirtual

    lu.assertTrue(table.contains(usedNames, "slash"), "应视为使用“谶”（杀）")
    lu.assertFalse(table.contains(me:getCardIds("h"), c2.id), "同花色手牌应被弃置")
    lu.assertTrue(me:getMark("j_shichen_conv-turn") > 0, "应记录本回合已转化")
  end)
end)

-- 测试：一回合未转化 → 回合结束摸一张牌
j_shichen:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shichen.name)
    room.current = comp2
    comp2.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_shichen_chen", 1)
  end)
  FkTest.runInRoom(function()
    local hand = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(#me:getCardIds("h"), hand + 1, "未转化应于回合结束摸一张牌")
  end)
end)

-- 测试：“谶”进入弃牌堆 → 视为使用；无法使用则摸两张牌
j_shichen:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shichen.name)
    room.current = comp2
    comp2.phase = Player.Play
    c1 = room:printCard("ex_nihilo", Card.Spade, 7)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_shichen_chen", 1)
  end)
  FkTest.runInRoom(function()
    -- 情形1：可以使用 → 视为使用，不摸牌
    local origUseVirtual = room.askToUseVirtualCard
    local used = false
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then used = true return true end
      return origUseVirtual(self, who, params)
    end
    local hand = #me:getCardIds("h")
    room:throwCard(c1.id, "test", comp2, comp2)
    room.askToUseVirtualCard = origUseVirtual
    lu.assertTrue(used, "“谶”进入弃牌堆应触发视为使用")
    lu.assertEquals(#me:getCardIds("h"), hand, "成功使用不应摸牌")
    lu.assertEquals(Fk:getCardById(c1.id):getMark("@@j_shichen_chen"), 0, "使用后“谶”标记应清除")

    -- 情形2：无法使用 → 摸两张牌
    local c2 = room:printCard("jink", Card.Heart, 8)
    room:obtainCard(comp2, { c2 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c2, "@@j_shichen_chen", 1)
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then return nil end  -- 无法使用
      return origUseVirtual(self, who, params)
    end
    hand = #me:getCardIds("h")
    room:throwCard(c2.id, "test", comp2, comp2)
    room.askToUseVirtualCard = origUseVirtual
    lu.assertEquals(#me:getCardIds("h"), hand + 2, "无法使用“谶”应改为摸两张牌")
  end)
end)

return j_shichen
