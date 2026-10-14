-- 君袁术·饥馑（僭业附属技能）
-- 每回合开始时你弃置一张黑色牌，否则受到1点雷电伤害。
local j_jihui = fk.CreateSkill {
  name = "j_jihui",
}

Fk:loadTranslationTable{
  ["j_jihui"] = "饥馑",
  [":j_jihui"] = "每回合开始时你弃置一张黑色牌，否则受到1点雷电伤害。",

  ["#j_jihui-discard"] = "饥馑：弃置一张黑色牌，否则受到1点雷电伤害",
  ["@j_jihui"] = "饥馑",

  ["$j_jihui1"] = "粮道断绝，天不佑汝！",
  ["$j_jihui2"] = "饥肠辘辘，何以自持！",
}

j_jihui:addEffect(fk.EventPhaseStart, {
  anim_type = "negative",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_jihui.name, true) or player.dead then return false end
    if data.to ~= Player.Play then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 找黑色牌（黑桃/梅花）
    local blacks = {}
    for _, id in ipairs(player:getCardIds("hej")) do
      local s = Fk:getCardById(id).suit
      if s == Card.Spade or s == Card.Club then table.insert(blacks, id) end
    end
    if #blacks > 0 then
      local c = room:askToChooseCards(player, {
        target = player,
        flag = "hej",
        min = 1,
        max = 1,
        cancelable = false,
        pattern = ".",
        skill_name = j_jihui.name,
        prompt = "#j_jihui-discard",
      })
      -- 校验黑色，非黑色则重问
      while c and #c > 0 and Fk:getCardById(c[1]).suit ~= Card.Spade and Fk:getCardById(c[1]).suit ~= Card.Club do
        c = room:askToChooseCards(player, {
          target = player,
          flag = "hej",
          min = 1,
          max = 1,
          cancelable = false,
          pattern = ".",
          skill_name = j_jihui.name,
          prompt = "#j_jihui-discard",
        })
      end
      if c and #c > 0 then
        room:throwCard(c, j_jihui.name, player, player)
      end
    else
      -- 无黑色牌：受到1点雷电伤害（无来源）
      room:damage{ to = player, damage = 1, damageType = fk.ThunderDamage, skillName = j_jihui.name }
    end
  end,
})

-- 测试：有黑色牌则弃置
j_jihui:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jihui.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    local b1 = room:printCard("slash", Card.Spade, 3)
    local r1 = room:printCard("peach", Card.Heart, 4)
    room:obtainCard(me, { b1, r1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local black = nil
    for _, id in ipairs(me:getCardIds("hej")) do
      local s = Fk:getCardById(id).suit
      if s == Card.Spade or s == Card.Club then black = id break end
    end
    FkTest.setNextReplies(me, { { black } })
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Draw, to = Player.Play })
    lu.assertEquals(#me:getCardIds("hej"), 1, "饥馑：应弃置一张黑色牌")
    lu.assertEquals(me.hp, 4, "饥馑：弃黑牌后不应受伤")
  end)
end)

-- 测试：无黑色牌则受1点雷电伤害
j_jihui:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jihui.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    -- 只有红色牌
    local r1 = room:printCard("peach", Card.Heart, 4)
    local r2 = room:printCard("jink", Card.Diamond, 5)
    room:obtainCard(me, { r1, r2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Draw, to = Player.Play })
    lu.assertEquals(me.hp, 3, "饥馑：无黑色牌应受1点雷电伤害")
  end)
end)

return j_jihui