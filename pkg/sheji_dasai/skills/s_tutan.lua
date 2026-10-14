-- 舒邵四号·涂炭
-- 准备阶段，若你的“粮”数量不小于3，你减1点体力上限；当你受到伤害时，你可以弃置一张牌或“粮”，将此伤害转移给伤害来源。
local s_tutan = fk.CreateSkill {
  name = "s_tutan",
}

Fk:loadTranslationTable{
  ["s_tutan"] = "涂炭",
  [":s_tutan"] = "准备阶段，若你的“粮”数量不小于3，你减1点体力上限；当你受到伤害时，你可以弃置一张牌或“粮”，将此伤害转移给伤害来源。",

  ["#s_tutan-invoke"] = "涂炭：是否弃置一张牌或“粮”，将此伤害转移给伤害来源？",
  ["#s_tutan-choice"] = "涂炭：选择弃置方式",
  ["s_tutan_card"] = "弃置一张牌",
  ["s_tutan_liang"] = "弃置一张“粮”",
  ["s_tutan_cancel"] = "不发动",

  ["$s_tutan1"] = "民既涂炭，何惜此身！",
  ["$s_tutan2"] = "以彼之矛，还施彼身！",
}

-- 准备阶段：粮≥3减1体力上限
s_tutan:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    if not player:hasSkill(s_tutan.name) then return false end
    if data.to ~= Player.Start then return false end
    return player:getMark("@s_sanliang4_liang") >= 3
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:changeMaxHp(player, -1)
  end,
})

-- 受到伤害时：弃一张牌或粮，将伤害转移给来源
s_tutan:addEffect(fk.DamageInflicted, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    if not player:hasSkill(s_tutan.name) then return false end
    if data.damage <= 0 then return false end
    if not data.from or data.from.dead then return false end
    return #player:getCardIds("he") > 0 or player:getMark("@s_sanliang4_liang") > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    return room:askToSkillInvoke(player, { skill_name = s_tutan.name, prompt = "#s_tutan-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = room:askToChoice(player, {
      skill_name = s_tutan.name,
      choices = { "s_tutan_card", "s_tutan_liang" },
      cancelable = true,
      prompt = "#s_tutan-choice",
    })
    if choice == "Cancel" then return end
    if choice == "s_tutan_card" then
      local c = room:askToDiscard(player, { min_num = 1, max_num = 1, include_equip = true, skill_name = s_tutan.name, cancelable = false })
      if not c or #c == 0 then return end
    else
      room:setPlayerMark(player, "@s_sanliang4_liang", player:getMark("@s_sanliang4_liang") - 1)
    end
    -- 转移伤害给伤害来源
    data.to = data.from
  end,
})

-- 测试1：准备阶段粮≥3减1体力上限
s_tutan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_tutan.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    room:setPlayerMark(me, "@s_sanliang4_liang", 3)
  end)
  FkTest.runInRoom(function()
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Finish, to = Player.Start })
    lu.assertEquals(me.maxHp, 3, "涂炭：粮≥3应减1点体力上限")
  end)
end)

-- 测试2：受伤害时弃“粮”将伤害转移给来源
s_tutan:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_tutan.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 3
    room.current = me
    room:setPlayerMark(me, "@s_sanliang4_liang", 1)
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1", { "s_tutan_liang" }, "1" })
    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, me, dmg)
    if dmg.to ~= comp2 then
      print("TEST_FAILURE: 涂炭转移失败 to=" .. tostring(dmg.to))
      error("涂炭：伤害应转移给来源")
    end
    if me:getMark("@s_sanliang4_liang") ~= 0 then
      print("TEST_FAILURE: 涂炭粮未减 mark=" .. tostring(me:getMark("@s_sanliang4_liang")))
      error("涂炭：应弃1枚粮")
    end
    print("TEST_OK: 涂炭转移成功")
  end)
end)

return s_tutan