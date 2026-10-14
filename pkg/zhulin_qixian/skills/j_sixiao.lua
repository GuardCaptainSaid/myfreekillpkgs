local j_sixiao = fk.CreateSkill {
  name = "j_sixiao",
}

Fk:loadTranslationTable{
  ["j_sixiao"] = "死孝",
  [":j_sixiao"] = "游戏开始时，你选择一名其他角色。每名角色的回合限一次，当其需要使用牌时，其可以观看你的手牌并可以选择其中一张牌使用之，然后你摸一张牌。",

  ["#j_sixiao-bind"] = "死孝：选择一名其他角色（其需要使用牌时可使用你的手牌）",
  ["#j_sixiao-invoke"] = "死孝：是否观看 %arg 的手牌并选择一张牌使用？",
  ["#j_sixiao-pick"] = "死孝：选择一张牌使用",

  ["$j_sixiao1"] = "哀毁骨立，终难自持。",
  ["$j_sixiao2"] = "孝子之事，不敢一日忘亲。",
}

-- 游戏开始时：选择一名其他角色绑定
j_sixiao:addEffect(fk.GameStart, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_sixiao.name) and player:getMark("j_sixiao_bind") == 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local t = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player),
      min_num = 1,
      max_num = 1,
      cancelable = false,
      skill_name = j_sixiao.name,
      prompt = "#j_sixiao-bind",
    })[1]
    if t then
      room:setPlayerMark(player, "j_sixiao_bind", t.id)
    end
  end,
})

-- 绑定角色需要使用牌时：可观看王戎手牌并选一张使用，王戎摸一张
j_sixiao:addEffect(fk.AskForCardUse, {
  global = true,
  priority = 5,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_sixiao.name) or player.dead then return false end
    if target == player then return false end
    local bind = player:getMark("j_sixiao_bind")
    if bind == 0 or target.id ~= bind then return false end
    if #player:getCardIds("h") == 0 then return false end
    if target:usedSkillTimes(j_sixiao.name, Player.HistoryTurn) > 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    room:showCards(player:getCardIds("h"), player)
    return room:askToSkillInvoke(target, { skill_name = j_sixiao.name, prompt = "#j_sixiao-invoke::" .. player.id })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local picked = room:askToChooseCards(target, {
      target = player,
      flag = "h",
      min = 1, max = 1, cancelable = false,
      pattern = ".",
      skill_name = j_sixiao.name,
      prompt = "#j_sixiao-pick",
    })
    if not picked or #picked == 0 then return end
    local card = Fk:getCardById(picked[1])
    -- 将选中的牌交给绑定角色，再由其使用
    room:moveCardTo(picked, Card.PlayerHand, target, fk.ReasonPreUse, j_sixiao.name, nil, false, player)
    if not table.contains(target:getCardIds("h"), picked[1]) then return end
    room:useCard{ from = target, card = card, tos = {}, skillName = j_sixiao.name }
    player:drawCards(1, j_sixiao.name)
  end,
})

j_sixiao:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_sixiao.name,
  think = function(self, player)
    return false
  end,
})

-- 测试：游戏开始绑定 → 绑定角色需要使用牌时选王戎一张手牌使用 → 王戎摸一张
j_sixiao:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_sixiao.name)
    -- 王戎手牌一张“闪”（无目标牌，便于测试直接使用）
    local c1 = room:printCard("jink", Card.Heart, 5)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    -- 游戏开始：王戎选择绑定 comp2（GameStart 可能伴随其他技能询问，多备回复兜底）
    FkTest.setNextReplies(me, {
      FkTest.ReplyChoosePlayer({ comp2 }),
      FkTest.ReplyChoosePlayer({ comp2 }),
      FkTest.ReplyChoosePlayer({ comp2 }),
      FkTest.ReplyChoosePlayer({ comp2 }),
    })
    room.logic:trigger(fk.GameStart, me, {})
    lu.assertEquals(me:getMark("j_sixiao_bind"), comp2.id, "死孝：应绑定所选角色")

    -- comp2 需要使用牌：观看王戎手牌并选一张使用
    local myHand = me:getCardIds("h")
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(comp2, { "1", { myHand[1] } })
    room.logic:trigger(fk.AskForCardUse, comp2, { user = comp2, pattern = "jink" })

    -- 王戎摸一张
    lu.assertEquals(#me:getCardIds("h"), handBefore, "死孝：王戎失去展示牌但摸回一张（净手牌不变）")
  end)
end)

-- 测试：绑定角色使用过死孝后本回合不再触发
j_sixiao:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_sixiao.name)
    room:setPlayerMark(me, "j_sixiao_bind", comp2.id)
    local c1 = room:printCard("jink", Card.Heart, 6)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    -- 模拟 comp2 本回合已用过死孝（usedSkillTimes 无法直接设置，用触发一次后再触发验证）
    local myHand = me:getCardIds("h")
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(comp2, { "1", { myHand[1] } })
    room.logic:trigger(fk.AskForCardUse, comp2, { user = comp2, pattern = "jink" })
    local handAfter1 = #me:getCardIds("h")

    -- 第二次触发：不应再触发（本回合已使用过）
    local handBefore2 = #me:getCardIds("h")
    FkTest.setNextReplies(comp2, { "1", { myHand[1] } })
    room.logic:trigger(fk.AskForCardUse, comp2, { user = comp2, pattern = "jink" })
    lu.assertEquals(#me:getCardIds("h"), handBefore2, "死孝：本回合第二次需要牌时不应再触发")
    lu.assertEquals(handAfter1, handBefore, "死孝：第一次触发后王戎手牌应净不变")
  end)
end)

return j_sixiao