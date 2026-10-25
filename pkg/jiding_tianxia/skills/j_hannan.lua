-- 计杨阜·悍难
-- 当一名角色成为【杀】的目标时，你可以将上一次进入弃牌堆的牌置于你的武将牌上；
-- 若其中有装备牌，你与其各摸一张牌。若如此做，本回合【杀】的伤害+X（X为本回合你发动【悍难】的次数）。
-- 当你武将牌上有重复花色的牌时，你将其中多余的牌置入弃牌堆，然后从牌堆里获得等量该花色的牌。
local j_hannan = fk.CreateSkill {
  name = "j_hannan",
  derived_piles = "j_hannan",
}

local PILE = "j_hannan"
local LAST_TAG = "j_hannan_last"
local COUNT = "j_hannan_count-turn"

Fk:loadTranslationTable{
  ["j_hannan"] = "悍难",
  [":j_hannan"] = "当一名角色成为【杀】的目标时，你可以将上一次进入弃牌堆的牌置于你的武将牌上；若其中有装备牌，你与其各摸一张牌。若如此做，本回合【杀】的伤害+X（X为本回合你发动【悍难】的次数）。当你武将牌上有重复花色的牌时，你将其中多余的牌置入弃牌堆，然后从牌堆里获得等量该花色的牌。",

  ["#j_hannan-invoke"] = "悍难：是否将上一次进入弃牌堆的牌置于武将牌上（本回合【杀】伤害+1）？",
}

-- 清除武将牌上重复花色的牌：每种花色留一张，多余的（重复的）置入弃牌堆，
-- 然后从牌堆里获得「等量」（=置入弃牌堆的张数）该花色的牌，而不是把该花色的牌整组换掉
local function cycleDuplicateSuits(room, player)
  if player.dead then return end
  local pile = player:getPile(PILE)
  if #pile == 0 then return end

  -- 按花色分组，每种花色保留第一张，其余记为“重复的牌”
  local seen = {}
  local dupBySuit = {}
  local suitOrder = {}
  for _, id in ipairs(pile) do
    local card = Fk:getCardById(id)
    if card then
      local s = card:getSuitString()
      if seen[s] then
        if not dupBySuit[s] then
          dupBySuit[s] = {}
          table.insert(suitOrder, s)
        end
        table.insert(dupBySuit[s], id)
      else
        seen[s] = true
      end
    end
  end
  if #suitOrder == 0 then return end

  for _, suit in ipairs(suitOrder) do
    local ids = dupBySuit[suit]
    local want = #ids
    room:moveCards{
      ids = ids,
      from = player,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonDiscard,
      skillName = j_hannan.name,
      proposer = player,
    }
    -- 从牌堆里找出等量该花色的牌并获得
    local found = {}
    for _, id in ipairs(room.draw_pile or {}) do
      if #found >= want then break end
      local c = Fk:getCardById(id)
      if c and c:getSuitString() == suit then
        table.insert(found, id)
      end
    end
    if #found > 0 then
      room:obtainCard(player, found, false, fk.ReasonGain, player, j_hannan.name)
    end
    if player.dead then return end
  end
end

-- 记录“上一次进入弃牌堆的牌”
j_hannan:addEffect(fk.AfterCardsMove, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_hannan.name) then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then return true end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local ids = {}
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          table.insert(ids, info.cardId)
        end
      end
    end
    if #ids > 0 then
      player.room:setTag(LAST_TAG, ids)
    end
  end,
})

