-- 计杨修·显忌（限定技）
-- 当你进入濒死状态时，你可以令伤害来源（没有来源则默认执行选项1）选择一项：
-- 1、令你摸体力上限张牌并将体力值回复至1点，然后直到你的下个回合结束，防止你受到的伤害；
--    你的下个回合开始时你获得技能【咆哮】和【狂骨】，回合结束时你失去所有体力；
-- 2、令你将体力回复至上限并获得技能【空城】。
local j_xianji = fk.CreateSkill {
  name = "j_xianji",
  tags = { Skill.Limited },
}

-- 自带【狂骨】副本（避免跨包依赖）
local j_kuanggu = fk.CreateSkill {
  name = "j_kuanggu",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_xianji"] = "显忌",
  [":j_xianji"] = "限定技，当你进入濒死状态时，你可以令伤害来源（没有来源则默认执行选项1）选择一项：1、令你摸体力上限张牌并将体力值回复至1点，然后直到你的下个回合结束，防止你受到的伤害；你的下个回合开始时你获得技能【咆哮】和【狂骨】，回合结束时你失去所有体力；2、令你将体力回复至上限并获得技能【空城】。",

  ["#j_xianji-invoke"] = "显忌：是否发动？由伤害来源选择一项",
  ["#j_xianji-choice"] = "显忌：请选择一项",
  ["j_xianji_opt1"] = "令其摸体力上限张牌、体力回复至1点，其下回合获得【咆哮】【狂骨】，该回合结束时失去所有体力",
  ["j_xianji_opt2"] = "令其将体力回复至上限并获得技能【空城】",

  ["j_kuanggu"] = "狂骨",
  [":j_kuanggu"] = "锁定技，当你对距离1以内的一名角色造成伤害后，你回复等量体力。",
}

-- 选项1：摸体力上限张牌、回复至1点、获得防伤与狂暴标记
local function doOption1(room, player)
  room:drawCards(player, player.maxHp, j_xianji.name)
  if player.dead then return end
  if player.hp < 1 then
    room:recover{
      who = player,
      num = 1 - player.hp,
      recoverBy = player,
      skillName = j_xianji.name,
    }
  end
  if player.dead then return end
  room:setPlayerMark(player, "j_xianji_protect", 1)
  room:setPlayerMark(player, "j_xianji_berserk", 1)
end

-- 选项2：体力回复至上限并获得【空城】
local function doOption2(room, player)
  if player.hp < player.maxHp then
    room:recover{
      who = player,
      num = player.maxHp - player.hp,
      recoverBy = player,
      skillName = j_xianji.name,
    }
  end
  if player.dead then return end
  room:handleAddLoseSkills(player, "kongcheng", nil, false, true)
end

-- 濒死时发动
j_xianji:addEffect(fk.EnterDying, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_xianji.name) and not player.dead
      and player:getMark("j_xianji_used") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_xianji.name,
      prompt = "#j_xianji-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_xianji_used", 1)
    -- 伤害来源；没有来源则默认执行选项1
    local source = (data.damage and data.damage.from) or data.killer
    if not source or source.dead or source == player then
      doOption1(room, player)
      return
    end
    local choice = room:askToChoice(source, {
      choices = { "j_xianji_opt1", "j_xianji_opt2" },
      skill_name = j_xianji.name,
      prompt = "#j_xianji-choice",
      cancelable = false,
    })
    if choice == "j_xianji_opt2" then
      doOption2(room, player)
    else
      doOption1(room, player)
    end
  end,
})

-- 选项1后续：直到你的下个回合结束，防止你受到的伤害
j_xianji:addEffect(fk.DamageInflicted, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:getMark("j_xianji_protect") > 0
  end,
  on_use = function(self, event, target, player, data)
    data:preventDamage()
  end,
})

-- 你的下个回合开始时：获得【咆哮】和【狂骨】
j_xianji:addEffect(fk.TurnStart, {
  global = true,
  anim_type = "offensive",
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:getMark("j_xianji_berserk") > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:handleAddLoseSkills(player, "paoxiao|" .. j_kuanggu.name, nil, false, true)
    room:setPlayerMark(player, "j_xianji_berserk_on", 1)
  end,
})

-- 该回合结束时：失去所有体力，收回所授技能并清除标记
j_xianji:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "offensive",
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:getMark("j_xianji_berserk_on") > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_xianji_berserk", 0)
    room:setPlayerMark(player, "j_xianji_berserk_on", 0)
    room:setPlayerMark(player, "j_xianji_protect", 0)
    room:handleAddLoseSkills(player, "-paoxiao|-" .. j_kuanggu.name, nil, false, true)
    -- 失去所有体力（流失体力，很可能进入濒死）
    if not player.dead and player.hp > 0 then
      room:loseHp(player, player.hp, j_xianji.name)
    end
  end,
})

