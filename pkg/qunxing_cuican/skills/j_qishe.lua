local j_qishe = fk.CreateSkill {
  name = "j_qishe",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_qishe"] = "骑射",
  [":j_qishe"] = "群势力技，锁定技，你的【杀】对所有与你距离不为1的角色生效；若此牌造成伤害，你修改势力；若未造成伤害，你将手牌调整至五张。",

  ["#j_qishe-discard"] = "骑射：此【杀】未造成伤害，弃置手牌至五张",
}

-- 你的【杀】无视距离限制，且可指定任意数量的远距离目标
j_qishe:addEffect("targetmod", {
  bypass_distances = function(self, player, card_skill, card, to)
    return player:hasSkill(j_qishe.name) and card and card.trueName == "slash"
      and to and player:distanceTo(to) ~= 1
  end,
  extra_target_func = function(self, player, card_skill, card)
    if player:hasSkill(j_qishe.name) and card and card.trueName == "slash" then
      return 99
    end
    return 0
  end,
})

-- 使用【杀】指定目标时：所有距离不为1的角色均成为目标
j_qishe:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_qishe.name)
      and not data.responseToEvent and not data.toCard
      and data.card and data.card.trueName == "slash"
  end,
  on_use = function(self, event, target, player, data)
    for _, p in ipairs(player.room:getOtherPlayers(player)) do
      if player:distanceTo(p) ~= 1 and not table.contains(data.tos, p) then
        data:addTarget(p)
      end
    end
  end,
})

-- 【杀】结算完毕：造成伤害则修改势力，否则手牌调整至五张
j_qishe:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_qishe.name)
      and not data.responseToEvent and not data.toCard
      and data.card and data.card.trueName == "slash"
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room

    local dealt = data.damageDealt
    local damaged_target
    if dealt then
      for _, p in ipairs(data.tos) do
        if dealt[p] and dealt[p] > 0 then
          damaged_target = p
          break
        end
      end
    end

    if damaged_target then
      -- 造成伤害：修改势力与受伤角色相同
      if damaged_target.kingdom and damaged_target.kingdom ~= player.kingdom then
        room:changeKingdom(player, damaged_target.kingdom, true)
      end
    else
      -- 未造成伤害：手牌调整至五张
      local hand = player:getCardIds("h")
      if #hand > 5 then
        local n = #hand - 5
        room:askToDiscard(player, {
          min_num = n,
          max_num = n,
          include_equip = false,
          skill_name = j_qishe.name,
          prompt = "#j_qishe-discard",
        })
      elseif #hand < 5 then
        room:drawCards(player, 5 - #hand, j_qishe.name)
      end
    end
  end,
})

-- 测试：【杀】未造成伤害（damageDealt 为空），手牌调整至五张
j_qishe:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qishe.name)
  end)

  FkTest.runInRoom(function()
    local c1 = room:printCard("peach")
    local c2 = room:printCard("peach")
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")

    local slash = Fk:cloneCard("slash")
    local sk = Fk.skills[j_qishe.name]:getSkeleton()
    local eff
    for _, spec in ipairs(sk.effect_spec_list) do
      if spec[1] == fk.CardUseFinished then eff = spec[3] break end
    end

    eff:on_use({ room = room }, me, me, {
      from = me,
      tos = { comp2 },
      card = slash,
      damageDealt = nil,
    })
    lu.assertEquals(#me:getCardIds("h"), 5, "骑射：未造成伤害应把手牌调整至5张")
  end)
end)

-- 测试：【杀】造成伤害时，势力修改为受伤角色的势力
j_qishe:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qishe.name)
  end)

  FkTest.runInRoom(function()
    room:changeKingdom(comp2, "shu", false)
    local slash = Fk:cloneCard("slash")
    local sk = Fk.skills[j_qishe.name]:getSkeleton()
    local eff
    for _, spec in ipairs(sk.effect_spec_list) do
      if spec[1] == fk.CardUseFinished then eff = spec[3] break end
    end

    local hand_before = #me:getCardIds("h")
    eff:on_use({ room = room }, me, me, {
      from = me,
      tos = { comp2 },
      card = slash,
      damageDealt = { [comp2] = 1 },
    })
    lu.assertEquals(me.kingdom, "shu", "骑射：造成伤害后势力应改为受伤角色的势力")
    lu.assertEquals(#me:getCardIds("h"), hand_before, "骑射：造成伤害时不应调整手牌")
  end)
end)

-- 复现测试：宋宪&魏续全套技能下，出牌阶段【杀】应可用（排查"回合开始无法出牌"）
j_qishe:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "j_daoge|j_qishe|j_yuji|j_xianji|j_kuiwei|j_motu")
  end)

  FkTest.runInRoom(function()
    local slash = room:printCard("slash")
    room:obtainCard(me, { slash }, true, fk.ReasonDraw, me, "test")

    me.phase = Player.Play
    local can_use = me:canUse(slash)
    me.phase = Player.NotActive

    lu.assertIsTrue(can_use, "骑射存在时出牌阶段应能使用【杀】")
  end)
end)

-- 复现测试：完整回合中实际使用【杀】并正常结算（骑射会扩充目标，验证流程不卡死）
j_qishe:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "j_daoge|j_qishe|j_yuji|j_xianji|j_kuiwei|j_motu")
  end)

  FkTest.runInRoom(function()
    local slash = room:printCard("slash")
    room:obtainCard(me, { slash }, true, fk.ReasonDraw, me, "test")

    -- 出牌阶段：先使用杀（指定 comp2），再结束出牌
    FkTest.setNextReplies(me, {
      { card = slash.id, targets = { comp2.id } },
      "",
    })
    -- 给被杀指定的角色发闪，并令其用闪响应
    local jink2 = room:printCard("jink")
    room:obtainCard(comp2, { jink2 }, true, fk.ReasonDraw, comp2, "test")
    local jink3 = room:printCard("jink")
    room:obtainCard(comp3, { jink3 }, true, fk.ReasonDraw, comp3, "test")
    FkTest.setNextReplies(comp2, { { card = jink2.id } })
    FkTest.setNextReplies(comp3, { { card = jink3.id } })

    GameEvent.Turn:create(TurnData:new(me, "game_rule", { Player.Start, Player.Judge, Player.Draw, Player.Play })):exec()

    lu.assertEquals(comp2.hp, 4, "使用杀后目标被闪响应，不应受伤")
    lu.assertEquals(comp3.hp, 4, "使用杀后远距离目标被闪响应，不应受伤")
  end)
end)

return j_qishe