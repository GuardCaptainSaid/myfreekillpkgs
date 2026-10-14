local w_jingwu = fk.CreateSkill {
  name = "w_jingwu",
}

Fk:loadTranslationTable{
  ["w_jingwu"] = "敬武",
  [":w_jingwu"] = "你可以将任意张点数之和为3的倍数的牌当做指定等量目标的【杀】使用，此【杀】指定目标后，目标角色需依次交给你一张手牌，否则此【杀】对其造成的伤害+1且其非锁定技失效至回合结束。（当一名角色使用【酒】或转化牌后（每回合限3次），你可观看其手牌并选择至多3张牌，这些牌本回合无距离及次数限制且伤害+X（X为已触发次数-1，至多+3））",

  ["#w_jingwu-give"] = "敬武：交给你一张手牌（否则此【杀】对其伤害+1且其非锁定技失效）",
  ["#w_jingwu-view"] = "敬武：观看 %src 的手牌，选择至多3张牌",

  ["$w_jingwu1"] = "敬若神明，武威八方！",
  ["$w_jingwu2"] = "吾之敬意，便是一刀！",
}

-- 房间标记牌集合（观看所选牌，本回合无距离次数限制且伤害+X）
local function markedIds(room)
  return room:getTag("w_jingwu_marked") or {}
end

local function isMarkedCard(room, card)
  if not card then return false end
  local ids = markedIds(room)
  if ids[card.id] then return true end
  for _, id in ipairs(card.subcards or {}) do
    if ids[id] then return true end
  end
  return false
end

-- 敬武【杀】：等量目标；观看所选牌本回合无距离及次数限制
w_jingwu:addEffect("targetmod", {
  extra_target_func = function(self, player, skill, card)
    if player:hasSkill(w_jingwu.name) and card and card.trueName == "slash"
      and card.skillName == w_jingwu.name then
      return #card.subcards - 1
    end
    return 0
  end,
  bypass_times = function(self, player, skill, scope, card, to)
    return isMarkedCard(player.room, card)
  end,
  bypass_distances = function(self, player, skill, card, to)
    return isMarkedCard(player.room, card)
  end,
})

-- 敬武：任意张点数之和为3的倍数的牌当【杀】使用
w_jingwu:addEffect("viewas", {
  anim_type = "offensive",
  card_filter = function(self, player, to_select, selected)
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    return #selected < 99
  end,
  filter_pattern = {
    min_num = 1,
    max_num = 99,
    pattern = ".",
  },
  view_as = function(self, player, cards)
    if #cards < 1 then return end
    local card = Fk:cloneCard("slash")
    card.skillName = w_jingwu.name
    card:addSubcards(cards)
    card.number = 3 -- 虚拟牌点数视为3（须在加子牌后设置）
    return card
  end,
  feasible = function(self, player, targets, selected_cards)
    if #selected_cards < 1 then return false end
    local sum = 0
    for _, id in ipairs(selected_cards) do
      sum = sum + Fk:getCardById(id).number
    end
    if sum % 3 ~= 0 then return false end
    return #targets == #selected_cards
  end,
  prompt = "#w_jingwu",
})

-- 此【杀】指定目标后：目标依次交一张手牌，否则惩罚标记
w_jingwu:addEffect(fk.TargetSpecified, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(w_jingwu.name) and not player.dead
      and data and data.card and data.card.trueName == "slash"
      and data.card.skillName == w_jingwu.name
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local punish = room:getTag("w_jingwu_punish") or {}
    punish[data.card.id] = punish[data.card.id] or {}
    for _, to in ipairs(data:getAllTargets()) do
      if to:isAlive() and not punish[data.card.id][to.id] then
        local cards = room:askToChooseCards(to, {
          target = to,
          flag = "h",
          min = 1,
          max = 1,
          cancelable = true,
          skill_name = w_jingwu.name,
          prompt = "#w_jingwu-give",
        })
        if cards and #cards > 0 then
          room:moveCardTo(cards, Card.PlayerHand, player, fk.ReasonGive, w_jingwu.name, nil, false, to)
        else
          punish[data.card.id][to.id] = true
          room:setPlayerMark(to, "w_jingwu_nojink", player.id)
        end
      end
    end
    room:setTag("w_jingwu_punish", punish)
  end,
})

-- 敬武【杀】对未交牌目标伤害+1（由武张飞视角全局判定）
w_jingwu:addEffect(fk.DamageInflicted, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(w_jingwu.name) then return false end
    if not data or not data.card or not data.from then return false end
    local punish = player.room:getTag("w_jingwu_punish") or {}
    local t = punish[data.card.id]
    return t and t[target.id] == true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data:changeDamage(1)
  end,
})

-- 未交牌目标非锁定技失效至回合结束
w_jingwu:addEffect("invalidity", {
  global = true,
  invalidity_func = function(self, from, skill)
    if from:getMark("w_jingwu_nojink") == 0 then return false end
    return not skill:hasTag(Skill.Compulsory) and not skill:hasTag(Skill.Limited)
  end,
})

-- 回合结束清除惩罚与观看次数
w_jingwu:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(w_jingwu.name)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room.alive_players) do
      if p:getMark("w_jingwu_nojink") ~= 0 then
        room:setPlayerMark(p, "w_jingwu_nojink", 0)
      end
    end
    room:setPlayerMark(player, "w_jingwu_view", 0)
    room:setTag("w_jingwu_marked", {})
    room:setTag("w_jingwu_punish", {})
  end,
})

