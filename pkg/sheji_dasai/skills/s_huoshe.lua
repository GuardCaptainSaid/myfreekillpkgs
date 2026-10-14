-- 舒邵六号·获赦
-- 锁定技，每回合每项限一次：
-- 1.你成为其他角色的基本牌目标时，若你手牌小于当前体力值，取消然后将手牌摸至体力上限。
-- 2.你成为其他角色的伤害牌目标后，若此牌对你造成了伤害，你回复一点体力。
-- 3.当你成为其他角色的延迟类锦囊牌目标时，你弃置一张手牌然后废除你的判定区直到你的下回合结束。
local s_huoshe = fk.CreateSkill {
  name = "s_huoshe",
}

Fk:loadTranslationTable{
  ["s_huoshe"] = "获赦",
  [":s_huoshe"] = "锁定技，每回合每项限一次：1.你成为其他角色的基本牌目标时，若你手牌小于当前体力值，取消然后将手牌摸至体力上限。2.你成为其他角色的伤害牌目标后，若此牌对你造成了伤害，你回复一点体力。3.当你成为其他角色的延迟类锦囊牌目标时，你弃置一张手牌然后废除你的判定区直到你的下回合结束。",

  ["#s_huoshe-discard"] = "获赦：弃置一张手牌并废除判定区",

  ["$s_huoshe1"] = "苍天垂悯，赦我残躯！",
  ["$s_huoshe2"] = "得蒙天赦，此身再起！",
}

-- 每回合结束：重置三项的次数标记
s_huoshe:addEffect(fk.RoundEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(s_huoshe.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "@s_huoshe_1_turn", 0)
    room:setPlayerMark(player, "@s_huoshe_2_turn", 0)
    room:setPlayerMark(player, "@s_huoshe_3_turn", 0)
  end,
})

-- 项1：成为其他角色基本牌目标时，手牌<当前体力 → 取消 + 摸至体力上限
s_huoshe:addEffect(fk.TargetConfirmed, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    if not player:hasSkill(s_huoshe.name) then return false end
    if player:getMark("@s_huoshe_1_turn") > 0 then return false end
    local from = data.from
    if not from or from == player then return false end
    local card = data.card
    if not card or card.type ~= Card.TypeBasic then return false end
    if #player:getCardIds("h") >= player.hp then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data:cancelTarget(player)
    room:setPlayerMark(player, "@s_huoshe_1_turn", 1)
    local need = player.maxHp - #player:getCardIds("h")
    if need > 0 then
      player:drawCards(need, s_huoshe.name)
    end
  end,
})

-- 项2：成为其他角色伤害牌目标后，若此牌造成了伤害 → 回复1
s_huoshe:addEffect(fk.Damaged, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    if not player:hasSkill(s_huoshe.name) then return false end
    if player:getMark("@s_huoshe_2_turn") > 0 then return false end
    if data.damage <= 0 then return false end
    local from = data.from
    if not from or from == player then return false end
    -- 伤害牌（杀/伤害类锦囊等）
    if not data.card then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:recover{ who = player, num = 1, recoverBy = player, skillName = s_huoshe.name }
    room:setPlayerMark(player, "@s_huoshe_2_turn", 1)
  end,
})

-- 项3：成为其他角色延时锦囊目标 → 弃一张手牌 + 废除判定区直到下回合结束
s_huoshe:addEffect(fk.TargetConfirmed, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    if not player:hasSkill(s_huoshe.name) then return false end
    if player:getMark("@s_huoshe_3_turn") > 0 then return false end
    local from = data.from
    if not from or from == player then return false end
    local card = data.card
    if not card then return false end
    if card.type ~= Card.TypeTrick or card.sub_type ~= Card.SubtypeDelayedTrick then return false end
    if #player:getCardIds("h") == 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 弃置一张手牌
    local c = room:askToDiscard(player, { min_num = 1, max_num = 1, include_equip = false, skill_name = s_huoshe.name, cancelable = false })
    if not c or #c == 0 then return end
    room:throwCard(c, fk.ReasonDiscard, s_huoshe.name, player, player)
    room:setPlayerMark(player, "@s_huoshe_3_turn", 1)
    -- 废除判定区
    if not table.contains(player.sealedSlots, Player.JudgeSlot) then
      room:abortPlayerArea(player, Player.JudgeSlot)
      room:setPlayerMark(player, "@@s_huoshe_judge", 1)
    end
  end,
})