-- 成为【杀】的目标时
j_hannan:addEffect(fk.TargetConfirmed, {
  global = true,
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_hannan.name) or player.dead then return false end
    local card = data and data.card
    if not card or card.trueName ~= "slash" then return false end
    local room = player.room
    for _, id in ipairs(room:getTag(LAST_TAG) or {}) do
      if room:getCardArea(id) == Card.DiscardPile then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_hannan.name,
      prompt = "#j_hannan-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = table.filter(room:getTag(LAST_TAG) or {}, function(id)
      return room:getCardArea(id) == Card.DiscardPile
    end)
    if #ids == 0 then return end
    room:setTag(LAST_TAG, {})

    local hasEquip = false
    for _, id in ipairs(ids) do
      local c = Fk:getCardById(id)
      if c and c.type == Card.TypeEquip then
        hasEquip = true
        break
      end
    end

    room:moveCards{
      ids = ids,
      to = player,
      toArea = Card.PlayerSpecial,
      specialName = PILE,
      moveReason = fk.ReasonPut,
      skillName = j_hannan.name,
      proposer = player,
    }

    -- 本回合【杀】伤害 +1（按发动次数累计）
    room:addPlayerMark(player, COUNT, 1)

    if hasEquip then
      room:drawCards(player, 1, j_hannan.name)
      local t = data.to
      if t and not t.dead and t ~= player then
        room:drawCards(t, 1, j_hannan.name)
      end
    end

    cycleDuplicateSuits(room, player)
  end,
})

-- 本回合【杀】伤害 +X
j_hannan:addEffect(fk.DetermineDamageInflicted, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_hannan.name) then return false end
    local x = player:getMark(COUNT)
    if x <= 0 then return false end
    local card = data and data.card
    return card ~= nil and card.trueName == "slash"
  end,
  on_use = function(self, event, target, player, data)
    data.damage = data.damage + player:getMark(COUNT)
  end,
})

-- 测试：某人成为杀的目标 → 上一次进入弃牌堆的牌置于武将牌上，并记录本回合次数
j_hannan:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_hannan.name)
    c1 = room:printCard("slash", Card.Spade, 7)
    room:moveCards{ ids = { c1.id }, toArea = Card.DiscardPile, moveReason = fk.ReasonDiscard }
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return true end
    local slash = Fk:cloneCard("slash")
    room.logic:trigger(fk.TargetConfirmed, comp2, { card = slash, to = comp2, from = me, tos = { comp2 } })
    room.askToSkillInvoke = origInvoke
    lu.assertTrue(table.contains(me:getPile(PILE), c1.id), "该牌应置于武将牌上")
    lu.assertEquals(me:getMark(COUNT), 1, "本回合悍难次数应为1")
  end)
end)

-- 测试：武将牌上出现重复花色时，只把多余的那张置入弃牌堆，并从牌堆获得等量的该花色牌
j_hannan:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  local handBefore
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_hannan.name)
    room:setTag(LAST_TAG, {})
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function() return true end

    local slash = Fk:cloneCard("slash")
    -- 第一次：黑桃进弃牌堆 → 悍难置于武将牌
    c1 = room:printCard("jink", Card.Spade, 4)
    room:moveCards{ ids = { c1.id }, toArea = Card.DiscardPile, moveReason = fk.ReasonDiscard }
    room.logic:trigger(fk.TargetConfirmed, comp2, { card = slash, to = comp2, from = me, tos = { comp2 } })

    handBefore = #me:getCardIds("h")
    -- 第二次：再来一张黑桃 → 武将为黑桃×2（重复）
    c2 = room:printCard("jink", Card.Spade, 8)
    room:moveCards{ ids = { c2.id }, toArea = Card.DiscardPile, moveReason = fk.ReasonDiscard }
    room.logic:trigger(fk.TargetConfirmed, comp2, { card = slash, to = comp2, from = me, tos = { comp2 } })

    room.askToSkillInvoke = origInvoke
  end)
  FkTest.runInRoom(function()
    local pile = me:getPile(PILE)
    lu.assertEquals(#pile, 1, "重复花色只应保留一张，多余的置入弃牌堆")
    lu.assertEquals(Fk:getCardById(pile[1]):getSuitString(), "spade", "保留的应是黑桃")

    local discarded = 0
    for _, id in ipairs({ c1.id, c2.id }) do
      if room:getCardArea(id) == Card.DiscardPile then discarded = discarded + 1 end
    end
    lu.assertEquals(discarded, 1, "只有多余的那一张应进弃牌堆，不是整组换掉")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 1, "应获得等量（1张）该花色的牌")
  end)
end)

return j_hannan
