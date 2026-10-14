local j_heli = fk.CreateSkill {
  name = "j_heli",
}

Fk:loadTranslationTable{
  ["j_heli"] = "合离",
  [":j_heli"] = "限定技，当你进入濒死状态时，你的体力上限和手牌数各加一，然后回复体力至2点。若场上有角色阵亡，你获得“共谋”和“疑异”。",

  ["#j_heli-invoke"] = "合离：是否发动（体力上限和手牌各加一，回复体力至2点）？",

  ["$j_heli1"] = "合则两利，离则俱伤。",
  ["$j_heli2"] = "你我同心，何惧生死。",
}

-- 限定技：进入濒死状态时触发
j_heli:addEffect(fk.EnterDying, {
  global = true,
  anim_type = "defense",
  can_trigger = function(self, event, target, player, data)
    if data.who ~= player or player.dead then return false end
    if not player:hasSkill(j_heli.name) then return false end
    return player:getMark("j_heli_used") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_heli.name, prompt = "#j_heli-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_heli_used", 1)

    -- 体力上限+1、手牌+1
    room:changeMaxHp(player, 1)
    player:drawCards(1, j_heli.name)

    -- 回复体力至2点
    if player.hp < 2 then
      room:recover{ who = player, num = 2 - player.hp, recoverBy = player, skillName = j_heli.name }
    end

    -- 若场上有角色阵亡 → 获得“共谋”和“疑异”
    if #room.alive_players < #room.players then
      room:handleAddLoseSkills(player, { "j_gongmou", "j_yiyi" })
    end
  end,
})

j_heli:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_heli.name,
  think = function(self, player)
    return true
  end,
})

-- 测试：进入濒死发动合离 → 上限+1、手牌+1、体力至2
j_heli:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_heli.name)
    local c1 = room:printCard("peach", Card.Heart, 1)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local maxHpBefore = me.maxHp
    local handBefore = #me:getCardIds("h")
    local hpBefore = me.hp
    FkTest.setNextReplies(me, { "1" })
    room:changeHp(me, -hpBefore, fk.LoseHp, "test") -- 置为0，自动进入濒死
    lu.assertEquals(me.maxHp, maxHpBefore + 1, "体力上限应+1")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 1, "手牌应+1")
    lu.assertEquals(me.hp, 2, "体力应回复至2点")
  end)
end)

-- 测试：场上有角色阵亡 → 获得共谋和疑异
j_heli:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_heli.name)
  end)

  FkTest.runInRoom(function()
    -- 重置限定技标记（addTest 共享同一 room，测试1 已发动过）
    room:setPlayerMark(me, "j_heli_used", 0)
    -- 制造一名角色阵亡
    room:killPlayer({ who = comp2 })

    room.current = me
    local hpBefore = me.hp
    FkTest.setNextReplies(me, { "1" })
    room:changeHp(me, -hpBefore, fk.LoseHp, "test") -- 自动进入濒死
    lu.assertTrue(me:hasSkill("j_gongmou"), "应获得共谋")
    lu.assertTrue(me:hasSkill("j_yiyi"), "应获得疑异")
  end)
end)

return j_heli