-- 下回合结束：恢复被废除的判定区
s_huoshe:addEffect(fk.EventPhaseEnd, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(s_huoshe.name) then return false end
    if player:getMark("@@s_huoshe_judge") == 0 then return false end
    if data.to ~= Player.Finish then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if table.contains(player.sealedSlots, Player.JudgeSlot) then
      room:resumePlayerArea(player, Player.JudgeSlot)
    end
    room:setPlayerMark(player, "@@s_huoshe_judge", 0)
  end,
})

-- 测试1：项1 —— 成为杀目标且手牌<体力时，取消目标并摸至体力上限
s_huoshe:addTest(function(room, me)
  local comp2 = room.players[2]
  local sl
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_huoshe.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    room.current = comp2
    -- me 手牌1张（< 体力4）
    local h1 = room:printCard("slash", Card.Spade, 3)
    room:obtainCard(me, { h1 }, true, fk.ReasonDraw, me, "test")
    sl = room:printCard("slash", Card.Diamond, 9)
    room:obtainCard(comp2, { sl }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local hBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "0" })
    room:useCard{ from = comp2, tos = { me }, card = Fk:getCardById(sl), extraUse = true }
    lu.assertEquals(me.hp, 4, "获赦：目标被取消不应受伤")
    lu.assertEquals(#me:getCardIds("h"), me.maxHp, "获赦：应摸至体力上限")
    lu.assertEquals(hBefore, 1, "获赦：发动前手牌为1张")
    lu.assertEquals(me:getMark("@s_huoshe_1_turn"), 1, "获赦：应记录项1已用")
  end)
end)

-- 测试2：项2 —— 受到伤害牌伤害后回复1点体力
s_huoshe:addTest(function(room, me)
  local comp2 = room.players[2]
  local sl
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_huoshe.name)
    me.maxHp = 4
    me.hp = 3
    comp2.maxHp = 4
    comp2.hp = 4
    room.current = comp2
    -- me 手牌足够（4张>体力），不触发项1
    local h1 = room:printCard("jink", Card.Heart, 4)
    local h2 = room:printCard("jink", Card.Club, 5)
    local h3 = room:printCard("peach", Card.Spade, 6)
    local h4 = room:printCard("duel", Card.Heart, 7)
    room:obtainCard(me, { h1, h2, h3, h4 }, true, fk.ReasonDraw, me, "test")
    sl = room:printCard("slash", Card.Diamond, 9)
    room:obtainCard(comp2, { sl }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    -- me 不出闪 → 受1点伤害 → 回复1
    FkTest.setNextReplies(me, { "0" })
    room:useCard{ from = comp2, tos = { me }, card = Fk:getCardById(sl), extraUse = true }
    lu.assertEquals(me.hp, 3, "获赦：受到1点伤害后应回复至3")
    lu.assertEquals(me:getMark("@s_huoshe_2_turn"), 1, "获赦：应记录项2已用")
  end)
end)

-- 测试3：项3 —— 成为延时锦囊目标时弃一张手牌并废除判定区
s_huoshe:addTest(function(room, me)
  local comp2 = room.players[2]
  local h1, h2, jx
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_huoshe.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    room.current = comp2
    h1 = room:printCard("slash", Card.Spade, 3)
    h2 = room:printCard("jink", Card.Heart, 4)
    room:obtainCard(me, { h1, h2 }, true, fk.ReasonDraw, me, "test")
    jx = room:printCard("indulgence", Card.Diamond, 9)
    room:obtainCard(comp2, { jx }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local hBefore = #me:getCardIds("h")
    -- me：弃置一张手牌（选 h1）
    FkTest.setNextReplies(me, { { h1 } })
    room:useCard{ from = comp2, tos = { me }, card = Fk:getCardById(jx), extraUse = true }
    lu.assertEquals(#me:getCardIds("h"), hBefore - 1, "获赦：应弃置1张手牌")
    lu.assertTrue(table.contains(me.sealedSlots, Player.JudgeSlot), "获赦：判定区应被废除")
    lu.assertEquals(me:getMark("@s_huoshe_3_turn"), 1, "获赦：应记录项3已用")
  end)
end)

return s_huoshe