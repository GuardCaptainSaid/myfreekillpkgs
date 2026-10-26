-- 计庞统·涅槃（转换技，锁定技）
-- 阳：当你进入濒死时，你将体力值回复至上限，弃置区域内的所有牌并摸四张牌，然后将武将牌复原；
-- 阴：出牌阶段开始时，若你的体力值为1，则你可横置你的武将牌。
local j_pangtong_niepan = fk.CreateSkill {
  name = "j_pangtong_niepan",
  tags = { Skill.Switch, Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_pangtong_niepan"] = "涅槃",
  [":j_pangtong_niepan"] = "转换技，锁定技。阳：当你进入濒死时，你将体力值回复至上限，弃置区域内的所有牌并摸四张牌，" ..
    "然后将武将牌复原；阴：出牌阶段开始时，若你的体力值为1，则你可横置你的武将牌。",
  [":j_pangtong_niepan_yang"] = "转换技，锁定技。" ..
    "<font color='#E0DB2F'>阳：当你进入濒死时，你将体力值回复至上限，弃置区域内的所有牌并摸四张牌，然后将武将牌复原；</font>" ..
    "<font color='grey'>阴：出牌阶段开始时，若你的体力值为1，则你可横置你的武将牌。</font>",
  [":j_pangtong_niepan_yin"] = "转换技，锁定技。" ..
    "<font color='grey'>阳：当你进入濒死时，你将体力值回复至上限，弃置区域内的所有牌并摸四张牌，然后将武将牌复原；</font>" ..
    "<font color='#E0DB2F'>阴：出牌阶段开始时，若你的体力值为1，则你可横置你的武将牌。</font>",

  ["#j_pangtong_niepan-invoke"] = "涅槃：是否横置你的武将牌？",

  ["$j_pangtong_niepan1"] = "凤雏涅槃，浴火重生！",
  ["$j_pangtong_niepan2"] = "死生有命，何惧一死！",
}

local function isYang(player)
  return player:getSwitchSkillState(j_pangtong_niepan.name) == fk.SwitchYang
end

-- 阳：进入濒死 → 回复至上限、弃置区域内所有牌、摸四张、复原武将牌（锁定，不询问）
j_pangtong_niepan:addEffect(fk.EnterDying, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_pangtong_niepan.name) and isYang(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.maxHp > player.hp then
      room:recover{
        who = player,
        num = player.maxHp - player.hp,
        recoverBy = player,
        skillName = j_pangtong_niepan.name,
      }
    end
    if player.dead then return end

    player:throwAllCards("hej", j_pangtong_niepan.name)
    if player.dead then return end

    room:drawCards(player, 4, j_pangtong_niepan.name)
    if player.dead then return end

    player:reset()
  end,
})

-- 阴：出牌阶段开始时，若体力值为1，可横置武将牌
j_pangtong_niepan:addEffect(fk.EventPhaseStart, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or not player:hasSkill(j_pangtong_niepan.name) then return false end
    if player.phase ~= Player.Play then return false end
    if isYang(player) then return false end
    return player.hp == 1 and not player.chained
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_pangtong_niepan.name,
      prompt = "#j_pangtong_niepan-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    if player.dead or player.chained then return end
    player:setChainState(true)
  end,
})

-- 测试1：阳形态进入濒死 → 回复至上限、弃光区域内牌、摸四张、复原武将牌，并翻转为阴
j_pangtong_niepan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_niepan.name)
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_pangtong_niepan.name, 0)  -- 阳
    me.hp = 0
    me.chained = true
    local c1 = room:printCard("slash", Card.Spade, 3)
    local c2 = room:printCard("jink", Card.Heart, 4)
    room:obtainCard(me, { c1.id, c2.id }, true, fk.ReasonDraw, me, "test")
    -- 清空手牌以外的干扰：牌堆保证够摸
    local before_total = #me:getCardIds("hej")

    room.logic:trigger(fk.EnterDying, me, { who = me })

    lu.assertEquals(me.hp, me.maxHp, "应回复体力至上限")
    lu.assertEquals(#me:getCardIds("hej"), 4, "弃光区域内所有牌后应正好摸四张")
    lu.assertFalse(me.chained, "武将牌应被复原（解除横置）")
    lu.assertEquals(me:getSwitchSkillState(j_pangtong_niepan.name), fk.SwitchYin,
      "发动后应翻转为阴形态")
  end)
end)

-- 测试2：阴形态、体力为1时出牌阶段开始 → 可横置武将牌，并翻回阳
j_pangtong_niepan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_niepan.name)
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_pangtong_niepan.name, 1)  -- 阴
    me.hp = 1
    me.chained = false
    me.phase = Player.Play

    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.EventPhaseStart, me, { who = me, phase = Player.Play })

    lu.assertTrue(me.chained, "应横置武将牌")
    lu.assertEquals(me:getSwitchSkillState(j_pangtong_niepan.name), fk.SwitchYang,
      "发动后应翻回阳形态")
  end)
end)

-- 测试3：阳形态下不会触发阴形态效果；体力不为1时阴形态也不触发
j_pangtong_niepan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_niepan.name)
    local eff = j_pangtong_niepan.effects[2]
    -- 阳形态
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_pangtong_niepan.name, 0)
    me.hp = 1
    me.chained = false
    me.phase = Player.Play
    lu.assertFalse(eff:triggerable(nil, me, me, {}), "阳形态不应触发阴效果")
    -- 阴形态但体力不为1
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_pangtong_niepan.name, 1)
    me.hp = 2
    lu.assertFalse(eff:triggerable(nil, me, me, {}), "体力不为1时不应触发")
    -- 阴形态且体力为1
    me.hp = 1
    lu.assertTrue(eff:triggerable(nil, me, me, {}), "阴形态且体力为1应可触发")
  end)
end)

return j_pangtong_niepan
