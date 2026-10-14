-- 鲍三娘一号·戊疆（双面：阳攻/阴守）
-- 阳(攻态，出征平蛮)：当你造成伤害后，你可以将一枚「疆」标记翻面为「蛮」；你每拥有两枚「蛮」，使用【杀】可额外指定一个目标。
-- 阴(守态，安民镇土)：当有其他角色受到伤害后，你可以将一枚「蛮」翻面为「疆」；你每拥有两枚「疆」，受到伤害时可令来源弃一张牌。
local s_wujiang = fk.CreateSkill {
  name = "s_wujiang",
}

Fk:loadTranslationTable{
  ["s_wujiang"] = "戊疆",
  [":s_wujiang"] = "阳（攻态，出征平蛮）：当你造成伤害后，你可以将一枚「疆」标记翻面为「蛮」；你每拥有两枚「蛮」，使用【杀】可额外指定一个目标。阴（守态，安民镇土）：当有其他角色受到伤害后，你可以将一枚「蛮」翻面为「疆」；你每拥有两枚「疆」，受到伤害时可令来源弃一张牌。",

  ["#s_wujiang-yang"] = "戊疆·阳：是否将一枚「疆」翻面为「蛮」？",
  ["#s_wujiang-yin"] = "戊疆·阴：是否将一枚「蛮」翻面为「疆」？",
  ["#s_wujiang-shou"] = "戊疆·阴守：是否令伤害来源弃一张牌？",
  ["#s_wujiang-discard"] = "戊疆：请弃置一张牌",
  ["@s_wujiang_jiang"] = "疆",
  ["@s_wujiang_man"] = "蛮",
}

-- 阳：造成伤害后 → 疆→蛮
s_wujiang:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    if player.dead or not player:hasSkill(s_wujiang.name) then return false end
    if not data or data.from ~= player then return false end
    return player:getMark("@s_wujiang_jiang") >= 1
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, s_wujiang.name, "#s_wujiang-yang")
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "@s_wujiang_jiang", player:getMark("@s_wujiang_jiang") - 1)
    room:setPlayerMark(player, "@s_wujiang_man", player:getMark("@s_wujiang_man") + 1)
  end,
})

-- 阴：其他角色受到伤害后 → 蛮→疆
s_wujiang:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    if player.dead or not player:hasSkill(s_wujiang.name) then return false end
    if not data or data.to == player then return false end
    return player:getMark("@s_wujiang_man") >= 1
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, s_wujiang.name, "#s_wujiang-yin")
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "@s_wujiang_man", player:getMark("@s_wujiang_man") - 1)
    room:setPlayerMark(player, "@s_wujiang_jiang", player:getMark("@s_wujiang_jiang") + 1)
  end,
})

-- 每两枚蛮：使用【杀】可额外指定一个目标
s_wujiang:addEffect("targetmod", {
  extra_target_func = function(self, player, skill)
    if not player:hasSkill(s_wujiang.name) then return 0 end
    if skill and skill.trueName == "slash_skill" then
      return player:getMark("@s_wujiang_man") // 2
    end
    return 0
  end,
})

-- 阴守：我受到伤害时（每两枚疆）可令来源弃一张牌
s_wujiang:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    if player.dead or not player:hasSkill(s_wujiang.name) then return false end
    if not data or data.to ~= player or not data.from or data.from.dead then return false end
    return player:getMark("@s_wujiang_jiang") >= 2
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, s_wujiang.name, "#s_wujiang-shou")
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local n = player:getMark("@s_wujiang_jiang") // 2
    for _ = 1, n do
      local from = data.from
      if from.dead then break end
      local ids = room:askToDiscard(from, {
        min_num = 1, max_num = 1,
        skill_name = s_wujiang.name,
        prompt = "#s_wujiang-discard",
        cancelable = true,
      })
      if #ids == 0 then break end
    end
  end,
})

-- 测试1：造成伤害后翻面（疆→蛮）；两蛮杀额外一目标
s_wujiang:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_wujiang.name)
    room:setPlayerMark(me, "@s_wujiang_jiang", 2)
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.DamageCaused, comp2, { from = me, to = comp2, damage = 1 })
    lu.assertEquals(me:getMark("@s_wujiang_jiang"), 1, "戊疆·阳：疆应-1")
    lu.assertEquals(me:getMark("@s_wujiang_man"), 1, "戊疆·阳：蛮应+1")
  end)
  FkTest.runInRoom(function()
    room:setPlayerMark(me, "@s_wujiang_man", 4)
    room.current = me
    me.phase = Player.Play
    -- extra_target_func 通过派生技能骨架取
    local tm = nil
    for k, v in pairs(Fk.skills) do
      if string.startsWith(k, "#s_wujiang_") and string.find(k, "targetmod", 1, true) then
        tm = v
        break
      end
    end
    lu.assertNotNil(tm, "戊疆：targetmod 应已生成")
    if tm then
      local fakeSkill = { trueName = "slash_skill" }
      lu.assertEquals(tm:getExtraTargetNum(me, fakeSkill), 2, "戊疆：每两蛮杀额外一个目标")
    end
  end)
end)

-- 测试2：其他角色受伤翻面（蛮→疆）；我受伤害时令来源弃牌
s_wujiang:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_wujiang.name)
    room:setPlayerMark(me, "@s_wujiang_man", 2)
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.DamageInflicted, comp2, { from = me, to = comp2, damage = 1 })
    lu.assertEquals(me:getMark("@s_wujiang_man"), 1, "戊疆·阴：蛮应-1")
    lu.assertEquals(me:getMark("@s_wujiang_jiang"), 1, "戊疆·阴：疆应+1")
  end)
  FkTest.runInRoom(function()
    room:setPlayerMark(me, "@s_wujiang_jiang", 4)
    -- 我受伤害（疆4→弃2张）
    local card1 = room:printCard("slash", Card.Spade, 1)
    local card2 = room:printCard("duel", Card.Heart, 1)
    room:moveCardTo(card1, Player.Hand, comp2, fk.ReasonGive, "test")
    room:moveCardTo(card2, Player.Hand, comp2, fk.ReasonGive, "test")
    FkTest.setNextReplies(me, { "1" })
    FkTest.setNextReplies(comp2, {
      FkTest.ReplyDiscard({ card1.id }),
      FkTest.ReplyDiscard({ card2.id }),
    })
    room.logic:trigger(fk.DamageInflicted, me, { from = comp2, to = me, damage = 1 })
    lu.assertEquals(#comp2:getCardIds("h"), 0, "戊疆·阴守：来源应弃2张牌")
  end)
end)

return s_wujiang