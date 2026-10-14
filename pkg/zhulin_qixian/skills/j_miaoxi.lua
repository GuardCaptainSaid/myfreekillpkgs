local j_miaoxi = fk.CreateSkill {
  name = "j_miaoxi",
}

Fk:loadTranslationTable{
  ["j_miaoxi"] = "妙析",
  [":j_miaoxi"] = "出牌阶段限一次，你可以与一名其他角色各展示一张手牌，若这些牌：颜色相同，你获得其的展示牌；类别相同，其失去1点体力；点数相同，重置〖妙析〗；若都不同，你摸两张牌。",

  ["#j_miaoxi-target"] = "妙析：选择一名其他角色各展示一张手牌",
  ["#j_miaoxi-mine"] = "妙析：选择你要展示的手牌",
  ["#j_miaoxi-theirs"] = "妙析：选择该角色要展示的手牌",

  ["$j_miaoxi1"] = "析理入微，妙在毫芒。",
  ["$j_miaoxi2"] = "一念之析，天地自分。",
}

-- 主动技：出牌阶段限一次；点数相同时重置（本回合可再次发动）
j_miaoxi:addEffect("active", {
  anim_type = "drawcard",
  card_num = 0,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    local used = player:usedSkillTimes(j_miaoxi.name, Player.HistoryTurn)
    local reset = player:getMark("j_miaoxi_reset")
    return used - reset <= 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player),
      min_num = 1,
      max_num = 1,
      cancelable = false,
      skill_name = j_miaoxi.name,
      prompt = "#j_miaoxi-target",
    })[1]
    if not target then return end

    local myCard = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      min = 1, max = 1, cancelable = false,
      pattern = ".",
      skill_name = j_miaoxi.name,
      prompt = "#j_miaoxi-mine",
    })[1]
    local theirCard = room:askToChooseCards(player, {
      target = target,
      flag = "h",
      min = 1, max = 1, cancelable = false,
      pattern = ".",
      skill_name = j_miaoxi.name,
      prompt = "#j_miaoxi-theirs",
    })[1]
    if not myCard or not theirCard then return end

    room:showCards({ myCard, theirCard }, player)
    local mc = Fk:getCardById(myCard)
    local tc = Fk:getCardById(theirCard)

    if mc.color ~= Card.NoColor and mc.color == tc.color then
      -- 颜色相同 → 获得其展示牌
      room:obtainCard(player, { theirCard }, true, fk.ReasonGot, target, j_miaoxi.name)
    elseif mc.type == tc.type then
      -- 类别相同 → 其失去1点体力
      room:loseHp(target, 1, j_miaoxi.name, player)
    elseif mc.number == tc.number then
      -- 点数相同 → 重置（本回合可再次发动）
      room:setPlayerMark(player, "j_miaoxi_reset", player:getMark("j_miaoxi_reset") + 1)
    else
      -- 都不同 → 你摸两张牌
      player:drawCards(2, j_miaoxi.name)
    end
  end,
})

-- 自己的回合开始：清零妙析重置标记
j_miaoxi:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Start then return false end
    if not player:hasSkill(j_miaoxi.name) then return false end
    return player:getMark("j_miaoxi_reset") > 0
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_miaoxi_reset", 0)
  end,
})

j_miaoxi:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_miaoxi.name,
  think = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0
  end,
})

-- 测试：颜色相同 → 获得其展示牌
j_miaoxi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_miaoxi.name)
    local c1 = room:printCard("slash", Card.Heart, 2) -- 红
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    local t1 = room:printCard("jink", Card.Diamond, 3) -- 红
    room:obtainCard(comp2, { t1 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    local meHand = me:getCardIds("h")
    local compHand = comp2:getCardIds("h")
    FkTest.setNextReplies(me, { FkTest.ReplyChoosePlayer({ comp2 }), { meHand[1] }, { compHand[1] } })
    local sk = Fk.skills[j_miaoxi.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(#comp2:getCardIds("h"), 0, "妙析：目标展示牌应被获得")
    lu.assertTrue(table.contains(me:getCardIds("h"), compHand[1]), "妙析：应获得其展示牌")
  end)
end)

-- 测试：点数相同 → 重置妙析（重置标记+1）
j_miaoxi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_miaoxi.name)
    local c1 = room:printCard("slash", Card.Heart, 2) -- 红/基本/2
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    local t1 = room:printCard("guding_blade", Card.Spade, 2) -- 黑/装备/2（颜色、类别均不同，仅点数相同）
    room:obtainCard(comp2, { t1 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    local meHand = me:getCardIds("h")
    local compHand = comp2:getCardIds("h")
    FkTest.setNextReplies(me, { FkTest.ReplyChoosePlayer({ comp2 }), { meHand[1] }, { compHand[1] } })
    local sk = Fk.skills[j_miaoxi.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(me:getMark("j_miaoxi_reset"), 1, "妙析：点数相同应重置")
    lu.assertEquals(#me:getCardIds("h"), 1, "妙析：点数相同不应获得牌")
  end)
end)

-- 测试：都不同 → 摸两张牌
j_miaoxi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_miaoxi.name)
    local c1 = room:printCard("slash", Card.Heart, 2) -- 红/基本/2
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    local t1 = room:printCard("guding_blade", Card.Spade, 9) -- 黑/装备/9
    room:obtainCard(comp2, { t1 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    local meHand = me:getCardIds("h")
    local compHand = comp2:getCardIds("h")
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { FkTest.ReplyChoosePlayer({ comp2 }), { meHand[1] }, { compHand[1] } })
    local sk = Fk.skills[j_miaoxi.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(#me:getCardIds("h"), handBefore + 2, "妙析：都不同应摸两张牌")
  end)
end)

return j_miaoxi