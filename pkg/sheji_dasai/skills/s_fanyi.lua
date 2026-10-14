-- 轲比能一号 · 藩异（s_fanyi）
-- 出牌阶段限一次，你可以展示全部手牌，若：
-- 没有花色相同的牌，你可以视为使用一张无距离次数限制的【杀】，然后摸一张牌并令此技能视为未发动过；
-- 有花色相同的牌，你可以弃置所有手牌并获得相同数量的【杀】；
-- 没有手牌，你可以展示牌堆顶的五张牌，获得其中一种颜色的牌。
local s_fanyi = fk.CreateSkill {
  name = "s_fanyi",
}

Fk:loadTranslationTable {
  ["s_fanyi"] = "藩异",
  [":s_fanyi"] = "出牌阶段限一次，你可以展示全部手牌，若：没有花色相同的牌，你可以视为使用一张无距离次数限制的【杀】，然后摸一张牌并令此技能视为未发动过；有花色相同的牌，你可以弃置所有手牌并获得相同数量的【杀】；没有手牌，你可以展示牌堆顶的五张牌，获得其中一种颜色的牌。",
  ["#s_fanyi-color"] = "藩异：选择获得牌的颜色",
  ["s_fanyi_red"] = "红色牌",
  ["s_fanyi_black"] = "黑色牌",
  ["#s_fanyi-slash"] = "藩异：视为使用一张【杀】，选择目标",
  ["$s_fanyi1"] = "鲜卑诸部，各怀异志！",
  ["$s_fanyi2"] = "藩属之间，离而复合！",
}

local function getSlashCards(room, n)
  -- 从牌堆顶翻取，收集 n 张【杀】，其余放回牌堆
  local gained = {}
  local rest = {}
  local pile = room:getNCards(4 * n + 8)
  for _, id in ipairs(pile) do
    if Fk:getCardById(id).trueName == "slash" and #gained < n then
      table.insert(gained, id)
    else
      table.insert(rest, id)
    end
  end
  if #rest > 0 then
    room:moveCards{ ids = rest, toArea = Card.DrawPile, moveReason = fk.ReasonPut }
  end
  return gained
end

s_fanyi:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    return player:usedSkillTimes(s_fanyi.name, Player.HistoryTurn) == 0 and
      player.phase == Player.Play
  end,
  on_cost = function(self, player, data, extra_data)
    local room = player.room
    if #player:getCardIds("h") == 0 then
      -- 没有手牌：展示牌堆顶5张，选一种颜色，未选牌放回牌堆
      local pile = room:getNCards(5)
      if #pile == 0 then return end
      room:showCards(pile, player, s_fanyi.name)
      local choice = room:askToChoice(player, {
        choices = { "s_fanyi_red", "s_fanyi_black" },
        skill_name = s_fanyi.name,
        prompt = "#s_fanyi-color",
      })
      local ids, rest = {}, {}
      for _, id in ipairs(pile) do
        local c = Fk:getCardById(id)
        if (choice == "s_fanyi_red" and c.color == Card.Red) or
          (choice == "s_fanyi_black" and c.color == Card.Black) then
          table.insert(ids, id)
        else
          table.insert(rest, id)
        end
      end
      if #rest > 0 then
        room:moveCards{ ids = rest, toArea = Card.DrawPile, moveReason = fk.ReasonPut }
      end
      return { mode = "empty", cards = ids }
    end
    -- 有手牌：展示全部手牌
    local hand = player:getCardIds("h")
    room:showCards(hand, player, s_fanyi.name)
    -- 判断花色是否互不相同
    local suits = {}
    for _, id in ipairs(hand) do
      suits[Fk:getCardById(id).suit] = true
    end
    local suitNum = 0
    for _ in pairs(suits) do suitNum = suitNum + 1 end
    local noSame = suitNum == #hand
    if noSame then
      -- 视为使用一张无距离次数限制的【杀】
      local tos = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = 1,
        targets = room.alive_players,
        skill_name = s_fanyi.name,
        prompt = "#s_fanyi-slash",
        cancelable = false,
      })
      if #tos == 0 then return end
      return { mode = "slash", tos = tos }
    else
      -- 弃置所有手牌并获得等量【杀】
      local ids = getSlashCards(room, #hand)
      return { mode = "convert", cards = ids }
    end
  end,
  on_use = function(self, room, skillUseEvent)
    local player = skillUseEvent.from
    local cost = skillUseEvent.cost_data
    if cost.mode == "slash" then
      local slash = Fk:cloneCard("slash")
      room:useCard{ from = player, tos = cost.tos, card = slash, extraUse = true }
      player:drawCards(1, s_fanyi.name)
      -- 令此技能视为未发动过
      player:setSkillUseHistory(s_fanyi.name, 0, Player.HistoryTurn)
      room:notifySkillInvoked(player, s_fanyi.name, "offensive")
      player:broadcastSkillInvoke(s_fanyi.name)
    elseif cost.mode == "convert" then
      -- 弃置所有手牌
      local hand = player:getCardIds("h")
      if #hand > 0 then
        room:throwCard(hand, fk.ReasonDiscard, s_fanyi.name, player, player)
      end
      if #cost.cards > 0 then
        room:obtainCard(player, cost.cards, true, fk.ReasonPrey, player, s_fanyi.name)
      end
      room:notifySkillInvoked(player, s_fanyi.name, "offensive")
      player:broadcastSkillInvoke(s_fanyi.name)
    else
      -- empty：获得所选颜色的牌
      local gained = cost.cards
      if #gained > 0 then
        player.room:obtainCard(player, gained, true, fk.ReasonPrey, player, s_fanyi.name)
      end
      player.room:notifySkillInvoked(player, s_fanyi.name, "offensive")
      player:broadcastSkillInvoke(s_fanyi.name)
    end
  end,
})

