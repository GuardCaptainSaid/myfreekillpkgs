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

return j_jianmou
