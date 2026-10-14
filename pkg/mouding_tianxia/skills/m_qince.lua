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

return m_qince
