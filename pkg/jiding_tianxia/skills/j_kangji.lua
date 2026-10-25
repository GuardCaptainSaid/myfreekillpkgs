-- 计杨阜·抗冀
-- 出牌阶段限一次，你可以展示一张手牌，弃置你武将牌上一张花色相同的牌，
-- 然后你视为使用展示的牌或弃置的牌。
local j_kangji = fk.CreateSkill {
  name = "j_kangji",
}

local PILE = "j_hannan"
local USE_HAND = "#j_kangji-use_hand"
local USE_PILE = "#j_kangji-use_pile"

Fk:loadTranslationTable{
  ["j_kangji"] = "抗冀",
  [":j_kangji"] = "出牌阶段限一次，你可以展示一张手牌，弃置你武将牌上一张花色相同的牌，然后视为使用展示的牌或弃置的牌。",

  ["#j_kangji"] = "抗冀：展示一张手牌并弃置武将牌上一张花色相同的牌，视为使用其中一张",
  [USE_HAND] = "使用展示的手牌",
  [USE_PILE] = "使用武将牌上的牌",
}

-- 武将牌上第一张该花色的牌
local function findPileCard(player, suit)
  for _, id in ipairs(player:getPile(PILE)) do
    local c = Fk:getCardById(id)
    if c and c:getSuitString() == suit then return id end
  end
  return nil
end

-- 该牌此刻能否当作虚拟牌使用（与 askToUseVirtualCard 内部的判定保持一致）
local function canUseAs(player, id, skillName)
  local card = Fk:getCardById(id)
  if not card or not card.trueName then return false end
  local virt = Fk:cloneCard(card.trueName)
  if not virt then return false end
  virt:addSubcards({ id })
  virt.skillName = skillName
  local extra = { bypass_times = true, extraUse = true, skillName = skillName }
  return #virt:getAvailableTargets(player, extra) > 0
end

j_kangji:addEffect("active", {
  anim_type = "offensive",
  prompt = "#j_kangji",
  min_card_num = 1,
  max_card_num = 1,
  target_num = 0,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    return player:usedSkillTimes(j_kangji.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, player, to_select, selected)
    if #selected > 0 or not table.contains(player:getCardIds("h"), to_select) then return false end
    local card = Fk:getCardById(to_select)
    return card ~= nil and findPileCard(player, card:getSuitString()) ~= nil
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_cards == 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local handId = effect.cards and effect.cards[1]
    if not handId then return end
    local handCard = Fk:getCardById(handId)
    if not handCard then return end
    local pileId = findPileCard(player, handCard:getSuitString())
    if not pileId then return end
    local pileCard = Fk:getCardById(pileId)
    if not pileCard then return end

    -- 两张都用不出去时直接不发动，免得白弃一张武将牌
    local handOk = canUseAs(player, handId, j_kangji.name)
    local pileOk = canUseAs(player, pileId, j_kangji.name)
    if not handOk and not pileOk then return end

    -- 展示这张手牌
    room:showCards({ handId }, player, player)
    -- 弃置武将牌上一张花色相同的牌
    room:moveCardTo(pileId, Card.DiscardPile, nil, fk.ReasonDiscard, j_kangji.name, nil, true, player)

    -- 二选一：使用展示的牌，或使用武将牌上的牌
    local useId
    if handOk and pileOk and handCard.trueName ~= pileCard.trueName then
      local choice = room:askToChoice(player, {
        choices = { USE_HAND, USE_PILE },
        skill_name = j_kangji.name,
        cancelable = false,
      })
      useId = (choice == USE_PILE) and pileId or handId
    elseif handOk then
      useId = handId
    else
      useId = pileId
    end

    local useCard = Fk:getCardById(useId)
    if not useCard then return end
    -- 视为使用：由 askToUseVirtualCard 内部完成实际使用
    room:askToUseVirtualCard(player, {
      name = useCard.trueName,
      subcards = { useId },
      skill_name = j_kangji.name,
      cancelable = true,
    })
  end,
})