-- 当一名角色使用【酒】或转化牌后（每回合限3次）：观看其手牌，选择至多3张牌
w_jingwu:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(w_jingwu.name) then return false end
    if player.dead then return false end
    if not data or not data.card or not data.from then return false end
    if data.from == player then return false end
    if player:getMark("w_jingwu_view") >= 3 then return false end
    local is_analeptic = data.card.trueName == "analeptic"
    local is_virtual = data.card:isVirtual()
      or (data.card.skillName ~= nil and data.card.skillName ~= "")
    if not (is_analeptic or is_virtual) then return false end
    if data.from:getCardIds("h") == nil or #data.from:getCardIds("h") == 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, {
      skill_name = w_jingwu.name,
      prompt = "#w_jingwu-view::" .. data.from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local times = player:getMark("w_jingwu_view")
    room:setPlayerMark(player, "w_jingwu_view", times + 1)
    local cards = room:askToChooseCards(player, {
      target = data.from,
      flag = "h",
      min = 0,
      max = 3,
      cancelable = true,
      skill_name = w_jingwu.name,
      prompt = "#w_jingwu-view::" .. data.from.id,
    })
    if cards and #cards > 0 then
      local marked = markedIds(room)
      for _, id in ipairs(cards) do
        marked[id] = true
      end
      room:setTag("w_jingwu_marked", marked)
    end
  end,
})

-- 观看所选牌造成伤害+X（X为已触发次数-1，至多+3）
w_jingwu:addEffect(fk.DamageCaused, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(w_jingwu.name) then return false end
    if not data or not data.card then return false end
    if not isMarkedCard(player.room, data.card) then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local times = 0
    for _, p in ipairs(room.alive_players) do
      if p:hasSkill(w_jingwu.name) then
        times = p:getMark("w_jingwu_view")
        break
      end
    end
    local x = math.min(math.max(times - 1, 0), 3)
    if x > 0 then
      data:changeDamage(x)
    end
  end,
})

-- 测试：点数之和为3的倍数的牌可转化为【杀】且等量目标
w_jingwu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, w_jingwu.name)
    local c1 = room:printCard("slash")
    c1.number = 1
    local c2 = room:printCard("peach")
    c2.number = 5
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[w_jingwu.name]:getSkeleton()
    local va_eff
    for _, spec in ipairs(skel.effect_spec_list) do
      if spec[1] == "viewas" then va_eff = spec[3] break end
    end
    local ids = me:getCardIds("h")
    lu.assertEquals(#ids, 2)
    local card = va_eff.view_as(va_eff, me, ids)
    lu.assertNotNil(card, "点数和为3倍数的牌应转化为杀")
    lu.assertEquals(card.name, "slash")
    lu.assertEquals(card.number, 3, "敬武杀点数视为3")
    lu.assertEquals(#card.subcards, 2)

    local tm_eff
    for _, spec in ipairs(skel.effect_spec_list) do
      if spec[1] == "targetmod" then tm_eff = spec[3] break end
    end
    lu.assertEquals(tm_eff.extra_target_func(tm_eff, me, nil, card), 1, "敬武杀额外目标=牌数-1")
  end)
end)

-- 测试：敬武杀指定目标后，目标不交牌则惩罚标记且伤害+1
w_jingwu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, w_jingwu.name)
  end)
  FkTest.runInRoom(function()
    local slash = Fk:cloneCard("slash")
    slash.skillName = w_jingwu.name
    slash:addSubcard(room:printCard("slash").id)
    FkTest.setNextReplies(comp2, { "" }) -- 拒绝交牌
    local use = UseCardData:new{ from = me, card = slash, tos = { comp2 } }
    room.logic:trigger(fk.TargetSpecified, me, use)
    lu.assertEquals(comp2:getMark("w_jingwu_nojink"), me.id, "不交牌目标应被惩罚标记")

    -- 伤害+1
    local dmg = DamageData:new{ from = me, to = comp2, damage = 1, damageType = fk.NormalDamage, card = slash }
    local room2 = room
    room2.logic:trigger(fk.DamageInflicted, comp2, dmg)
    lu.assertEquals(dmg.damage, 2, "敬武杀对未交牌目标伤害+1")
  end)
end)

-- 测试：观看所选牌（酒/转化牌后）本回合无距离次数限制且伤害+X
w_jingwu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, w_jingwu.name)
    room:setPlayerMark(me, "w_jingwu_view", 3) -- 已触发3次 → X=2
    local c1 = room:printCard("slash", Card.Heart, 1)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
    room:setTag("w_jingwu_marked", { [c1.id] = true })
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[w_jingwu.name]:getSkeleton()
    local tm_eff
    for _, spec in ipairs(skel.effect_spec_list) do
      if spec[1] == "targetmod" then tm_eff = spec[3] break end
    end
    local marked_card = Fk:getCardById(comp2:getCardIds("h")[1])
    lu.assertTrue(tm_eff.bypass_times(tm_eff, comp2, comp2, nil, marked_card, nil), "被标记牌应无次数限制")
    lu.assertTrue(tm_eff.bypass_distances(tm_eff, comp2, comp2, marked_card, nil), "被标记牌应无距离限制")

    local card = Fk:getCardById(comp2:getCardIds("h")[1])
    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage, card = card }
    room.logic:trigger(fk.DamageCaused, comp2, dmg)
    lu.assertEquals(dmg.damage, 3, "标记牌伤害应+X（X=次数-1=2）")
  end)
end)

return w_jingwu