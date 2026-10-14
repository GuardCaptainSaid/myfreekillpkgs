-- 舒邵五号·散粮
-- 你的体力值发生变化后，你可交给一名角色三张不同花色或不同类型的牌，若该角色为当前回合的角色，该角色使用杀的次数+1。
local s_sanliang = fk.CreateSkill {
  name = "s_sanliang",
}

Fk:loadTranslationTable{
  ["s_sanliang"] = "散粮",
  [":s_sanliang"] = "你的体力值发生变化后，你可交给一名角色三张不同花色或不同类型的牌，若该角色为当前回合的角色，该角色使用杀的次数+1。",

  ["#s_sanliang-invoke"] = "散粮：是否交给一名角色三张不同花色或不同类型的牌？",
  ["#s_sanliang-cards"] = "散粮：选择三张不同花色或不同类型的牌",
  ["#s_sanliang-target"] = "散粮：选择一名角色获得这些牌",
  ["@s_sanliang_slash"] = "散粮",

  ["$s_sanliang1"] = "仓廪所积，当济同袍！",
  ["$s_sanliang2"] = "分粮于众，共赴沙场！",
}

-- 体力值发生变化后：给一名角色三张不同花色/类型牌
s_sanliang:addEffect(fk.HpChanged, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    if not player:hasSkill(s_sanliang.name) then return false end
    -- 体力值实际发生变化
    if data.num == 0 then return false end
    return #player:getCardIds("h") >= 3
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, { skill_name = s_sanliang.name, prompt = "#s_sanliang-invoke" }) then
      return false
    end
    -- 选三张不同花色或不同类型的牌（手牌）
    local c = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      min = 3,
      max = 3,
      cancelable = true,
      pattern = ".",
      skill_name = s_sanliang.name,
      prompt = "#s_sanliang-cards",
    })
    if not c or #c ~= 3 then return false end
    local suits, types = {}, {}
    for _, id in ipairs(c) do
      local cd = Fk:getCardById(id)
      suits[cd.suit] = true
      types[cd.type] = true
    end
    -- 三张牌花色全不同 或 类型全不同
    if #suits ~= 3 and #types ~= 3 then return false end
    -- 选一名其他角色
    local tos = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player),
      min_num = 1,
      max_num = 1,
      cancelable = true,
      skill_name = s_sanliang.name,
      prompt = "#s_sanliang-target",
    })
    if not tos or #tos ~= 1 then return false end
    self.costData = { cards = c, to = tos[1] }
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cd = self.costData
    self.costData = nil
    if not cd then return end
    room:obtainCard(cd.to, cd.cards, true, fk.ReasonGive, player, s_sanliang.name)
    -- 若该角色为当前回合的角色，其本回合使用杀次数+1
    if cd.to == room.current and not cd.to.dead then
      room:setPlayerMark(cd.to, "@s_sanliang_slash", cd.to:getMark("@s_sanliang_slash") + 1)
    end
  end,
})

-- 回合结束：清除散粮标记
s_sanliang:addEffect(fk.TurnEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    return player:getMark("@s_sanliang_slash") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@s_sanliang_slash", 0)
  end,
})

-- targetmod：使用杀次数+1
s_sanliang:addEffect("targetmod", {
  residue_func = function(self, player, card_skill, scope, card, to)
    if player:getMark("@s_sanliang_slash") > 0 and card and card.trueName == "slash" then
      return player:getMark("@s_sanliang_slash")
    end
    return 0
  end,
})

-- 测试1：体力变化后发动，给非当前回合角色3张牌，无杀次数加成
s_sanliang:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_sanliang.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 3
    comp2.hp = 3
    room.current = comp3
    -- 三张不同花色（黑桃/红桃/梅花）
    local c1 = room:printCard("slash", Card.Spade, 3)
    local c2 = room:printCard("jink", Card.Heart, 4)
    local c3 = room:printCard("peach", Card.Club, 5)
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local h = me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", { h[1], h[2], h[3] }, { card = { subcards = {} }, targets = { comp2.id } } })
    room:loseHp(me, 1, "test")
    lu.assertEquals(#comp2:getCardIds("h"), 3, "散粮：目标应获得3张牌")
    lu.assertEquals(comp2:getMark("@s_sanliang_slash"), 0, "散粮：非当前回合角色无杀次数加成")
  end)
end)

-- 测试2：目标为当前回合角色，获得杀次数+1
s_sanliang:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_sanliang.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 3
    comp2.hp = 3
    room.current = comp2
    -- 三张不同类型（基本/锦囊/装备）
    local c1 = room:printCard("slash", Card.Spade, 3)
    local c2 = room:printCard("duel", Card.Heart, 4)
    local c3 = room:printCard("crossbow", Card.Club, 5)
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local h = me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", { h[1], h[2], h[3] }, { card = { subcards = {} }, targets = { comp2.id } } })
    room:loseHp(me, 1, "test")
    lu.assertEquals(#comp2:getCardIds("h"), 3, "散粮：目标应获得3张牌")
    lu.assertEquals(comp2:getMark("@s_sanliang_slash"), 1, "散粮：当前回合角色应获得杀次数+1")
  end)
end)

return s_sanliang