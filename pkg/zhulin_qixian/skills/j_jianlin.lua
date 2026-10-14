local j_jianlin = fk.CreateSkill {
  name = "j_jianlin",
}

Fk:loadTranslationTable{
  ["j_jianlin"] = "俭吝",
  [":j_jianlin"] = "一名角色的回合结束后，若你本回合失去过基本牌，你可以从弃牌堆中选择一张牌并获得之。",

  ["#j_jianlin-invoke"] = "俭吝：是否从弃牌堆选择一张牌获得？",
  ["#j_jianlin-pick"] = "俭吝：从弃牌堆选择一张牌",

  ["$j_jianlin1"] = "家道中落，不得不俭。",
  ["$j_jianlin2"] = "一果之微，亦足营生。",
}

-- 王戎失去基本牌时打标记（静默监听）
j_jianlin:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianlin.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if move.from and move.from == player then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = Fk:getCardById(info.cardId)
          if card.type == Card.TypeBasic then
            return true
          end
        end
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_jianlin_lost", 1)
  end,
})

-- 任意角色回合开始：清零本回合失去基本牌标记
j_jianlin:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Start then return false end
    if not player:hasSkill(j_jianlin.name) then return false end
    return player:getMark("j_jianlin_lost") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_jianlin_lost", 0)
  end,
})

-- 一名角色的回合结束后：若本回合失去过基本牌 → 从弃牌堆选一张获得
j_jianlin:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Finish then return false end
    if not player:hasSkill(j_jianlin.name) or player.dead then return false end
    return player:getMark("j_jianlin_lost") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_jianlin.name, prompt = "#j_jianlin-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local discard = room.discard_pile
    if #discard == 0 then return end
    local picked = room:askToChooseCards(player, {
      target = player,
      flag = { card_data = { { "$DiscardPile", discard } } },
      min = 1, max = 1, cancelable = false,
      pattern = ".",
      skill_name = j_jianlin.name,
      prompt = "#j_jianlin-pick",
    })
    if picked and #picked > 0 then
      room:obtainCard(player, picked, true, fk.ReasonGot, nil, j_jianlin.name)
    end
  end,
})

j_jianlin:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_jianlin.name,
  think = function(self, player)
    return player:getMark("j_jianlin_lost") > 0 and #player.room.discard_pile > 0
  end,
})

-- 测试：回合内失去基本牌 → 回合结束可从弃牌堆获得一张
j_jianlin:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianlin.name)
    local c1 = room:printCard("slash", Card.Club, 2) -- 基本牌
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local hand = me:getCardIds("h")
    -- 王戎失去一张基本牌（弃置自己一张杀）
    room:throwCard({ hand[1] }, j_jianlin.name, me, me)
    lu.assertEquals(me:getMark("j_jianlin_lost"), 1, "俭吝：失去基本牌应有标记")

    local discard = room.discard_pile
    lu.assertTrue(#discard > 0, "俭吝：弃牌堆应有牌")
    local wantId = discard[1] -- 提前缓存目标牌（obtainCard 后弃牌堆引用会变化）
    local before = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", { wantId } })
    local phaseData = { from = Player.Play, to = Player.Finish }
    room.logic:trigger(fk.EventPhaseStart, me, phaseData)

    lu.assertEquals(#me:getCardIds("h"), before + 1, "俭吝：应获得一张弃牌堆中的牌")
    lu.assertTrue(table.contains(me:getCardIds("h"), wantId), "俭吝：应获得指定的弃牌")
  end)
end)

-- 测试：本回合未失去基本牌 → 回合结束不触发
j_jianlin:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianlin.name)
    room:setPlayerMark(me, "j_jianlin_lost", 0)
  end)

  FkTest.runInRoom(function()
    local before = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1" })
    local phaseData = { from = Player.Play, to = Player.Finish }
    room.logic:trigger(fk.EventPhaseStart, me, phaseData)
    lu.assertEquals(#me:getCardIds("h"), before, "俭吝：未失去基本牌时不应获得牌")
  end)
end)

return j_jianlin