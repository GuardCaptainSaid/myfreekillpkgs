-- 君公孙瓒·退守
-- 本局游戏每项限一次，当你受到伤害后，你可弃一枚"骑"，令来源角色选择：1.弃置两张手牌；2.令你回复1点体力并摸一张牌；3、你对其造成1点雷电伤害并弃置其所有装备；4、令你获得其一张牌并摸一张牌；5、令其失去随机一个技能直至一名角色死亡；6、令你选择场上一个技能获得。
local j_tuishou = fk.CreateSkill {
  name = "j_tuishou",
}

Fk:loadTranslationTable{
  ["j_tuishou"] = "退守",
  [":j_tuishou"] = "本局游戏每项限一次，当你受到伤害后，你可弃一枚“骑”，令来源角色选择：1.弃置两张手牌；2.令你回复1点体力并摸一张牌；3.你对其造成1点雷电伤害并弃置其所有装备；4.令你获得其一张牌并摸一张牌；5.令其失去随机一个技能直至一名角色死亡；6.令你选择场上一个技能获得。",

  ["#j_tuishou-invoke"] = "退守：是否弃一枚“骑”发动退守？",
  ["#j_tuishou-choice"] = "退守：令来源角色选择一项",
  ["#j_tuishou-discard"] = "退守：弃置两张手牌",
  ["#j_tuishou-get"] = "退守：选择获得其一张牌",
  ["#j_tuishou-skill"] = "退守：选择一个场上技能获得",

  ["$j_tuishou1"] = "避其锋芒，徐图再战！",
  ["$j_tuishou2"] = "退守坚城，伺机而动！",
}

local opt_marks = { "@j_tuishou_opt1", "@j_tuishou_opt2", "@j_tuishou_opt3", "@j_tuishou_opt4", "@j_tuishou_opt5", "@j_tuishou_opt6" }
local opt_names = { "1", "2", "3", "4", "5", "6" }

-- 随机失去的技能恢复（任一角色死亡时）
j_tuishou:addEffect(fk.Death, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    local lost = player.room:getTag("j_tuishou_lost")
    return lost and #lost > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local lost = room:getTag("j_tuishou_lost") or {}
    for _, info in ipairs(lost) do
      local p = room:getPlayerById(info[1])
      if p and not p.dead and info[2] then
        room:handleAddLoseSkills(p, info[2], nil, false, true)
      end
    end
    room:setTag("j_tuishou_lost", {})
  end,
})

