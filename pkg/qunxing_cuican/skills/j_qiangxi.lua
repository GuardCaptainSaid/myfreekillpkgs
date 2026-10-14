local j_qiangxi = fk.CreateSkill {
  name = "j_qiangxi",
}

Fk:loadTranslationTable{
  ["j_qiangxi"] = "强袭",
  [":j_qiangxi"] = "出牌阶段限一次，你可以弃置一张装备牌，选择你攻击范围内的一名其他角色，该角色不能使用或打出【闪】响应你对其使用的【杀】（本回合）。",
}

-- 主动发动：弃置一张装备牌，令攻击范围内一名角色本回合不能闪响应你的杀
j_qiangxi:addEffect("active", {
  anim_type = "offensive",
  card_num = 1,
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:usedSkillTimes(j_qiangxi.name, Player.HistoryPhase) > 0 then return false end
    return table.find(player:getCardIds("h"), function(id)
      return Fk:getCardById(id).type == Card.TypeEquip
    end) ~= nil
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).type == Card.TypeEquip
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    if #selected > 0 or to_select == player then return false end
    if #selected_cards == 0 then return false end
    return player:inMyAttackRange(to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos[1]
    local id = effect.cards[1]
    room:throwCard(id, j_qiangxi.name, player, player)
    room:setPlayerMark(to, "j_qiangxi_nojink", player.id)
  end,
})

-- 你的杀指定被标记的角色时，该角色不能响应
j_qiangxi:addEffect(fk.TargetSpecified, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(j_qiangxi.name) then return false end
    if not data.card or data.card.trueName ~= "slash" then return false end
    for _, to in ipairs(data:getAllTargets()) do
      if to:getMark("j_qiangxi_nojink") == player.id then
        return true
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    for _, to in ipairs(data:getAllTargets()) do
      if to:getMark("j_qiangxi_nojink") == player.id then
        data:setDisresponsive(to)
      end
    end
  end,
})

-- 回合结束清除标记
j_qiangxi:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_qiangxi.name)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room.alive_players) do
      if p:getMark("j_qiangxi_nojink") ~= 0 then
        room:setPlayerMark(p, "j_qiangxi_nojink", 0)
      end
    end
  end,
})

-- 测试：弃置装备牌后，目标被标记，使用杀指定该目标时其不可响应
j_qiangxi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qiangxi.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("spear")
    room:obtainCard(me, { equip }, true, fk.ReasonDraw, me, "test")

    FkTest.setNextReplies(me, {
      { card = equip.id, targets = { comp2.id } },
      "",
    })
    room:useSkill(me, Fk.skills[j_qiangxi.name], function()
      Fk.skills[j_qiangxi.name]:onUse(room, { from = me, tos = { comp2 }, cards = { equip.id } })
    end, {})

    lu.assertEquals(comp2:getMark("j_qiangxi_nojink"), me.id, "强袭：目标应被标记为不能响应")
  end)
end)

-- 测试：使用杀指定被标记目标时，目标不可响应（disresponsiveList 生效）
j_qiangxi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qiangxi.name)
  end)

  FkTest.runInRoom(function()
    room:setPlayerMark(comp2, "j_qiangxi_nojink", me.id)
    local slash = room:printCard("slash")
    room:obtainCard(me, { slash }, true, fk.ReasonDraw, me, "test")

    FkTest.setNextReplies(me, { { card = slash.id, targets = { comp2.id } }, "" })
    FkTest.setNextReplies(comp2, { "" })

    local hp_before = comp2.hp
    room:useCard{ from = me, tos = { comp2 }, card = slash }

    lu.assertEquals(comp2.hp, hp_before - 1, "强袭：目标不能使用闪响应，杀应造成伤害")
  end)
end)

return j_qiangxi