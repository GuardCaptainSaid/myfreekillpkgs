-- 君公孙瓒·破阵（限定技）
-- 出牌阶段开始时，你可以弃置所有"骑"，对攻击范围内的所有其他角色各造成1点伤害。若你以此法对至少3名角色造成伤害，你获得【趫猛】。
local j_pozheng = fk.CreateSkill {
  name = "j_pozheng",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["j_pozheng"] = "破阵",
  [":j_pozheng"] = "限定技，出牌阶段开始时，你可以弃置所有“骑”，对攻击范围内的所有其他角色各造成1点伤害。若你以此法对至少3名角色造成伤害，你获得【趫猛】。",

  ["#j_pozheng-invoke"] = "破阵：是否弃置所有“骑”并对攻击范围内角色各造成1点伤害？",
  ["@j_pozheng"] = "破阵",

  ["$j_pozheng1"] = "白马长枪，破阵夺旗！",
  ["$j_pozheng2"] = "一鼓作气，踏平敌营！",
}

j_pozheng:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_pozheng.name) or player.dead then return false end
    if player:getMark("@j_pozheng_used") > 0 then return false end
    if data.to ~= Player.Play then return false end
    return player:getMark("@j_tuji_qi") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_pozheng.name, prompt = "#j_pozheng-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "@j_pozheng_used", 1)
    -- 弃置所有骑
    room:setPlayerMark(player, "@j_tuji_qi", 0)
    -- 对攻击范围内的所有其他角色各造成1点伤害
    local count = 0
    for _, p in ipairs(room:getOtherPlayers(player)) do
      if not p.dead and player:inMyAttackRange(p) then
        room:damage{ from = player, to = p, damage = 1, damageType = fk.NormalDamage, skillName = j_pozheng.name }
        if not p.dead then
          count = count + 1
        end
      end
    end
    -- 至少3名角色造成伤害 → 获得趫猛
    if count >= 3 then
      room:handleAddLoseSkills(player, "j_qiaomeng", nil, false, true)
    end
  end,
})

-- 测试：对攻击范围内角色造成伤害并计数获得趫猛
j_pozheng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pozheng.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "@j_tuji_qi", 3)
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Draw, to = Player.Play })
    lu.assertEquals(me:getMark("@j_tuji_qi"), 0, "破阵：应弃置所有骑")
    lu.assertEquals(me:getMark("@j_pozheng_used"), 1, "破阵：限定技应记录已用")
    -- 8人房攻击范围1 → 相邻2名角色受伤 → count<3 → 不获趫猛
    lu.assertFalse(me:hasSkill("j_qiaomeng"), "破阵：不足3名角色不应获得趫猛")
  end)
end)

-- 测试：武器攻击范围覆盖3人 → 获得趫猛
j_pozheng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pozheng.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "@j_tuji_qi", 3)
    -- 装备武器（如诸葛连弩攻击范围1不够 → 用青釭剑/贯石斧范围2 → 覆盖2人；用麒麟弓范围5 → 覆盖7人）
    local bow = room:printCard("crossbow", Card.Spade, 2)
    room:moveCardTo(bow, Player.Equip, me, fk.ReasonPut, "test")
    -- 调整：crossbow 攻击范围1 → 只有2人 → 构造专用范围：改用麒麟弓（guding? 用范围大的武器）
    -- 直接提升 me 攻击范围：用突骑选项2（+maxHp=4）→ 覆盖全场
    room:setPlayerMark(me, "@j_tuji_opt2-turn", 1)
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Draw, to = Player.Play })
    lu.assertTrue(me:hasSkill("j_qiaomeng"), "破阵：对至少3名角色造成伤害应获得趫猛")
  end)
end)

return j_pozheng