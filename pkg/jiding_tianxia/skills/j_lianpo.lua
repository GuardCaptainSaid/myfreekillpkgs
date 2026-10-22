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

-- 炼魄核心结算（死亡触发）：标记、累计次数、复活并将体力值调整至 3-x、摸 4-x 张、
-- 令其失去所有非锁定技（炼魄自身不移除，由幕谋转换统一移除，保证 fk.Death 兜底仍可触发）。
-- 结算完成后若目标拥有【幕谋】则触发幕谋转换（失去炼魄、摸两张、获得诡智）。
local function applyLianpo(room, player, target)
  -- 本次炼魄标记为目标并累计发动次数（至多 3）
  room:setPlayerMark(target, "@j_lianpo_marked", 1)
  room:addPlayerMark(player, "j_lianpo_count", 1)
  local x = player:getMark("j_lianpo_count")
  if x > 3 then x = 3 end

  -- 复活：恢复存活状态，再将体力值调整至 3-x
  room:revivePlayer(target, true, j_lianpo.name)
  room:setPlayerProperty(target, "hp", 3 - x)

  -- 摸 4-x 张牌
  room:drawCards(target, 4 - x, j_lianpo.name)

  -- 失去所有非锁定技（锁定技/限定技保留；#状态技不主动移除；炼魄自身不移除，
  -- 由幕谋转换统一移除，保证即使本次结算异常，fk.Death 上的幕谋兜底仍可触发）
  local lost = {}
  for _, sname in ipairs(target:getSkillNameList()) do
    local sk = Fk.skills[sname]
    if sk and sname:sub(1, 1) ~= "#" and sname ~= "j_lianpo" and
      not sk:hasTag(Skill.Compulsory) and not sk:hasTag(Skill.Limited) then
      table.insert(lost, "-" .. sname) -- handleAddLoseSkills 用 "-" 前缀表示移除
    end
  end
  if #lost > 0 then
    room:handleAddLoseSkills(target, table.concat(lost, "|"), nil, true, true)
  end

  -- 炼魄全部结算完成后：若目标拥有【幕谋】且成为“炼魄”角色，
  -- 由幕谋执行“失去炼魄、摸两张、获得诡智”（顺序：先完成炼魄，再转换）
  if target:hasSkill("j_mumou", true) then
    local ms = Fk.skills["j_mumou"]
    if ms then
      -- __convert 定义在幕谋的 skeleton 上，主技能对象取不到时回退 skeleton
      local conv = ms.__convert or (ms.skeleton and ms.skeleton.__convert)
      if conv then
        conv(target)
      end
    end
  end
end

j_lianpo:addEffect(fk.BeforeGameOverJudge, {
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
    -- 本次死亡被炼魄救活：标记由下方 GameOverJudge 监听消费，
    -- 阻止 game_rule 的 bury() 弃掉刚摸的牌/清除标记/令技能失效
    room:setPlayerMark(target, "j_lianpo_revive_flag", 1)
    applyLianpo(room, player, target)
  end,
})

-- 本次死亡被炼魄救活：死亡结算后续的保护。
-- game_rule 的 GameOverJudge（priority 0）正常判胜后（复活角色 alive，判胜不会发生），
-- 这里（priority -1，自动触发不弹窗）重新设置 SkipGameRule，供 game_rule 的
-- BuryVictim 消费以跳过 bury()（否则会弃掉刚摸的牌/清除标记/令技能失效）。
-- j_lianpo_revive_flag 为一次性标记（不可见标记）：设置后立即清除，正常死亡（未被炼魄救活）不受影响。
j_lianpo:addEffect(fk.GameOverJudge, {
  global = true,
  priority = -1,
  -- 自动执行：跳过 askToSkillInvoke 询问（非锁定触发技默认会询问）
  on_cost = function(self, event, target, player, data)
    return true
  end,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target:getMark("j_lianpo_revive_flag") > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(target, "j_lianpo_revive_flag", 0)
    room:setTag("SkipGameRule", true)
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
    -- BuryVictim 已被 SkipGameRule 跳过，复活后手牌保留（含摸的 3 张）；
    -- comp3 拥有【幕谋】且成为“炼魄”角色，炼魄结算后再由幕谋摸 2 张并获得诡智
    lu.assertEquals(#comp3:getCardIds("h"), 5, "复活后手牌保留（3张）+幕谋联动摸2张")
    lu.assertTrue(comp3:hasSkill("j_guizhi"), "幕谋联动后应获得诡智")
  end)
end)

-- 测试：真实伤害致死（含濒死结算）路径 → 炼魄复活自己 + 幕谋联动转换
j_lianpo:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lianpo.name)
    room:handleAddLoseSkills(me, "j_mumou")
  end)
  FkTest.runInRoom(function()
    -- damage 致死先触发濒死求桃（回复 "" 取消），死亡后再发动炼魄（回复 "1"）
    FkTest.setNextReplies(me, { "", "1" })
    room:damage{ from = comp2, to = me, damage = 5, damageType = fk.NormalDamage }
    lu.assertFalse(me.dead, "真实伤害致死应被炼魄复活")
    lu.assertEquals(me.hp, 2, "复活后体力应调整至 3-x（x=1）")
    lu.assertEquals(me:getMark("@j_lianpo_marked"), 1, "应成为“炼魄”角色")
    lu.assertFalse(me:hasSkill("j_lianpo"), "炼魄结算后应失去炼魄")
    lu.assertTrue(me:hasSkill("j_guizhi"), "最后应获得诡智")
    lu.assertEquals(#me:getCardIds("h"), 5, "炼魄摸3+幕谋摸2=5")
  end)
end)

-- 测试：真实计贾诩武将（自带炼魄+幕谋）死亡 → 炼魄复活自己 → 幕谋转换完整链
j_lianpo:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:prepareGeneral(me, "ji_jiaxu")
    -- testmode 的 attachSkillToPlayers 为空，prepareGeneral 只登记武将，
    -- 需手动附加技能模拟真实开局
    room:handleAddLoseSkills(me, "j_lianpo|j_mumou")
    local ids = me:getCardIds("h")
    if #ids > 0 then
      room:moveCards{ ids = ids, toArea = Card.DiscardPile, moveReason = fk.ReasonPut }
    end
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room:killPlayer{ who = me, killer = comp2 }
    lu.assertFalse(me.dead, "炼魄应复活自己")
    lu.assertEquals(me.hp, 2, "体力应调整至 3-x（x=1）")
    lu.assertEquals(me:getMark("@j_lianpo_marked"), 1, "应成为“炼魄”角色")
    lu.assertFalse(me:hasSkill("j_lianpo"), "炼魄结算后应失去炼魄")
    lu.assertTrue(me:hasSkill("j_guizhi"), "最后应获得诡智")
    lu.assertEquals(#me:getCardIds("h"), 5, "炼魄摸3+幕谋摸2=5")
  end)
end)

-- AI：有角色死亡时主动炼魄（复活并控制其技能）
j_lianpo:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_lianpo.name,
  think = Util.TrueFunc,
})

return j_lianpo
