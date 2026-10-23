-- 计辛毗·监伺（锁定技）
-- 当其他角色在摸牌阶段外获得牌后，你摸一张牌并使用之，若无法使用则展示之。
local j_jiansi = fk.CreateSkill {
  name = "j_jiansi",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_jiansi"] = "监伺",
  [":j_jiansi"] = "锁定技，当其他角色在摸牌阶段外获得牌后，你摸一张牌并使用之，若无法使用则展示之。",

  ["#j_jiansi-use"] = "监伺：请使用摸到的牌",
}

-- 是否有“其他角色在摸牌阶段外获得牌”
local function findGainMove(player, data)
  for _, move in ipairs(data) do
    local to = move.to
    if to and to ~= player and not to.dead and move.toArea == Card.PlayerHand
      and #(move.moveInfo or {}) > 0 and to.phase ~= Player.Draw then
      return true
    end
  end
  return false
end

j_jiansi:addEffect(fk.AfterCardsMove, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jiansi.name) or player.dead then return false end
    -- 自身结算中不再嵌套触发
    if player:getMark("j_jiansi_busy") > 0 then return false end
    return findGainMove(player, data)
  end,
  -- 锁定技：不询问
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_jiansi_busy", 1)
    local ids = room:drawCards(player, 1, j_jiansi.name)
    local drawnId = ids and ids[1]
    if drawnId and not player.dead then
      local card = Fk:getCardById(drawnId)
      -- 判断能否主动使用（杀/酒不受次数与距离限制）
      room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 1)
      local canUse = card.is_passive or player:canUse(card, { bypass_times = true, bypass_distances = true })
      room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 0)
      local used
      if canUse then
        room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 1)
        room:setPlayerMark(player, MarkEnum.BypassDistancesLimit, 1)
        used = room:askToUseCard(player, {
          pattern = card.name,
          prompt = "#j_jiansi-use",
          cancelable = false,
        })
        room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 0)
        room:setPlayerMark(player, MarkEnum.BypassDistancesLimit, 0)
      end
      if not used and not player.dead then
        if table.contains(player:getCardIds("hej"), drawnId) then
          room:showCards({ drawnId }, player, j_jiansi.name)
        end
      end
    end
    room:setPlayerMark(player, "j_jiansi_busy", 0)
  end,
})

-- 测试：其他角色在出牌阶段获得牌 → 监伺摸一张；且自身摸牌不触发
j_jiansi:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiansi.name)
    room.current = comp2
    comp2.phase = Player.Play
    c1 = room:printCard("jink", Card.Heart, 3)
  end)
  FkTest.runInRoom(function()
    local origAsk = room.askToUseCard
    local asked = 0
    room.askToUseCard = function(self, who, params)
      if who == me then
        asked = asked + 1
        return nil -- 不使用 → 展示
      end
      return origAsk(self, who, params)
    end
    local before = #me:getCardIds("h")
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
    room.askToUseCard = origAsk
    lu.assertEquals(#me:getCardIds("h"), before + 1, "监伺应摸一张牌")
    lu.assertEquals(asked, 1, "应询问是否使用摸到的牌")
    lu.assertTrue(me:getMark("j_jiansi_busy") == 0, "结算标记应清空")
  end)
  FkTest.runInRoom(function()
    -- 自己摸牌（非摸牌阶段）不触发
    local before = #me:getCardIds("h")
    local card = room:printCard("slash", Card.Spade, 9)
    room:obtainCard(me, { card }, true, fk.ReasonDraw, me, "test")
    lu.assertEquals(#me:getCardIds("h"), before + 1, "自身获得牌不应再摸牌")
  end)
end)

return j_jiansi