-- 测试1：手牌花色互不相同 → 视为使用杀（选目标）+ 摸1 + 技能重置
s_fanyi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_fanyi.name)
    me.maxHp = 5
    me.hp = 3
    comp2.maxHp = 4
    comp2.hp = 4
    room.current = me
    me.phase = Player.Play
    local h1 = room:printCard("slash", Card.Spade, 3)
    local h2 = room:printCard("peach", Card.Heart, 4)
    room:obtainCard(me, { h1, h2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local sk = Fk.skills[s_fanyi.name]
    local hBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { FkTest.ReplyChoosePlayer({ comp2 }) })
    local cost = sk:onCost(me, {}, nil)
    lu.assertEquals(cost.mode, "slash", "藩异：花色互不相同应选择视为使用杀")
    FkTest.setNextReplies(comp2, { "0" })
    sk:onUse(room, { from = me, tos = {}, cards = {}, cost_data = cost })
    -- 视为使用的杀为虚拟牌（不消耗手牌），摸1张 → 手牌 2+1=3
    lu.assertEquals(#me:getCardIds("h"), hBefore + 1, "藩异：视为使用杀后应摸1张牌")
    -- 技能重置：可再次发动
    lu.assertEquals(me:usedSkillTimes(s_fanyi.name, Player.HistoryTurn), 0, "藩异：应视为未发动过")
  end)
end)

-- 测试2：有相同花色 → 弃置所有手牌并获得等量杀
s_fanyi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_fanyi.name)
    me.maxHp = 5
    me.hp = 3
    comp2.maxHp = 4
    comp2.hp = 4
    room.current = me
    me.phase = Player.Play
    local h1 = room:printCard("slash", Card.Spade, 3)
    local h2 = room:printCard("peach", Card.Spade, 4)
    room:obtainCard(me, { h1, h2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local sk = Fk.skills[s_fanyi.name]
    local cost = sk:onCost(me, {}, nil)
    lu.assertEquals(cost.mode, "convert", "藩异：有相同花色应选择弃牌换杀")
    sk:onUse(room, { from = me, tos = {}, cards = {}, cost_data = cost })
    -- 弃置2张 → 获得2张杀
    local hands = me:getCardIds("h")
    lu.assertEquals(#hands, 2, "藩异：应弃置所有手牌并获得等量杀（2张）")
    local slashCount = 0
    for _, id in ipairs(hands) do
      if Fk:getCardById(id).trueName == "slash" then slashCount = slashCount + 1 end
    end
    lu.assertEquals(slashCount, 2, "藩异：获得的牌应均为杀")
  end)
end)

-- 测试3：无手牌 → 展示牌堆顶5张，获得一种颜色的牌
s_fanyi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_fanyi.name)
    me.maxHp = 5
    me.hp = 3
    comp2.maxHp = 4
    comp2.hp = 4
    room.current = me
    me.phase = Player.Play
    local hands = me:getCardIds("h")
    if #hands > 0 then room:throwCard(hands, fk.ReasonDiscard, "test", me, me) end
    -- 预置两张红牌到牌堆顶，保证翻出的5张中有红色牌
    local r1 = room:printCard("peach", Card.Heart, 4)
    local r2 = room:printCard("duel", Card.Diamond, 5)
    room:moveCards{ ids = { r1, r2 }, toArea = Card.DrawPile, moveReason = fk.ReasonPut }
  end)
  FkTest.runInRoom(function()
    local sk = Fk.skills[s_fanyi.name]
    lu.assertEquals(#me:getCardIds("h"), 0, "前置：应无手牌")
    FkTest.setNextReplies(me, { "s_fanyi_red" })
    local cost = sk:onCost(me, {}, nil)
    lu.assertEquals(cost.mode, "empty", "藩异：无手牌应选择翻牌堆")
    sk:onUse(room, { from = me, tos = {}, cards = {}, cost_data = cost })
    -- 获得红色牌
    local hands = me:getCardIds("h")
    lu.assertTrue(#hands >= 1, "藩异：应获得所选颜色的牌")
    for _, id in ipairs(hands) do
      lu.assertEquals(Fk:getCardById(id).color, Card.Red, "藩异：获得的牌应为红色")
    end
  end)
end)

return s_fanyi