-- 测试1：武将牌上是【闪】（出牌阶段用不出去）→ 不弹二选一，直接视为使用展示的手牌
j_kangji:addTest(function(room, me)
  local comp2 = room.players[2]
  local handId, pileId, victimCard
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_kangji.name)
    room.current = me
    me.phase = Player.Play
    handId = room:printCard("dismantlement", Card.Spade, 7).id
    room:obtainCard(me, { handId }, true, fk.ReasonDraw, me, "test")
    pileId = room:printCard("jink", Card.Spade, 8).id
    room:moveCards{
      ids = { pileId }, to = me, toArea = Card.PlayerSpecial,
      specialName = PILE, moveReason = fk.ReasonPut, skillName = "test",
    }
    victimCard = room:printCard("jink", Card.Heart, 5).id
    room:obtainCard(comp2, { victimCard }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local choiceAsked = false
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      if params.skill_name == j_kangji.name then
        choiceAsked = true
        return params.choices[1]
      end
      return origChoice(self, who, params)
    end
    FkTest.setNextReplies(me, {
      { card = { name = "dismantlement", subcards = { handId } }, targets = { comp2.id } },
    })
    local sk = Fk.skills[j_kangji.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = { handId } })
    end, {})
    room.askToChoice = origChoice
    lu.assertFalse(choiceAsked, "只有一张能用时不应弹二选一")
    lu.assertFalse(table.contains(me:getPile(PILE), pileId), "武将牌上的牌应被弃置")
    lu.assertEquals(room:getCardArea(pileId), Card.DiscardPile, "武将牌上的牌应进入弃牌堆")
    lu.assertFalse(table.contains(me:getCardIds("h"), handId), "展示的牌应被使用掉")
    lu.assertFalse(table.contains(comp2:getCardIds("h"), victimCard), "应真的拆掉对手一张牌")
  end)
end)

-- 测试2：两张都能用且牌名不同 → 弹出二选一，选「使用武将牌上的牌」
j_kangji:addTest(function(room, me)
  local comp2 = room.players[2]
  local handId, pileId, victimCard
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_kangji.name)
    room.current = me
    me.phase = Player.Play
    handId = room:printCard("slash", Card.Spade, 7).id
    room:obtainCard(me, { handId }, true, fk.ReasonDraw, me, "test")
    pileId = room:printCard("dismantlement", Card.Spade, 9).id
    room:moveCards{
      ids = { pileId }, to = me, toArea = Card.PlayerSpecial,
      specialName = PILE, moveReason = fk.ReasonPut, skillName = "test",
    }
    victimCard = room:printCard("jink", Card.Heart, 5).id
    room:obtainCard(comp2, { victimCard }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local chosen
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      if params.skill_name == j_kangji.name then
        chosen = params.choices[2]
        return chosen
      end
      return origChoice(self, who, params)
    end
    FkTest.setNextReplies(me, {
      { card = { name = "dismantlement", subcards = { pileId } }, targets = { comp2.id } },
    })
    local sk = Fk.skills[j_kangji.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = { handId } })
    end, {})
    room.askToChoice = origChoice
    lu.assertEquals(chosen, USE_PILE, "应弹出二选一")
    lu.assertFalse(table.contains(me:getPile(PILE), pileId), "武将牌上的牌应被弃置")
    lu.assertTrue(table.contains(me:getCardIds("h"), handId), "选择用武将牌上的牌时，手牌应保留")
    lu.assertFalse(table.contains(comp2:getCardIds("h"), victimCard), "应真的拆掉对手一张牌")
  end)
end)

-- 测试3：只有手牌可用（【杀】）→ 视为使用该【杀】，牌名与实体牌都传对
j_kangji:addTest(function(room, me)
  local comp2 = room.players[2]
  local handId, pileId
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_kangji.name)
    room.current = me
    me.phase = Player.Play
    handId = room:printCard("slash", Card.Spade, 7).id
    room:obtainCard(me, { handId }, true, fk.ReasonDraw, me, "test")
    pileId = room:printCard("jink", Card.Spade, 8).id
    room:moveCards{
      ids = { pileId }, to = me, toArea = Card.PlayerSpecial,
      specialName = PILE, moveReason = fk.ReasonPut, skillName = "test",
    }
  end)
  FkTest.runInRoom(function()
    local seen
    local origUse = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, who, params)
      if params.skill_name == j_kangji.name then
        seen = params
        return nil
      end
      return origUse(self, who, params)
    end
    local sk = Fk.skills[j_kangji.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = { handId } })
    end, {})
    room.askToUseVirtualCard = origUse
    lu.assertNotNil(seen, "应弹出视为使用")
    lu.assertEquals(seen.name, "slash", "应按【杀】使用")
    lu.assertEquals(seen.subcards[1], handId, "应使用展示的那张手牌")
    lu.assertFalse(table.contains(me:getPile(PILE), pileId), "武将牌上的牌应被弃置")
  end)
end)

return j_kangji
