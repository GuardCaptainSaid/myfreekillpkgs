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
    local used = false
    if drawnId and not player.dead then
      local card = Fk:getCardById(drawnId)
      -- 闪/无懈可击是"只能在响应时使用"的牌，出牌阶段用不了 → 直接展示
      if card and not card.is_passive and table.contains(player:getCardIds("h"), drawnId)
        and player:canUse(card) then
        -- askToUseRealCard：只允许用这张实体牌，不走转化技；内部会自动 useCard
        local use = room:askToUseRealCard(player, {
          pattern = { drawnId },
          prompt = "#j_jiansi-use",
          cancelable = true,
        })
        used = use ~= nil
      end
      if not used and not player.dead and table.contains(player:getCardIds("hej"), drawnId) then
        room:showCards({ drawnId }, player, j_jiansi.name)
      end
    end
    room:setPlayerMark(player, "j_jiansi_busy", 0)
  end,
})

-- 测试：其他角色在出牌阶段获得牌 → 监伺摸一张；且自身摸牌不触发
j_jiansi:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, top
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiansi.name)
    room.current = comp2
    comp2.phase = Player.Play
    c1 = room:printCard("jink", Card.Heart, 3)
    -- 牌堆顶放一张【杀】，确保监伺摸到的是可主动使用的牌
    top = room:printCard("slash", Card.Spade, 4)
    room:moveCards{ ids = { top.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut }
  end)
  FkTest.runInRoom(function()
    local origAsk = room.askToUseRealCard
    local asked = 0
    room.askToUseRealCard = function(self, who, params)
      asked = asked + 1
      lu.assertEquals(params.pattern[1], top.id, "只应允许使用摸到的那张牌")
      return nil -- 不使用 → 展示
    end
    local before = #me:getCardIds("h")
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
    room.askToUseRealCard = origAsk
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

-- 测试：摸到的牌会被真正使用（此前只 askToUseCard 却没 room:useCard，牌打不出去）
j_jiansi:addTest(function(room, me)
  local comp2 = room.players[2]
  local trick, c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiansi.name)
    room.current = comp2
    comp2.phase = Player.Play
    trick = room:printCard("ex_nihilo", Card.Heart, 6)
    room:moveCards{ ids = { trick.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut }
    c1 = room:printCard("jink", Card.Club, 8)
  end)
  FkTest.runInRoom(function()
    local origAsk = room.askToUseRealCard
    local asked = 0
    -- 模拟玩家选择使用摸到的这张牌（askToUseRealCard 内部会 useCard）
    room.askToUseRealCard = function(self, who, params)
      asked = asked + 1
      lu.assertEquals(params.pattern[1], trick.id, "只应允许使用摸到的那张牌")
      local use = { from = who, tos = {}, card = Fk:getCardById(trick.id), extraUse = true }
      self:useCard(use)
      return use
    end
    local before = #me:getCardIds("h")
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
    room.askToUseRealCard = origAsk
    lu.assertEquals(asked, 1, "应询问使用摸到的牌")
    -- 监伺摸1张(无中生有) - 使用1张 + 无中生有效果摸2张 = 净 +2
    lu.assertEquals(#me:getCardIds("h"), before + 2, "摸到的【无中生有】应真正生效")
    lu.assertFalse(table.contains(me:getCardIds("h"), trick.id), "使用后该牌应离开手牌")
  end)
end)

-- 测试：摸到【闪】这类被动牌 → 不询问、直接展示
j_jiansi:addTest(function(room, me)
  local comp2 = room.players[2]
  local jink, c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiansi.name)
    room.current = comp2
    comp2.phase = Player.Play
    jink = room:printCard("jink", Card.Diamond, 7)
    room:moveCards{ ids = { jink.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut }
    c1 = room:printCard("slash", Card.Club, 8)
  end)
  FkTest.runInRoom(function()
    local origAsk = room.askToUseRealCard
    local asked = 0
    room.askToUseRealCard = function(self, who, params)
      asked = asked + 1
      return nil
    end
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
    room.askToUseRealCard = origAsk
    lu.assertEquals(asked, 0, "闪不能在出牌阶段主动使用，不应询问")
    lu.assertTrue(table.contains(me:getCardIds("h"), jink.id), "摸到的闪应留在手中")
  end)
end)

return j_jiansi
