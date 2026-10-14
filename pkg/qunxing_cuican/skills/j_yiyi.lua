local j_yiyi = fk.CreateSkill {
  name = "j_yiyi",
}

Fk:loadTranslationTable{
  ["j_yiyi"] = "疑异",
  [":j_yiyi"] = "出牌阶段限一次，你可以移去一枚“谋”，令一名角色摸两张牌并对其造成一点伤害。你进入濒死状态时，你可以移去一枚“谋”，回复一点体力。",

  ["#j_yiyi-mou"] = "疑异：选择一枚要移去的“谋”",
  ["#j_yiyi-target"] = "疑异：选择一名角色摸两张牌并对其造成一点伤害",
  ["#j_yiyi-dying"] = "疑异：是否移去一枚“谋”回复一点体力？",

  ["$j_yiyi1"] = "生疑生隙，此消彼长。",
  ["$j_yiyi2"] = "攻心为上，攻城为下。",
}

-- 主动技：出牌阶段限一次，移去一枚“谋”令一名角色摸两张并受1点伤害
j_yiyi:addEffect("active", {
  anim_type = "control",
  card_num = 0,
  can_use = function(self, player)
    return player.phase == Player.Play and #player:getPile("j_mou") > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local mou = player:getPile("j_mou")
    if #mou == 0 then return end

    -- 移去一枚“谋”
    local id = room:askToChooseCard(player, {
      target = player,
      flag = { card_data = { { "$PlayerSpecial", mou } } },
      skill_name = j_yiyi.name,
      prompt = "#j_yiyi-mou",
    })
    if not id then return end
    room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonPut, j_yiyi.name, nil, false, player, nil, player)

    -- 令一名角色摸两张牌并对其造成一点伤害
    local targets = {}
    for _, p in ipairs(room:getOtherPlayers(player, false)) do
      if not p.dead then table.insert(targets, p) end
    end
    if #targets == 0 then return end
    local target = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      cancelable = false,
      skill_name = j_yiyi.name,
      prompt = "#j_yiyi-target",
    })[1]
    if not target then return end

    target:drawCards(2, j_yiyi.name)
    room:damage{ from = player, to = target, damage = 1, damageType = fk.NormalDamage, skillName = j_yiyi.name }
  end,
})

-- 被动：进入濒死时可移去一枚“谋”回复一点体力（弹窗询问时机）
j_yiyi:addEffect(fk.EnterDying, {
  global = true,
  anim_type = "defense",
  can_trigger = function(self, event, target, player, data)
    if data.who ~= player or player.dead then return false end
    if not player:hasSkill(j_yiyi.name) then return false end
    return #player:getPile("j_mou") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_yiyi.name, prompt = "#j_yiyi-dying" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local mou = player:getPile("j_mou")
    if #mou == 0 then return end
    room:moveCardTo(mou[1], Card.DiscardPile, nil, fk.ReasonPut, j_yiyi.name, nil, false, player, nil, player)
    room:recover{ who = player, num = 1, recoverBy = player, skillName = j_yiyi.name }
  end,
})

j_yiyi:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_yiyi.name,
  think = function(self, player)
    return player.phase == Player.Play and #player:getPile("j_mou") > 0
  end,
})

-- 测试：出牌阶段移去一枚谋 → 目标摸2并受1点伤害
j_yiyi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yiyi.name)
    local mou1 = room:printCard("slash", Card.Spade, 5)
    me:addToPile("j_mou", mou1.id, true, j_yiyi.name)
  end)

  FkTest.runInRoom(function()
    room.current = me
    local hpBefore = comp2.hp
    local handBefore = #comp2:getCardIds("h")
    FkTest.setNextReplies(me, { me:getPile("j_mou")[1], FkTest.ReplyChoosePlayer({ comp2 }) })
    local sk = Fk.skills[j_yiyi.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(#me:getPile("j_mou"), 0, "应移去一枚谋")
    lu.assertEquals(#comp2:getCardIds("h"), handBefore + 2, "目标应摸两张牌")
    lu.assertEquals(comp2.hp, hpBefore - 1, "目标应受到1点伤害")
  end)
end)

-- 测试：进入濒死时移去一枚谋回复1点体力
j_yiyi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yiyi.name)
    local mou1 = room:printCard("slash", Card.Spade, 5)
    me:addToPile("j_mou", mou1.id, true, j_yiyi.name)
  end)

  FkTest.runInRoom(function()
    -- fake房主初始4血：先备好回复，扣4点自动进入濒死
    FkTest.setNextReplies(me, { "1" })
    room:changeHp(me, -4, fk.LoseHp, "test")
    lu.assertEquals(#me:getPile("j_mou"), 0, "应移去一枚谋")
    lu.assertEquals(me.hp, 1, "应回复一点体力")
  end)
end)

return j_yiyi