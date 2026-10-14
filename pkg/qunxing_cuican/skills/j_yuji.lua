local j_yuji = fk.CreateSkill {
  name = "j_yuji",
  tags = { Skill.AttachedKingdom },
  attached_kingdom = { "wei" },
}

Fk:loadTranslationTable{
  ["j_yuji"] = "余悸",
  [":j_yuji"] = "魏势力技，出牌阶段攻击范围内的每名角色限一次，你可以令一名其他角色交给你一张装备牌，否则你对其造成1点伤害。若你因此获得牌，此技能本回合失效。",

  ["#j_yuji-give"] = "余悸：交给其一张手牌中的装备牌，否则其将受到1点伤害",
}

j_yuji:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:getMark("j_yuji_off") ~= 0 then return false end
    local chosen = player:getTableMark("j_yuji_chosen")
    -- getOtherPlayers 仅服务端 Room 有，客户端渲染技能按钮时会调用 can_use，必须用通用字段
    return table.find(Fk:currentRoom().players, function(p)
      return p ~= player and p:isAlive() and player:inMyAttackRange(p)
        and not table.contains(chosen, p.id)
    end) ~= nil
  end,
  target_filter = function(self, player, to_select, selected)
    if #selected > 0 or to_select == player then return false end
    if not player:inMyAttackRange(to_select) then return false end
    local chosen = player:getTableMark("j_yuji_chosen")
    return not table.contains(chosen, to_select.id)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos[1]

    -- 记录该角色本回合已成为目标
    local chosen = player:getTableMark("j_yuji_chosen")
    table.insert(chosen, to.id)
    room:setPlayerMark(player, "j_yuji_chosen", chosen)

    -- 令目标交给你一张手牌中的装备牌
    local equip_in_hand = table.filter(to:getCardIds("h"), function(id)
      return Fk:getCardById(id).type == Card.TypeEquip
    end)

    if #equip_in_hand > 0 then
      local ids = room:askToCards(to, {
        min_num = 1,
        max_num = 1,
        pattern = ".|.|.|.|.|equip",
        skill_name = j_yuji.name,
        prompt = "#j_yuji-give",
        cancelable = false,
      })
      if #ids > 0 then
        room:moveCardTo(ids, Card.PlayerHand, player, fk.ReasonGive, j_yuji.name, nil, false, to)
        -- 因此获得牌：此技能本回合失效
        room:setPlayerMark(player, "j_yuji_off", 1)
        return
      end
    end

    -- 否则对其造成1点伤害
    room:damage{
      from = player,
      to = to,
      damage = 1,
      skillName = j_yuji.name,
    }
  end,
})

-- 回合开始重置记录（标准触发型；引擎不调用 can_refresh/on_refresh 刷新型字段）
j_yuji:addEffect(fk.TurnStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_yuji.name)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_yuji_chosen", {})
    room:setPlayerMark(player, "j_yuji_off", 0)
  end,
})

-- 测试：目标无装备牌可交时受到1点伤害，且被记录为已指定目标
j_yuji:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yuji.name)
  end)

  FkTest.runInRoom(function()
    local hp_before = comp2.hp
    local sk = Fk.skills[j_yuji.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = { comp2 }, cards = {} })
    end, {})

    lu.assertEquals(comp2.hp, hp_before - 1, "余悸：无装备牌可交时应受到1点伤害")
    lu.assertIsTrue(
      table.contains(me:getTableMark("j_yuji_chosen"), comp2.id),
      "余悸：应记录该角色本回合已成为目标")
  end)
end)

-- 复现测试：宋宪&魏续全套技能 + 完整回合（回合开始→判定→摸牌→出牌），验证流程不卡死且可正常出牌
j_yuji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "j_daoge|j_qishe|j_yuji|j_xianji|j_kuiwei|j_motu")
  end)

  FkTest.runInRoom(function()
    local c1 = room:printCard("slash")
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")

    GameEvent.Turn:create(TurnData:new(me, "game_rule", { Player.Start, Player.Judge, Player.Draw, Player.Play })):exec()

    -- 出牌阶段结束后手牌应能正常变化（摸牌阶段+2，且未被卡死）
    lu.assertIsTrue(#me:getCardIds("h") >= 2, "完整回合应正常结束，手牌应包含摸牌阶段所得")
  end)
end)

return j_yuji