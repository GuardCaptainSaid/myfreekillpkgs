local j_jianmou = fk.CreateSkill {
  name = "j_jianmou",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_jianmou"] = "间谋",
  [":j_jianmou"] = "锁定技，你摸牌阶段外获得手牌时明置并增加“间谋”标记，你的“间谋”牌不记入手牌上限且只能做为转化牌使打出。当你成为一张牌的目标时，若你的手牌中有与其花色相同的“间谋”牌，你展示之并摸一张牌。",

  ["@@j_jianmou-inhand"] = "间谋",
}

-- 间谋标记牌对全场明置（对其他角色可见；非间谋牌返回 nil 不表态，保持默认可见性）
j_jianmou:addEffect("visibility", {
  card_visible = function(self, player, card)
    if card and card:getMark("@@j_jianmou-inhand") > 0 then return true end
    return nil
  end,
})

-- 不记入手牌上限
j_jianmou:addEffect("maxcards", {
  exclude_from = function(self, player, card)
    return card:getMark("@@j_jianmou-inhand") > 0 and player:hasSkill(j_jianmou.name)
  end
})

-- 摸牌阶段外获得手牌时：明置并增加“间谋”标记
j_jianmou:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianmou.name) then return false end
    if player.dead then return false end
    -- 摸牌阶段内的摸牌不视为“摸牌阶段外”
    local current = player.room.current
    if current and current.phase == Player.Draw then return false end
    for _, move in ipairs(data) do
      if move.to == player and move.toArea == Card.PlayerHand then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, move in ipairs(data) do
      if move.to == player and move.toArea == Card.PlayerHand then
        for _, info in ipairs(move.moveInfo) do
          local card = Fk:getCardById(info.cardId)
          if card:getMark("@@j_jianmou-inhand") == 0 then
            room:setCardMark(card, "@@j_jianmou-inhand", 1)
          end
        end
      end
    end
  end,
})

-- 成为一张牌的目标时：若手牌中有与其花色相同的“间谋”牌，展示之并摸一张牌
j_jianmou:addEffect(fk.TargetConfirmed, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianmou.name) then return false end
    if player.dead then return false end
    if data.to ~= player then return false end
    if not data.card then return false end
    local suit = data.card.suit
    if suit == Card.NoSuit then return false end
    return table.find(player:getCardIds("h"), function(id)
      local c = Fk:getCardById(id)
      return c:getMark("@@j_jianmou-inhand") > 0 and c.suit == suit
    end) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local suit = data.card.suit
    local shown = table.filter(player:getCardIds("h"), function(id)
      local c = Fk:getCardById(id)
      return c:getMark("@@j_jianmou-inhand") > 0 and c.suit == suit
    end)
    if #shown > 0 then
      -- 展示给全场（明置=对其他角色可见）
      room:showCards(shown, player, player)
      room:drawCards(player, 1, j_jianmou.name)
    end
  end,
})

-- 间谋牌只能作为转化牌使用（不能直接使用，间智转化放行）
j_jianmou:addEffect(fk.PreCardUse, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianmou.name) then return false end
    if target ~= player then return false end
    if not data.card then return false end
    if data.card.skillName == "j_jianzhi" then return false end
    if data.card:getMark("@@j_jianmou-inhand") > 0 then return true end
    for _, id in ipairs(data.card.subcards or {}) do
      if Fk:getCardById(id):getMark("@@j_jianmou-inhand") > 0 then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    -- 返回 true 使引擎中断本次使用
    return true
  end,
})

-- 间谋牌只能作为转化牌打出（不能直接打出/响应，间智转化放行）
j_jianmou:addEffect(fk.PreCardRespond, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianmou.name) then return false end
    if target ~= player then return false end
    if not data.card then return false end
    if data.card.skillName == "j_jianzhi" then return false end
    if data.card:getMark("@@j_jianmou-inhand") > 0 then return true end
    for _, id in ipairs(data.card.subcards or {}) do
      if Fk:getCardById(id):getMark("@@j_jianmou-inhand") > 0 then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    -- 返回 true 使引擎中断本次打出
    return true
  end,
})

-- 测试：摸牌阶段外获得手牌 → 增加“间谋”标记
j_jianmou:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianmou.name)
    c1 = room:printCard("slash", Card.Spade, 5)
  end)
  FkTest.runInRoom(function()
    room.current = comp2 -- 回合外
    room:obtainCard(me, { c1 }, false, fk.ReasonPrey, comp2, "test")
    lu.assertEquals(c1:getMark("@@j_jianmou-inhand"), 1, "回合外获得手牌应标记间谋")
  end)
end)

-- 测试：摸牌阶段内的摸牌不标记
j_jianmou:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianmou.name)
    c1 = room:printCard("slash", Card.Spade, 5)
  end)
  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Draw
    room:obtainCard(me, { c1 }, false, fk.ReasonDraw, me, "test")
    lu.assertEquals(c1:getMark("@@j_jianmou-inhand"), 0, "摸牌阶段摸牌不应标记")
  end)
end)

-- 测试：成为目标时展示同花色“间谋”牌并摸一张
j_jianmou:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianmou.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_jianmou-inhand", 1)
  end)
  FkTest.runInRoom(function()
    local aim = AimData:new{ from = comp2, card = Fk:cloneCard("slash", Card.Spade, 5), tos = { me }, to = me }
    room.logic:trigger(fk.TargetConfirmed, me, aim)
    lu.assertEquals(#me:getCardIds("h"), 2, "展示间谋牌后应摸一张")
  end)
end)

-- 测试：间谋牌不能直接使用（被拦截）；间智转化放行
j_jianmou:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianmou.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_jianmou-inhand", 1)
  end)
  FkTest.runInRoom(function()
    local card = c1
    local use = UseCardData:new{ from = me, card = card, tos = {} }
    local ret = room.logic:trigger(fk.PreCardUse, me, use)
    lu.assertTrue(ret, "间谋牌直接使用应被拦截")

    local card2 = Fk:cloneCard("slash", Card.Spade, 5)
    card2.skillName = "j_jianzhi"
    card2:addSubcard(c1.id)
    local use2 = UseCardData:new{ from = me, card = card2, tos = {} }
    local ret2 = room.logic:trigger(fk.PreCardUse, me, use2)
    lu.assertFalse(ret2, "间智转化使用应放行")
  end)
end)

-- 测试：间谋牌对其他角色可见（明置），普通牌对其他角色保持暗置
j_jianmou:addTest(function(room, me)
  local comp3 = room.players[3]
  local c1, c2
  FkTest.runInRoom(function()
    c1 = room:printCard("slash", Card.Spade, 5)
    c2 = room:printCard("peach", Card.Heart, 6)
    -- 先获得普通牌（此时尚未拥有间谋，不会被标记）
    room:obtainCard(me, { c2 }, false, fk.ReasonPrey, me, "test")
    room:handleAddLoseSkills(me, j_jianmou.name)
    -- 拥有间谋后再获得，触发摸牌阶段外获得 → 自动标记
    room:obtainCard(me, { c1 }, false, fk.ReasonPrey, me, "test")
  end)
  FkTest.runInRoom(function()
    lu.assertTrue(me:cardVisible(c1.id), "间谋牌应明置可见")
    lu.assertTrue(comp3:cardVisible(c1.id), "间谋牌应对其他角色可见（明置=对其他角色可见）")
    lu.assertTrue(me:cardVisible(c2.id), "普通牌对持有者应可见")
    lu.assertFalse(comp3:cardVisible(c2.id), "普通牌对其他角色应暗置")
  end)
end)

return j_jianmou