local j_sulv = fk.CreateSkill {
  name = "j_sulv",
}

Fk:loadTranslationTable{
  ["j_sulv"] = "肃律",
  [":j_sulv"] = "回合开始时，你可以令所有手牌数不等于体力值的角色各摸一张牌；回合结束时，你可以获得所有其他角色各一张手牌。",

  ["#j_sulv-invoke1"] = "肃律：是否令所有手牌数不等于体力值的角色各摸一张牌？",
  ["#j_sulv-invoke2"] = "肃律：是否获得所有其他角色各一张手牌？",

  ["$j_sulv1"] = "法度既立，天下咸遵。",
  ["$j_sulv2"] = "肃清朝纲，何人敢犯！",
}

-- 手牌数不等于当前体力值的角色
local function hand_ne_hp(room)
  return table.filter(room.alive_players, function(p)
    return p:getHandcardNum() ~= p.hp
  end)
end

-- 回合开始时：令所有手牌数不等于体力值的角色各摸一张牌
j_sulv:addEffect(fk.TurnStart, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_sulv.name) or player.dead then return false end
    if target ~= player then return false end
    return #hand_ne_hp(player.room) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_sulv.name, prompt = "#j_sulv-invoke1" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(table.simpleClone(hand_ne_hp(room))) do
      if p:isAlive() then
        room:drawCards(p, 1, j_sulv.name)
      end
    end
  end,
})

-- 回合结束时：获得所有其他角色的一张手牌（随机）
j_sulv:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_sulv.name) or player.dead then return false end
    if target ~= player then return false end
    return table.find(player.room.alive_players, function(p)
      return p ~= player and p:getHandcardNum() > 0
    end) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_sulv.name, prompt = "#j_sulv-invoke2" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(table.simpleClone(room.alive_players)) do
      if p ~= player and p:isAlive() and p:getHandcardNum() > 0 then
        local ids = p:getCardIds("h")
        local id = ids[math.random(1, #ids)]
        room:obtainCard(player, { id }, true, fk.ReasonPrey, p, j_sulv.name)
        if player.dead then return end
      end
    end
  end,
})

-- 测试：回合开始时所有手牌数不等于体力值的角色各摸一张牌
j_sulv:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_sulv.name)
    -- 让 comp2 手牌数（2）不等于体力值（1）→ 应摸牌
    local c1 = room:printCard("slash", Card.Spade, 5)
    local c2 = room:printCard("jink", Card.Heart, 6)
    room:obtainCard(comp2, { c1, c2 }, true, fk.ReasonDraw, comp2, "test")
    comp2.hp = 1
    -- me 手牌数等于体力值 → 不摸牌
    me.hp = #me:getCardIds("h")
  end)

  FkTest.runInRoom(function()
    local before = #comp2:getCardIds("h")
    local my_before = #me:getCardIds("h")
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return true end
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToSkillInvoke = origInvoke
    lu.assertEquals(#comp2:getCardIds("h"), before + 1, "手牌数不等于体力值的角色应摸一张牌")
    lu.assertEquals(#me:getCardIds("h"), my_before, "手牌数等于体力值的角色不应摸牌")
  end)
end)

-- 测试：回合开始时拒绝发动则无人摸牌
j_sulv:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_sulv.name)
    local c1 = room:printCard("slash", Card.Spade, 5)
    local c2 = room:printCard("jink", Card.Heart, 6)
    room:obtainCard(comp2, { c1, c2 }, true, fk.ReasonDraw, comp2, "test")
    comp2.hp = 1 -- 手牌数(2) ≠ 体力值(1) → 若不发动则不应摸牌
  end)

  FkTest.runInRoom(function()
    local before = #comp2:getCardIds("h")
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return false end
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToSkillInvoke = origInvoke
    lu.assertEquals(#comp2:getCardIds("h"), before, "拒绝发动时手牌数不等于体力值的角色不应摸牌")
  end)
end)

-- 测试：回合结束时获得所有其他角色一张手牌
j_sulv:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_sulv.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return true end
    room.logic:trigger(fk.TurnEnd, me, {})
    room.askToSkillInvoke = origInvoke
    lu.assertTrue(table.contains(me:getCardIds("h"), c1.id), "回合结束应获得其他角色一张手牌")
    lu.assertEquals(#comp2:getCardIds("h"), 0, "被获得手牌的角色应少一张手牌")
  end)
end)

return j_sulv
