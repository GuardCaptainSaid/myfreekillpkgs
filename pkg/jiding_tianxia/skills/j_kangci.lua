-- 计辛毗·抗辞
-- 出牌阶段限0次，你可以摸一张牌，并交给一名其他角色。（次数由【审度】增加）
local j_kangci = fk.CreateSkill {
  name = "j_kangci",
}

Fk:loadTranslationTable{
  ["j_kangci"] = "抗辞",
  [":j_kangci"] = "出牌阶段限0次（由【审度】增加次数），你可以摸一张牌，并交给一名其他角色。",

  ["#j_kangci"] = "抗辞：摸一张牌，交给一名其他角色",
}

j_kangci:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#j_kangci",
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    return player:usedSkillTimes(j_kangci.name, Player.HistoryPhase) < player:getMark("j_kangci_count-turn")
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and not to_select.dead and to_select ~= player
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_targets == 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if not target or target.dead then return end
    local ids = room:drawCards(player, 1, j_kangci.name)
    local id = ids and ids[1]
    if not id then return end
    room:moveCardTo(id, Card.PlayerHand, target, fk.ReasonGive, j_kangci.name, nil, true, player)
  end,
})

-- 测试：抗辞次数为 0 不可用；审度给次数后可摸一交一
j_kangci:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_kangci.name)
    room.current = me
    me.phase = Player.Play
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_kangci.name]
    skel = skel.getSkeleton and skel:getSkeleton() or skel
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")
    lu.assertFalse(spec:can_use(me), "次数为0时不可发动")

    room:setPlayerMark(me, "j_kangci_count-turn", 1)
    lu.assertTrue(spec:can_use(me), "审度给次数后可发动")

    local before = #comp2:getCardIds("h")
    spec:on_use(room, { from = me, tos = { comp2 } })
    lu.assertEquals(#comp2:getCardIds("h"), before + 1, "应摸一张交给目标")
  end)
end)

return j_kangci