j_tuishou:addEffect(fk.DamageFinished, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_tuishou.name) or player.dead then return false end
    if not data.from or data.from == player then return false end
    return player:getMark("@j_tuji_qi") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_tuishou.name, prompt = "#j_tuishou-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    -- 弃一枚骑
    room:setPlayerMark(player, "@j_tuji_qi", player:getMark("@j_tuji_qi") - 1)
    -- 六选一（已用置灰）
    local available = {}
    local all = {}
    for i = 1, 6 do
      all[i] = opt_names[i]
      if player:getMark(opt_marks[i]) == 0 then
        table.insert(available, opt_names[i])
      end
    end
    if #available == 0 then return end
    local choice = room:askToChoice(from, { choices = available, all_choices = all, skill_name = j_tuishou.name, prompt = "#j_tuishou-choice" })
    room:setPlayerMark(player, opt_marks[tonumber(choice)], 1)
    if choice == "1" then
      -- 来源弃两张手牌
      local h = from:getCardIds("h")
      local n = math.min(2, #h)
      if n > 0 then
        local c = room:askToChooseCards(from, {
          target = from,
          flag = "h",
          min = n,
          max = n,
          cancelable = false,
          pattern = ".",
          skill_name = j_tuishou.name,
          prompt = "#j_tuishou-discard",
        })
        if c and #c > 0 then
          room:throwCard(c, j_tuishou.name, from, from)
        end
      end
    elseif choice == "2" then
      -- 你回复1体力并摸1
      room:recover{ who = player, num = 1 }
      if not player.dead then
        player:drawCards(1, j_tuishou.name)
      end
    elseif choice == "3" then
      -- 你对其造成1雷伤并弃置其所有装备
      room:damage{ from = player, to = from, damage = 1, damageType = fk.ThunderDamage, skillName = j_tuishou.name }
      local eqs = from:getCardIds("e")
      if #eqs > 0 then
        room:throwCard(eqs, j_tuishou.name, from, from)
      end
    elseif choice == "4" then
      -- 你获得其一张牌并摸1
      if not from:isAllNude() then
        local c = room:askToChooseCards(player, {
          target = from,
          flag = "hej",
          min = 1,
          max = 1,
          cancelable = false,
          pattern = ".",
          skill_name = j_tuishou.name,
          prompt = "#j_tuishou-get",
        })
        if c and #c > 0 then
          room:obtainCard(player, c, true, fk.ReasonGive, from, j_tuishou.name)
        end
      end
      if not player.dead then
        player:drawCards(1, j_tuishou.name)
      end
    elseif choice == "5" then
      -- 令其失去随机一个技能直至一名角色死亡
      local candidates = {}
      for _, sname in ipairs(from:getSkillNameList()) do
        local sk = Fk.skills[sname]
        if sk and not sk:hasTag(Skill.Compulsory) and not sk:hasTag(Skill.Limited) and not sname:startsWith("#") then
          table.insert(candidates, sname)
        end
      end
      if #candidates > 0 then
        local sname = table.randomPick(candidates)
        room:handleAddLoseSkills(from, "-" .. sname, nil, false, true)
        local lost = room:getTag("j_tuishou_lost") or {}
        table.insert(lost, { from.id, sname })
        room:setTag("j_tuishou_lost", lost)
      end
    elseif choice == "6" then
      -- 令你选择场上一个技能获得
      local pool = {}
      local seen = {}
      for _, p in ipairs(room.alive_players) do
        for _, sname in ipairs(p:getSkillNameList()) do
          if not sname:startsWith("#") and not seen[sname] then
            seen[sname] = true
            table.insert(pool, sname)
          end
        end
      end
      if #pool > 0 then
        local sname = room:askToChoice(player, { choices = pool, skill_name = j_tuishou.name, prompt = "#j_tuishou-skill" })
        room:handleAddLoseSkills(player, sname, nil, false, true)
      end
    end
  end,
})

-- 测试：受伤后弃骑，来源选2（回复+摸1）
j_tuishou:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_tuishou.name)
    me.maxHp = 4
    me.hp = 2
    room:setPlayerMark(me, "@j_tuji_qi", 2)
  end)

  FkTest.runInRoom(function()
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1" })
    FkTest.setNextReplies(comp2, { { "2" } })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me:getMark("@j_tuji_qi"), 1, "退守：应弃1枚骑")
    lu.assertEquals(me.hp, 2, "退守：受伤1点后回复1点应保持2")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 1, "退守：选项2应摸1张牌")
    lu.assertEquals(me:getMark("@j_tuishou_opt2"), 1, "退守：选项2应记录已用")
  end)
end)

-- 测试：来源选5 → 失去随机技能；任一角色死亡后恢复
j_tuishou:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_tuishou.name)
    me.maxHp = 4
    me.hp = 2
    room:setPlayerMark(me, "@j_tuji_qi", 1)
    -- comp2 有一个普通技能（用突骑做样例）
    room:handleAddLoseSkills(comp2, "j_tuji")
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    FkTest.setNextReplies(comp2, { { "5" } })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    local lost = room:getTag("j_tuishou_lost")
    lu.assertTrue(lost and #lost > 0, "退守：选项5应记录失去的技能")
    lu.assertFalse(comp2:hasSkill("j_tuji"), "退守：来源应失去随机技能")
    -- 任一角色死亡 → 恢复
    room:killPlayer{ who = comp3, killer = comp2 }
    lu.assertTrue(comp2:hasSkill("j_tuji"), "退守：角色死亡后应恢复失去的技能")
    lu.assertEquals(#(room:getTag("j_tuishou_lost") or {}), 0, "退守：恢复后应清空记录")
  end)
end)

return j_tuishou