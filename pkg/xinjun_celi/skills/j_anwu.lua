-- 君孙权·安吴
-- 其他角色对你使用的【杀】需先弃一张红桃牌，否则无效。
local j_anwu = fk.CreateSkill {
  name = "j_anwu",
}

Fk:loadTranslationTable{
  ["j_anwu"] = "安吴",
  [":j_anwu"] = "其他角色对你使用的【杀】需先弃一张红桃牌，否则无效。",

  ["#j_anwu-discard"] = "安吴：弃置一张红桃牌，否则此【杀】对你无效",

  ["$j_anwu1"] = "吴地安泰，君临江东！",
  ["$j_anwu2"] = "江东之基，稳如泰山！",
}

j_anwu:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_anwu.name, true) or player.dead then return false end
    if not data.card or not data.from or data.from == player then return false end
    local n = data.card.name
    if n ~= "slash" and n ~= "fire__slash" and n ~= "thunder__slash" then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    local ok = false
    if from and not from.dead and not from:isAllNude() then
      local c = room:askToChooseCards(from, {
        target = from,
        flag = "hej",
        min = 0,
        max = 1,
        cancelable = true,
        pattern = ".",
        skill_name = j_anwu.name,
        prompt = "#j_anwu-discard",
      })
      if c and #c > 0 and Fk:getCardById(c[1]).suit == Card.Heart then
        room:throwCard(c, j_anwu.name, from, from)
        ok = true
      end
    end
    if not ok then
      data:cancelCurrentTarget()
    end
  end,
})

-- 测试：对方有红桃可弃则杀有效；无红桃则无效
j_anwu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_anwu.name)
    me.maxHp = 4
    me.hp = 4
    room.current = comp2
    comp2.phase = Player.Play
    -- comp2 有红桃牌可弃
    local h = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(comp2, { h }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = comp2
    comp2.phase = Player.Play
    local hpBefore = me.hp
    -- comp2 用杀指定 me：弃红桃 → 杀有效
    local slash = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(comp2, { slash }, true, fk.ReasonDraw, comp2, "test")
    local heartCard = comp2:getCardIds("h")[1]
    -- me 无闪 → 受伤
    FkTest.setNextReplies(comp2, { { heartCard } })
    room:useCard{ from = comp2, card = slash, tos = { me } }
    lu.assertEquals(me.hp, hpBefore - 1, "安吴：弃红桃后杀应有效")
  end)
end)

-- 测试：无红桃可弃 → 杀无效
j_anwu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_anwu.name)
    me.maxHp = 4
    me.hp = 4
    room.current = comp2
    comp2.phase = Player.Play
    -- comp2 只有黑桃牌，无红桃
    local h = room:printCard("jink", Card.Spade, 3)
    room:obtainCard(comp2, { h }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = comp2
    comp2.phase = Player.Play
    local hpBefore = me.hp
    local slash = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(comp2, { slash }, true, fk.ReasonDraw, comp2, "test")
    FkTest.setNextReplies(comp2, { {} }) -- 无可弃红桃（取消）
    room:useCard{ from = comp2, card = slash, tos = { me } }
    lu.assertEquals(me.hp, hpBefore, "安吴：无红桃可弃时杀应无效")
  end)
end)

return j_anwu