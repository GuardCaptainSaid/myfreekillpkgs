local m_buzhen = fk.CreateSkill {
  name = "m_buzhen",
}

Fk:loadTranslationTable{
  ["m_buzhen"] = "布阵",
  [":m_buzhen"] = "回合开始前，若你的武将牌背面朝上，你可以弃置所有区域内的牌，然后展示牌堆底的X张牌（X为场上存活角色的数量，不足3则改为3；若场上角色势力均相同，则X+2），你获得其中的基本牌，并使用其他牌或将其依次置于场上或牌堆两端，若因此造成伤害，你可以重置武将牌。",

  ["#m_buzhen-invoke"] = "布阵：弃置所有区域内的牌，展示牌堆底的牌",
  ["#m_buzhen-place::"] = "布阵：选择 %arg 的处理方式",
  ["#m_buzhen-reset"] = "布阵：你造成了伤害，可以重置武将牌",
  ["m_buzhen:use"] = "使用",
  ["m_buzhen:equip"] = "置于装备区",
  ["m_buzhen:judge"] = "置于判定区",
  ["m_buzhen:top"] = "置牌堆顶",
  ["m_buzhen:bottom"] = "置牌堆底",
  ["$m_buzhen1"] = "八阵图成，万夫莫开！",
  ["$m_buzhen2"] = "布阵以待，静候敌来！",
}

-- 布阵结算中（检测"若因此造成伤害"）
local function inResolve(room)
  return room:getTag("m_buzhen_resolving") == true
end

-- 置牌堆底
local function placeToBottom(room, player, id)
  room:moveCards {
    ids = { id },
    toArea = Card.DrawPile,
    moveReason = fk.ReasonPut,
    skillName = m_buzhen.name,
    proposer = player,
    drawPilePosition = -1,
  }
end

-- 置牌堆顶
local function placeToTop(room, player, id)
  room:moveCards {
    ids = { id },
    toArea = Card.DrawPile,
    moveReason = fk.ReasonPut,
    skillName = m_buzhen.name,
    proposer = player,
    drawPilePosition = 1,
  }
end

local function buzhen(player)
  local room = player.room

  -- 1. 弃置所有区域内的牌
  local all = player:getCardIds("hej")
  if #all > 0 then
    room:throwCard(all, m_buzhen.name, player, player)
  end

  -- 2. X：存活角色数，不足3则3；势力均相同则+2
  local alive = room.alive_players
  local X = #alive
  if X < 3 then X = 3 end
  local kingdom = alive[1] and alive[1].kingdom
  local same = kingdom ~= nil
  for _, p in ipairs(alive) do
    if p.kingdom ~= kingdom then same = false break end
  end
  if same then X = X + 2 end

  -- 3. 展示牌堆底的X张牌（移至处理区）
  local ids = room:getNCards(X, "bottom")
  if #ids == 0 then return end
  room:turnOverCardsFromDrawPile(player, ids, m_buzhen.name, true)

  -- 4. 获得其中的基本牌
  local basicIds, others = {}, {}
  for _, id in ipairs(ids) do
    if Fk:getCardById(id).type == Card.TypeBasic then
      table.insert(basicIds, id)
    else
      table.insert(others, id)
    end
  end
  if #basicIds > 0 then
    room:obtainCard(player, basicIds, false, fk.ReasonPrey, player, m_buzhen.name)
  end

  -- 5. 非基本牌：使用或依次置于场上/牌堆两端
  room:setTag("m_buzhen_resolving", true)
  room:setPlayerMark(player, "m_buzhen_damaged", 0)
  for _, id in ipairs(others) do
    local card = Fk:getCardById(id)
    if card.type == Card.TypeEquip then
      local choice = room:askToChoice(player, {
        choices = { "m_buzhen:equip", "m_buzhen:top", "m_buzhen:bottom" },
        skill_name = m_buzhen.name,
        prompt = "#m_buzhen-place::" .. id,
      })
      if choice == "m_buzhen:equip" then
        room:moveCardTo(id, Card.PlayerEquip, player, fk.ReasonPut, m_buzhen.name)
      elseif choice == "m_buzhen:bottom" then
        placeToBottom(room, player, id)
      else
        placeToTop(room, player, id)
      end
    elseif card.sub_type == Card.SubtypeDelayedTrick then
      local choice = room:askToChoice(player, {
        choices = { "m_buzhen:judge", "m_buzhen:top", "m_buzhen:bottom" },
        skill_name = m_buzhen.name,
        prompt = "#m_buzhen-place::" .. id,
      })
      if choice == "m_buzhen:judge" then
        room:moveCardTo(id, Card.PlayerJudge, player, fk.ReasonPut, m_buzhen.name)
      elseif choice == "m_buzhen:bottom" then
        placeToBottom(room, player, id)
      else
        placeToTop(room, player, id)
      end
    else
      -- 普通锦囊：可使用则提供"使用"选项
      local targets = table.filter(room.alive_players, function(p)
        return player:canUseTo(card, p)
      end)
      local choices = { "m_buzhen:top", "m_buzhen:bottom" }
      if #targets > 0 then table.insert(choices, 1, "m_buzhen:use") end
      local choice = room:askToChoice(player, {
        choices = choices,
        skill_name = m_buzhen.name,
        prompt = "#m_buzhen-place::" .. id,
      })
      if choice == "m_buzhen:use" then
        local tos = room:askToChoosePlayers(player, {
          targets = targets,
          min_num = 1,
          max_num = #targets,
          skill_name = m_buzhen.name,
          prompt = "#m_buzhen-place::" .. id,
        })
        room:useCard{ from = player, tos = tos, card = card, skillName = m_buzhen.name }
      elseif choice == "m_buzhen:bottom" then
        placeToBottom(room, player, id)
      else
        placeToTop(room, player, id)
      end
    end
  end
  room:setTag("m_buzhen_resolving", nil)

  -- 6. 若因此造成伤害，可以重置武将牌（翻回正面）
  if player:getMark("m_buzhen_damaged") > 0 and not player.faceup then
    if room:askToSkillInvoke(player, {
      skill_name = m_buzhen.name,
      prompt = "#m_buzhen-reset",
    }) then
      player:turnOver()
    end
  end
  room:setPlayerMark(player, "m_buzhen_damaged", 0)
end

-- 回合开始前，武将牌背面朝上时可发动
m_buzhen:addEffect(fk.PreTurnStart, {
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(m_buzhen.name) then return false end
    if target ~= player or player.dead then return false end
    return not player.faceup
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, {
      skill_name = m_buzhen.name,
      prompt = "#m_buzhen-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    buzhen(player)
  end,
})

-- 布阵使用牌造成伤害时记录（用于结算后重置武将牌）
m_buzhen:addEffect(fk.DamageCaused, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(m_buzhen.name) then return false end
    if not inResolve(player.room) then return false end
    return data.from == player
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "m_buzhen_damaged", 1)
  end,
})

m_buzhen:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = m_buzhen.name,
  think = Util.TrueFunc,
})

return m_buzhen