-- 狂骨（副本）：锁定技，你对距离1以内的角色造成伤害后回复等量体力
j_kuanggu:addEffect(fk.Damage, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_kuanggu.name) and not player.dead
      and data.to ~= player and data.to ~= nil and player:isWounded()
      and player:distanceTo(data.to) <= 1
  end,
  trigger_times = function(self, event, target, player, data)
    return data.damage
  end,
  on_use = function(self, event, target, player, data)
    player.room:recover{
      who = player,
      num = 1,
      recoverBy = player,
      skillName = j_kuanggu.name,
    }
  end,
})

-- 测试：濒死无来源 → 默认选项1（摸X张、回复至1、防伤、下回合获咆哮狂骨、回合末失去所有体力）
j_xianji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xianji.name)
    me.maxHp = 4
    me.hp = 0
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params)
      if who == me then return true end
      return origInvoke(self, who, params)
    end
    local hand = #me:getCardIds("h")
    local dying = DyingData:new{ who = me }
    room.logic:trigger(fk.EnterDying, me, dying)
    room.askToSkillInvoke = origInvoke

    lu.assertEquals(#me:getCardIds("h"), hand + 4, "应摸体力上限张牌")
    lu.assertEquals(me.hp, 1, "体力应回复至1点")
    lu.assertTrue(me:getMark("j_xianji_protect") > 0, "应获得防伤标记")
    lu.assertTrue(me:getMark("j_xianji_used") > 0, "限定技应记录已使用")

    -- 防止伤害
    local dmg = DamageData:new{ from = room.players[2], to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, me, dmg)
    lu.assertTrue(dmg.prevented, "下个回合结束前伤害应被防止")

    -- 下个回合开始：获得咆哮与狂骨
    room.current = me
    me.phase = Player.Start
    room.logic:trigger(fk.TurnStart, me, {})
    lu.assertTrue(me:hasSkill("paoxiao"), "应获得【咆哮】")
    lu.assertTrue(me:hasSkill("j_kuanggu"), "应获得【狂骨】")

    -- 回合结束：失去所有体力、收回技能、清除标记（mock 掉体力流失避免濒死结算）
    local loseHpArgs
    local origLoseHp = room.loseHp
    room.loseHp = function(self, who, num, reason)
      loseHpArgs = { who = who, num = num }
    end
    room.logic:trigger(fk.TurnEnd, me, {})
    room.loseHp = origLoseHp

    lu.assertEquals(loseHpArgs.num, me.hp, "应失去所有体力")
    lu.assertFalse(me:hasSkill("paoxiao"), "回合结束应收回【咆哮】")
    lu.assertFalse(me:hasSkill("j_kuanggu"), "回合结束应收回【狂骨】")
    lu.assertEquals(me:getMark("j_xianji_protect"), 0, "防伤标记应清除")
  end)
end)

-- 测试：有伤害来源 → 来源选择选项2（回满体力并获得【空城】）
j_xianji:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xianji.name)
    me.maxHp = 4
    me.hp = 0
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChoice = room.askToChoice
    room.askToSkillInvoke = function(self, who, params)
      if who == me then return true end
      return origInvoke(self, who, params)
    end
    room.askToChoice = function(self, who, params)
      if who == comp2 then return "j_xianji_opt2" end
      return origChoice(self, who, params)
    end
    local dying = DyingData:new{ who = me, damage = { from = comp2 } }
    room.logic:trigger(fk.EnterDying, me, dying)
    room.askToSkillInvoke = origInvoke
    room.askToChoice = origChoice

    lu.assertEquals(me.hp, me.maxHp, "体力应回复至上限")
    lu.assertTrue(me:hasSkill("kongcheng"), "应获得【空城】")
    lu.assertEquals(me:getMark("j_xianji_protect"), 0, "选项2不应有防伤标记")

    -- 限定技整局限一次
    local hand = #me:getCardIds("h")
    me.hp = 0
    local dying2 = DyingData:new{ who = me }
    room.logic:trigger(fk.EnterDying, me, dying2)
    lu.assertEquals(#me:getCardIds("h"), hand, "限定技不应再次发动")
  end)
end)

-- 测试：狂骨——对距离1以内角色造成伤害后回复等量体力
j_kuanggu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_kuanggu.name)
    room:loseHp(me, 2)
  end)
  FkTest.runInRoom(function()
    local before = me.hp
    room:damage{ from = me, to = room.players[2], damage = 1 }
    lu.assertEquals(me.hp, before + 1, "对距离1以内角色造成伤害应回复1点体力")
  end)
end)

return j_xianji
