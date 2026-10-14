local j_sijiu = fk.CreateSkill {
  name = "j_sijiu",
}

Fk:loadTranslationTable{
  ["j_sijiu"] = "思旧",
  [":j_sijiu"] = "回合结束时，若你本回合获得过其他角色的牌，你可以摸一张牌并观看一名其他角色的手牌。",

  ["#j_sijiu-invoke"] = "思旧：是否发动（摸一张牌并观看一名其他角色的手牌）？",
  ["#j_sijiu-target"] = "思旧：选择一名其他角色观看其手牌",

  ["$j_sijiu1"] = "旧友凋零，思之泫然。",
  ["$j_sijiu2"] = "睹物思人，哀从中来。",
}

-- 自己回合开始：清零本回合获得标记
j_sijiu:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Start then return false end
    if target ~= player then return false end
    if not player:hasSkill(j_sijiu.name) then return false end
    return player:getMark("j_sijiu_got") > 0
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_sijiu_got", 0)
  end,
})

-- 获得其他角色的牌时打标记（全局监听，静默执行）
j_sijiu:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_sijiu.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if move.to and move.to.id == player.id and move.from and move.from ~= player then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_sijiu_got", 1)
  end,
})

-- 回合结束时：若本回合获得过其他角色的牌 → 摸一张并观看一名其他角色手牌
j_sijiu:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Finish then return false end
    if target ~= player then return false end
    if not player:hasSkill(j_sijiu.name) or player.dead then return false end
    return player:getMark("j_sijiu_got") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_sijiu.name, prompt = "#j_sijiu-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:drawCards(1, j_sijiu.name)
    local t = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player),
      min_num = 1,
      max_num = 1,
      cancelable = false,
      skill_name = j_sijiu.name,
      prompt = "#j_sijiu-target",
    })[1]
    if t then
      room:showCards(t:getCardIds("h"), t)
    end
  end,
})

j_sijiu:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_sijiu.name,
  think = function(self, player)
    return player:getMark("j_sijiu_got") > 0
  end,
})

-- 测试：本回合获得过其他角色的牌 → 回合结束时摸一张并观看手牌
j_sijiu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_sijiu.name)
    local c1 = room:printCard("slash", Card.Heart, 5)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    -- me 获得 comp2 一张牌 → 打标记
    local compHand = comp2:getCardIds("h")
    room:obtainCard(me, { compHand[1] }, true, fk.ReasonGot, comp2, "test")
    lu.assertEquals(me:getMark("j_sijiu_got"), 1, "思旧：获得其他角色牌应有标记")

    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", FkTest.ReplyChoosePlayer({ comp2 }) })
    local phaseData = { from = Player.Play, to = Player.Finish }
    room.logic:trigger(fk.EventPhaseStart, me, phaseData)

    lu.assertEquals(#me:getCardIds("h"), handBefore + 1, "思旧：应摸一张牌")
  end)
end)

-- 测试：本回合未获得其他角色的牌 → 回合结束不触发
j_sijiu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_sijiu.name)
    room:setPlayerMark(me, "j_sijiu_got", 0)
  end)

  FkTest.runInRoom(function()
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1" })
    local phaseData = { from = Player.Play, to = Player.Finish }
    room.logic:trigger(fk.EventPhaseStart, me, phaseData)
    lu.assertEquals(#me:getCardIds("h"), handBefore, "思旧：未获得牌时不应触发摸牌")
  end)
end)

return j_sijiu