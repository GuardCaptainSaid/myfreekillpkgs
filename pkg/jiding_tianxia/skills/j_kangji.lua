-- 计杨阜·抗冀
-- 出牌阶段限一次，你可以展示一张手牌并移去你武将牌上一张花色相同的牌，视为使用之。
local j_kangji = fk.CreateSkill {
  name = "j_kangji",
}

local PILE = "j_hannan"

Fk:loadTranslationTable{
  ["j_kangji"] = "抗冀",
  [":j_kangji"] = "出牌阶段限一次，你可以展示一张手牌并移去你武将牌上一张花色相同的牌，视为使用之。",

  ["#j_kangji"] = "抗冀：选择一张手牌（需有同花色的“悍难”牌），视为使用之",
  ["#j_kangji-use"] = "抗冀：是否使用该牌",
}

-- 武将牌上是否有该花色的牌
local function hasSameSuitCard(player, suit)
  for _, id in ipairs(player:getPile(PILE)) do
    local c = Fk:getCardById(id)
    if c and c:getSuitString() == suit then return true end
  end
  return false
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
    return card ~= nil and hasSameSuitCard(player, card:getSuitString())
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_cards == 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local cardId = effect.cards and effect.cards[1]
    if not cardId then return end
    local card = Fk:getCardById(cardId)
    if not card then return end
    local suit = card:getSuitString()
    local removeId
    for _, id in ipairs(player:getPile(PILE)) do
      local c = Fk:getCardById(id)
      if c and c:getSuitString() == suit then
        removeId = id
        break
      end
    end
    if not removeId then return end

    -- 移去武将牌上同花色的一张牌
    room:moveCardTo(removeId, Card.DiscardPile, nil, fk.ReasonDiscard, j_kangji.name, nil, true, player)
    -- 展示该手牌，然后视为使用之
    room:showCards({ cardId }, player, j_kangji.name)
    room:askToUseVirtualCard(player, {
      name = card.trueName,
      subcards = { cardId },
      skill_name = j_kangji.name,
      cancelable = true,
      prompt = "#j_kangji-use",
    })
  end,
})

-- 测试：无同花色牌不可选；有则可展示并移去该牌
j_kangji:addTest(function(room, me)
  local h1, p1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_kangji.name)
    room.current = me
    me.phase = Player.Play
    h1 = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(me, { h1 }, true, fk.ReasonDraw, me, "test")
    p1 = room:printCard("jink", Card.Spade, 8)
    room:moveCards{
      ids = { p1.id }, to = me, toArea = Card.PlayerSpecial,
      specialName = PILE, moveReason = fk.ReasonPut, skillName = "test",
    }
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_kangji.name]
    skel = skel.getSkeleton and skel:getSkeleton() or skel
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")
    lu.assertTrue(spec:card_filter(me, h1.id, {}), "同花色的手牌可选")

    local origUse = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then return nil end
      return origUse(self, who, params)
    end
    spec:on_use(room, { from = me, cards = { h1.id } })
    room.askToUseVirtualCard = origUse
    lu.assertFalse(table.contains(me:getPile(PILE), p1.id), "同花色的武将牌牌应被移去")
  end)
end)

return j_kangji
