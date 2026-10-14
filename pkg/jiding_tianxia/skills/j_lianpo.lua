local j_lianpo = fk.CreateSkill {
  name = "j_lianpo",
}

Fk:loadTranslationTable{
  ["j_lianpo"] = "炼魄",
  [":j_lianpo"] = "一名角色死亡时，若其未成为过该技能的目标，你可以令其将体力值调整至3-×，摸4-×张牌并令其失去所有非锁定技。(X为此技能本局游戏中发动过的次数且至多为3)",

  ["#j_lianpo-invoke"] = "炼魄：是否令其还阳？",
  ["@j_lianpo_marked"] = "炼魄",

  ["$j_lianpo1"] = "亡者魂魄，尽归吾掌！",
  ["$j_lianpo2"] = "炼汝残魄，供吾驱策！",
}

j_lianpo:addEffect(fk.Death, {
  anim_type = "defensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    -- ignoreAlive=true：自己死亡时（死亡者技能默认失效）也能响应炼魄
    if not player:hasSkill(j_lianpo.name, true, true) then return false end
    if not target or target.dead == false then return false end
    -- 可指定任意死亡角色为目标，包括自己
    if target:getMark("@j_lianpo_marked") > 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_lianpo.name, prompt = "#j_lianpo-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 跳过后续 BuryVictim 的埋牌与奖惩（GameRule 检测该 tag 后自动清除）
    room:setTag("SkipGameRule", true)
    -- 标记为目标并累计发动次数（至多 3）
    room:setPlayerMark(target, "@j_lianpo_marked", 1)
    room:addPlayerMark(player, "j_lianpo_count", 1)
    local x = player:getMark("j_lianpo_count")
    if x > 3 then x = 3 end

    -- 复活：恢复存活状态，再将体力值调整至 3-x
    room:revivePlayer(target, true, j_lianpo.name)
    room:setPlayerProperty(target, "hp", 3 - x)

    -- 摸 4-x 张牌
    room:drawCards(target, 4 - x, j_lianpo.name)

    -- 失去所有非锁定技（锁定技/限定技保留）
    local lost = {}
    for _, sname in ipairs(target:getSkillNameList()) do
      local sk = Fk.skills[sname]
      if sk and not sk:hasTag(Skill.Compulsory) and not sk:hasTag(Skill.Limited) then
        table.insert(lost, "-" .. sname) -- handleAddLoseSkills 用 "-" 前缀表示移除
      end
    end
    if #lost > 0 then
      room:handleAddLoseSkills(target, table.concat(lost, "|"), nil, true, true)
    end
  end,
})

-- 测试：死亡时发动炼魄 → 复活、调体力、摸牌
j_lianpo:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lianpo.name)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room:killPlayer{ who = comp3, killer = comp2 }
    lu.assertFalse(comp3.dead, "炼魄应令死亡角色复活")
    lu.assertEquals(comp3.hp, 2, "体力值应调整至 3-x（x=1）")
    lu.assertEquals(#comp3:getCardIds("h"), 3, "应摸 4-x=3 张牌")
    lu.assertEquals(comp3:getMark("@j_lianpo_marked"), 1, "应记录成为过目标")
    lu.assertEquals(me:getMark("j_lianpo_count"), 1, "应累计发动次数")
  end)
end)

-- 测试：不发动炼魄则角色正常死亡
j_lianpo:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lianpo.name)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "" })
    room:killPlayer{ who = comp3, killer = comp2 }
    lu.assertTrue(comp3.dead, "拒绝发动时角色应正常死亡")
    lu.assertEquals(comp3:getMark("@j_lianpo_marked"), 0, "不应记录目标")
  end)
end)

-- 测试：自己死亡时可发动炼魄复活自己
j_lianpo:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lianpo.name)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room:killPlayer{ who = me, killer = comp2 }
    lu.assertFalse(me.dead, "自己死亡时可被炼魄复活")
    lu.assertEquals(me.hp, 2, "自己复活后体力值应调整至 3-x（x=1）")
    lu.assertEquals(me:getMark("@j_lianpo_marked"), 1, "应记录自己成为过目标")
  end)
end)

-- 测试：炼魄后失去非锁定技、保留锁定技
j_lianpo:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lianpo.name)
    room:handleAddLoseSkills(comp3, "j_mumou|j_guizhi") -- 锁定技 + 普通技
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room:killPlayer{ who = comp3, killer = comp2 }
    lu.assertFalse(comp3.dead, "炼魄应令角色复活")
    lu.assertTrue(comp3:hasSkill("j_mumou"), "锁定技应保留")
    lu.assertFalse(comp3:hasSkill("j_guizhi"), "非锁定技应被移除")
    -- BuryVictim 已被 SkipGameRule 跳过，复活后手牌保留（含摸的 3 张）
    lu.assertEquals(#comp3:getCardIds("h"), 3, "复活后手牌应保留不被埋葬")
  end)
end)

-- AI：有角色死亡时主动炼魄（复活并控制其技能）
j_lianpo:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_lianpo.name,
  think = Util.TrueFunc,
})

return j_lianpo