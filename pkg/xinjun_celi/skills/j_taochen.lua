-- 君曹操·讨臣
-- 每轮限一次，其他角色出牌阶段开始时，你可以令其展示所有手牌。若其中有至少两张不同花色的牌，则你选择其中一张获得之，且其本回合不能对除你外的角色使用牌；若其手牌花色均相同，则其对你造成1点伤害，你摸x张牌。（x为场上角色数）
local j_taochen = fk.CreateSkill {
  name = "j_taochen",
}

Fk:loadTranslationTable{
  ["j_taochen"] = "讨臣",
  [":j_taochen"] = "每轮限一次，其他角色出牌阶段开始时，你可以令其展示所有手牌。若其中有至少两张不同花色的牌，则你选择其中一张获得之，且其本回合不能对除你外的角色使用牌；若其手牌花色均相同，则其对你造成1点伤害，你摸x张牌。（x为场上角色数）",

  ["#j_taochen-invoke"] = "讨臣：是否令其展示所有手牌？",
  ["#j_taochen-get"] = "讨臣：选择获得其一张手牌",
  ["@j_taochen_ban"] = "讨臣",

  ["$j_taochen1"] = "顺我者昌，逆我者亡！",
  ["$j_taochen2"] = "尔等之心，朕一目了然！",
}

j_taochen:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Play then return false end
    if target == player or target.dead then return false end
    if not player:hasSkill(j_taochen.name) or player.dead then return false end
    if player:getMark("@j_taochen_used") > 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_taochen.name, prompt = "#j_taochen-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "@j_taochen_used", 1)
    local hand = target:getCardIds("h")
    if #hand == 0 then return end
    room:showCards(hand, target)
    local suits = {}
    for _, id in ipairs(hand) do
      local s = Fk:getCardById(id).suit
      if not table.contains(suits, s) then table.insert(suits, s) end
    end
    if #suits >= 2 then
      -- 至少两张不同花色：获得其中一张，其本回合不能对除你外的角色使用牌
      local c = room:askToChooseCards(player, {
        target = target,
        flag = "h",
        min = 1,
        max = 1,
        cancelable = false,
        pattern = ".",
        skill_name = j_taochen.name,
        prompt = "#j_taochen-get",
      })
      if c and #c > 0 then
        room:obtainCard(player, c, true, fk.ReasonGive, target, j_taochen.name)
        room:setPlayerMark(target, "@j_taochen_ban", 1)
        room:setPlayerMark(target, "@j_taochen_owner", player.id)
      end
    else
      -- 花色均相同：其对你造成1点伤害，你摸x张（x为场上角色数）
      room:damage{ from = target, to = player, damage = 1, damageType = fk.NormalDamage, skillName = j_taochen.name }
      if not player.dead then
        player:drawCards(#room.alive_players, j_taochen.name)
      end
    end
  end,
})

-- 被讨臣的角色本回合不能对除君曹操外的角色使用牌
j_taochen:addEffect("prohibit", {
  is_prohibited = function(self, from, to, card)
    if from:getMark("@j_taochen_ban") == 1 and to and to.id ~= from:getMark("@j_taochen_owner") then
      return true
    end
    return false
  end,
})

-- 该角色回合结束：清除限制
j_taochen:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Finish then return false end
    return target and target:getMark("@j_taochen_ban") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = target.room
    room:setPlayerMark(target, "@j_taochen_ban", 0)
    room:setPlayerMark(target, "@j_taochen_owner", 0)
  end,
})

-- 每轮结束时重置限次
j_taochen:addEffect(fk.RoundEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_taochen.name) and player:getMark("@j_taochen_used") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@j_taochen_used", 0)
  end,
})

-- 测试：其他角色手牌有两色 → 获得一张且被禁
j_taochen:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_taochen.name)
    me.maxHp = 4
    me.hp = 4
    room.current = comp2
    comp2.phase = Player.Play
    local h1 = room:printCard("slash", Card.Spade, 2)
    local h2 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(comp2, { h1, h2 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = comp2
    comp2.phase = Player.Play
    local hand = comp2:getCardIds("h")
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", { hand[1] } })
    room.logic:trigger(fk.EventPhaseStart, comp2, { from = Player.Draw, to = Player.Play })
    lu.assertEquals(#me:getCardIds("h"), handBefore + 1, "讨臣：应获得其一张手牌")
    lu.assertEquals(comp2:getMark("@j_taochen_ban"), 1, "讨臣：应限制其出牌")
    lu.assertEquals(comp2:getMark("@j_taochen_owner"), me.id, "讨臣：应限制其对他人用牌")
    -- 回合结束清除
    room.logic:trigger(fk.EventPhaseStart, comp2, { from = Player.Play, to = Player.Finish })
    lu.assertEquals(comp2:getMark("@j_taochen_ban"), 0, "讨臣：回合结束应清除限制")
  end)
end)

-- 测试：手牌花色均相同 → 造成伤害并摸牌
j_taochen:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_taochen.name)
    me.maxHp = 4
    me.hp = 4
    room.current = comp2
    comp2.phase = Player.Play
    local h1 = room:printCard("slash", Card.Spade, 2)
    local h2 = room:printCard("jink", Card.Spade, 3)
    room:obtainCard(comp2, { h1, h2 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = comp2
    comp2.phase = Player.Play
    local hpBefore = me.hp
    local handBefore = #me:getCardIds("h")
    local alive = #room.alive_players
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.EventPhaseStart, comp2, { from = Player.Draw, to = Player.Play })
    lu.assertEquals(me.hp, hpBefore - 1, "讨臣：应受到1点伤害")
    lu.assertEquals(#me:getCardIds("h"), handBefore + alive, "讨臣：应摸场上角色数张牌")
  end)
end)

return j_taochen