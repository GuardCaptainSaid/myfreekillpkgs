local m_qince = fk.CreateSkill {
  name = "m_qince",
}

Fk:loadTranslationTable{
  ["m_qince"] = "勤策",
  [":m_qince"] = "当一名角色失去最后的手牌时，若你：有手牌，你可以摸一张牌并交给其至少两张牌；没有手牌：直到你的下个回合你视为拥有“空城”。",

  ["#m_qince-invoke"] = "勤策：%dest 失去了最后的手牌",
  ["#m_qince-give"] = "勤策：交给 %dest 至少两张牌",
  ["$m_qince1"] = "勤于谋划，策定乾坤。",
  ["$m_qince2"] = "运筹帷幄，决胜千里！",
}

local QINCE_KONGCHENG = "m_qince_kongcheng"

-- 找到"失去最后手牌"的角色（移动后手牌数为0）
local function findLostRole(data)
  for _, move in ipairs(data) do
    local from = move.from
    if from and not from.dead and #from:getCardIds("h") == 0 then
      for _, info in ipairs(move.moveInfo) do
        if info.fromArea == Card.PlayerHand then
          return from
        end
      end
    end
  end
end

m_qince:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(m_qince.name) then return false end
    if player.dead then return false end
    return findLostRole(data) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local lostRole = findLostRole(data)
    return event.room:askToSkillInvoke(player, {
      skill_name = m_qince.name,
      prompt = "#m_qince-invoke::" .. lostRole.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local lostRole = findLostRole(data)
    if not lostRole then return end
    if #player:getCardIds("h") > 0 then
      -- 有手牌：摸一张牌并交给其至少两张牌
      player:drawCards(1, m_qince.name)
      local hand = player:getCardIds("h")
      if #hand >= 2 then
        local cards = room:askToChooseCards(player, {
          target = player,
          flag = "h",
          min = 2,
          max = #hand,
          cancelable = true,
          skill_name = m_qince.name,
          prompt = "#m_qince-give::" .. lostRole.id,
        })
        if cards and #cards > 0 then
          room:moveCardTo(cards, Card.PlayerHand, lostRole, fk.ReasonGive, m_qince.name, nil, false, player)
        end
      end
    else
      -- 没有手牌：直到自己的下个回合视为拥有"空城"
      if not player:hasSkill("kongcheng") then
        room:handleAddLoseSkills(player, "kongcheng")
      end
      room:setPlayerMark(player, QINCE_KONGCHENG, 1)
    end
  end,
})

-- 自己的回合开始时移除临时空城
m_qince:addEffect(fk.TurnStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(m_qince.name)
      and player:getMark(QINCE_KONGCHENG) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, QINCE_KONGCHENG, 0)
    if player:hasSkill("kongcheng") then
      room:handleAddLoseSkills(player, "-kongcheng")
    end
  end,
})

m_qince:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = m_qince.name,
  think = Util.TrueFunc,
})

-- 测试：有手牌分支——摸一张并交给失去最后手牌的角色至少两张
m_qince:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2, c3, cDraw
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, m_qince.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    c2 = room:printCard("peach", Card.Heart, 6)
    c3 = room:printCard("dismantlement", Card.Club, 7)
    cDraw = room:printCard("peach", Card.Diamond, 8) -- 置于牌堆顶，摸牌时获得
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    -- comp2 只有一张手牌，将其打出/弃置后失去最后手牌
    room:obtainCard(comp2, { c2 }, true, fk.ReasonDraw, comp2, "test")
    room:obtainCard(comp2, { c3 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    -- comp2 弃掉两张手牌 → 失去最后手牌
    FkTest.setNextReplies(me, { "1", FkTest.ReplyChooseCards({ c1.id, cDraw.id }) })
    local moveData = {
      {
        from = comp2,
        to = nil,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonDiscard,
        moveInfo = {
          { cardId = c2.id, fromArea = Card.PlayerHand },
          { cardId = c3.id, fromArea = Card.PlayerHand },
        },
      },
    }
    room.logic:trigger(fk.AfterCardsMove, comp2, moveData)
    -- me 原有1张手牌 + 摸1 = 2，交出2张 → 手牌0
    lu.assertEquals(#me:getCardIds("h"), 0, "摸一张后应交出两张")
    lu.assertEquals(#comp2:getCardIds("h"), 2, "失去手牌的角色应获得至少两张牌")
  end)
end)

-- 测试：没有手牌分支——视为拥有空城，直到自己的下个回合移除
m_qince:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, m_qince.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
    -- me 无手牌
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    -- comp2 打出最后一张手牌（杀）
    local moveData = {
      {
        from = comp2,
        to = nil,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonUse,
        moveInfo = {
          { cardId = c1.id, fromArea = Card.PlayerHand },
        },
      },
    }
    room.logic:trigger(fk.AfterCardsMove, comp2, moveData)
    lu.assertTrue(me:hasSkill("kongcheng"), "没有手牌时应视为拥有空城")
    lu.assertEquals(me:getMark(QINCE_KONGCHENG), 1, "应记录临时空城标记")
    -- 空城生效：comp2 不能用杀/决斗指定无手牌的 me
    local slash = Fk:cloneCard("slash")
    lu.assertFalse(comp2:canUseTo(slash, me), "空城应禁止杀指定")
    -- 自己回合开始 → 移除空城
    FkTest.runInRoom(function()
      local tdata = { who = me, reason = "game_rule" }
      room.logic:trigger(fk.TurnStart, me, tdata)
    end)
    lu.assertFalse(me:hasSkill("kongcheng"), "自己回合开始应移除临时空城")
    lu.assertEquals(me:getMark(QINCE_KONGCHENG), 0, "标记应清除")
  end)
end)

return m_qince