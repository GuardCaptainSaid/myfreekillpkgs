local j_jiedao = fk.CreateSkill {
  name = "j_jiedao",
}

Fk:loadTranslationTable{
  ["j_jiedao"] = "借刀",
  [":j_jiedao"] = "每回合限一次，当有角色装备装备牌时，你可以摸一张牌。",

  ["#j_jiedao-invoke"] = "借刀：是否发动？",
}

-- 任意角色装备装备牌（装备牌进入其装备区）时，每回合限一次，摸一张牌
j_jiedao:addEffect(fk.AfterCardsMove, {
  global = true,
  anim_type = "draw",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jiedao.name) then return false end
    if player:usedSkillTimes(j_jiedao.name, Player.HistoryTurn) > 0 then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.PlayerEquip and move.to and move.to:isAlive() then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_jiedao.name,
      prompt = "#j_jiedao-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    player.room:drawCards(player, 1, j_jiedao.name)
  end,
})

-- 测试：任意角色装备装备牌时，摸一张牌
j_jiedao:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiedao.name)
  end)

  FkTest.runInRoom(function()
    local hand_before = #me:getCardIds("h")
    local equip = room:printCard("guding_blade")

    FkTest.setNextReplies(me, { "1" })
    room:useCard{ from = comp2, tos = { comp2 }, card = equip }

    lu.assertEquals(#me:getCardIds("h"), hand_before + 1, "借刀：有角色装备装备牌时应摸一张牌")
  end)
end)

-- 测试：每回合限一次（同回合第二次装备不触发）
j_jiedao:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiedao.name)
  end)

  FkTest.runInRoom(function()
    local hand_before = #me:getCardIds("h")
    local equip1 = room:printCard("guding_blade")
    local equip2 = room:printCard("spear")

    FkTest.setNextReplies(me, { "1", "1", "1" })
    room:useCard{ from = comp2, tos = { comp2 }, card = equip1 }
    room:useCard{ from = comp2, tos = { comp2 }, card = equip2 }

    lu.assertEquals(#me:getCardIds("h"), hand_before + 1, "借刀：每回合限一次，第二次装备不应再摸牌")
  end)
end)

-- 测试：回合重置后再次可发动
j_jiedao:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiedao.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("guding_blade")
    FkTest.setNextReplies(me, { "1" })
    room:useCard{ from = comp2, tos = { comp2 }, card = equip }
    local after_first = #me:getCardIds("h")

    -- 模拟进入新回合（借刀已用过一次）
    FkTest.setNextReplies(me, { "1" })
    local equip2 = room:printCard("spear")
    room:useCard{ from = comp2, tos = { comp2 }, card = equip2 }
    lu.assertEquals(#me:getCardIds("h"), after_first, "借刀：未重置时同回合第二次装备不触发")

    -- 触发回合变更以重置历史（TurnStart 由引擎清空 HistoryTurn）
    GameEvent.Turn:create(TurnData:new(me, "game_rule", { Player.Start })):exec()
    FkTest.setNextReplies(me, { "1" })
    local equip3 = room:printCard("qinggang_sword")
    room:useCard{ from = comp2, tos = { comp2 }, card = equip3 }
    lu.assertEquals(#me:getCardIds("h"), after_first + 1, "借刀：新回合应重置每回合限一次")
  end)
end)

return j_jiedao