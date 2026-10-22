-- 计陈群·定品
-- 出牌阶段限一次，你可以选择一名角色，交给其至多3张牌，以此定其乡品：
-- 至少1张（下品）：其本轮使用牌无距离限制；
-- 交至少2张（中品）：你与其本轮使用或打出手牌时摸一张牌；
-- 交至少3张（上品）：该角色与你本轮使用牌无次数限制。
local j_dingpin = fk.CreateSkill {
  name = "j_dingpin",
}

Fk:loadTranslationTable{
  ["j_dingpin"] = "定品",
  [":j_dingpin"] = "出牌阶段限一次，你可以选择一名角色，交给其至多3张牌，以此定其乡品：至少1张（下品），其本轮使用牌无距离限制；交至少2张（中品），你与其本轮使用或打出手牌时摸一张牌；交至少3张（上品），该角色与你本轮使用牌无次数限制。",

  ["#j_dingpin"] = "定品：选择一名角色，交给其至多3张手牌定其乡品",
  -- @@ 前缀标记只显示翻译后的纯文字（勿用带后缀的 @ 标记，会显示原始标记名）
  ["@@j_dingpin_pin1-round"] = "下品",
  ["@@j_dingpin_pin2-round"] = "中品",
  ["@@j_dingpin_pin3-round"] = "上品",
}

-- 出牌阶段限一次：选一名角色，交至多3张手牌
j_dingpin:addEffect("active", {
  anim_type = "control",
  prompt = "#j_dingpin",
  min_card_num = 1,
  max_card_num = 3,
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    return player:usedSkillTimes(j_dingpin.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected < 3 and table.contains(player:getCardIds("h"), to_select)
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    return #selected == 0 and #selected_cards > 0
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_targets == 1 and #selected_cards >= 1 and #selected_cards <= 3
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local ids = effect.cards
    if not target or target.dead or not ids or #ids == 0 then return end
    -- 交给其牌（明置）
    room:moveCardTo(ids, Card.PlayerHand, target, fk.ReasonGive, j_dingpin.name, nil, true, player)
    local n = #ids
    -- 乡品等级显示（@@ 标记 → 纯文字"下品/中品/上品"，仅显示最高档）
    room:setPlayerMark(target, "@@j_dingpin_pin1-round", 0)
    room:setPlayerMark(target, "@@j_dingpin_pin2-round", 0)
    room:setPlayerMark(target, "@@j_dingpin_pin3-round", 0)
    room:setPlayerMark(target, ("@@j_dingpin_pin%d-round"):format(math.min(n, 3)), 1)
    -- 下品（至少1张）：其本轮使用牌无距离限制
    room:setPlayerMark(target, MarkEnum.BypassDistancesLimit .. "-round", 1)
    -- 中品（至少2张）：你与其本轮使用或打出手牌时摸一张牌
    if n >= 2 then
      room:setPlayerMark(target, "j_dingpin_mid-round", 1)
      room:setPlayerMark(player, "j_dingpin_mid-round", 1)
    end
    -- 上品（至少3张）：该角色与你本轮使用牌无次数限制
    if n >= 3 then
      room:setPlayerMark(target, MarkEnum.BypassTimesLimit .. "-round", 1)
      room:setPlayerMark(player, MarkEnum.BypassTimesLimit .. "-round", 1)
    end
    -- 供典律判定：本回合发动过定品
    room:setPlayerMark(player, "j_dingpin_used-turn", 1)
  end,
})

-- 中品：被定品者本轮使用手牌时摸一张牌
local function midDrawCanTrigger(self, event, target, player, data)
  if not player:hasSkill(j_dingpin.name) or player.dead then return false end
  local from = data.from
  if not from or from.dead then return false end
  if from:getMark("j_dingpin_mid-round") == 0 then return false end
  -- 必须是使用/打出手牌
  for _, info in ipairs(data.subcardsFromInfo or {}) do
    if info.fromArea == Card.PlayerHand then return true end
  end
  return false
end

j_dingpin:addEffect(fk.CardUsing, {
  global = true,
  -- 技能文本无“可以”，锁定发动
  on_cost = function() return true end,
  can_trigger = midDrawCanTrigger,
  on_use = function(self, event, target, player, data)
    player.room:drawCards(data.from, 1, j_dingpin.name)
  end,
})

j_dingpin:addEffect(fk.CardResponding, {
  global = true,
  on_cost = function() return true end,
  can_trigger = midDrawCanTrigger,
  on_use = function(self, event, target, player, data)
    player.room:drawCards(data.from, 1, j_dingpin.name)
  end,
})

-- 测试：交2张牌 → 目标获得下品+中品，陈群获得中品，记录典律联动标记
j_dingpin:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_dingpin.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)
    c2 = room:printCard("jink", Card.Heart, 8)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_dingpin.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")
    spec:on_use(room, { from = me, tos = { comp2 }, cards = { c1.id, c2.id } })

    lu.assertTrue(table.contains(comp2:getCardIds("h"), c1.id), "目标应获得交给的牌")
    lu.assertEquals(comp2:getMark("@@j_dingpin_pin2-round"), 1, "乡品应显示为中品")
    lu.assertEquals(comp2:getMark("@@j_dingpin_pin1-round"), 0, "只显示最高档，不应显示下品")
    lu.assertEquals(comp2:getMark("@@j_dingpin_pin3-round"), 0, "只显示最高档，不应显示上品")
    lu.assertNotNil(comp2:hasMark(MarkEnum.BypassDistancesLimit), "下品：目标使用牌应无距离限制")
    lu.assertEquals(comp2:getMark("j_dingpin_mid-round"), 1, "中品：目标应有摸牌标记")
    lu.assertEquals(me:getMark("j_dingpin_mid-round"), 1, "中品：你应有摸牌标记")
    lu.assertEquals(comp2:getMark(MarkEnum.BypassTimesLimit .. "-round"), 0, "未达上品不应有无次数限制")
    lu.assertEquals(me:getMark("j_dingpin_used-turn"), 1, "应记录本回合发动过定品")
  end)
end)

-- 测试：交3张牌 → 双方均获得上品（无次数限制）；中品下使用手牌摸一张牌
j_dingpin:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2, c3, s1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_dingpin.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)
    c2 = room:printCard("jink", Card.Heart, 8)
    c3 = room:printCard("peach", Card.Diamond, 9)
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
    s1 = room:printCard("slash", Card.Club, 10)
    room:obtainCard(comp2, { s1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_dingpin.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    spec:on_use(room, { from = me, tos = { comp2 }, cards = { c1.id, c2.id, c3.id } })

    lu.assertEquals(comp2:getMark("@@j_dingpin_pin3-round"), 1, "乡品应显示为上品")
    lu.assertEquals(comp2:getMark("@@j_dingpin_pin1-round"), 0, "只显示最高档，不应显示下品")
    lu.assertNotNil(comp2:hasMark(MarkEnum.BypassTimesLimit), "上品：目标使用牌应无次数限制")
    lu.assertNotNil(me:hasMark(MarkEnum.BypassTimesLimit), "上品：你使用牌应无次数限制")

    -- 中品：目标使用手牌时摸一张牌
    local handBefore = #comp2:getCardIds("h")
    room.logic:trigger(fk.CardUsing, comp2, {
      from = comp2,
      card = Fk:cloneCard("slash"),
      subcardsFromInfo = { { cardId = s1.id, fromArea = Card.PlayerHand } },
    })
    lu.assertEquals(#comp2:getCardIds("h"), handBefore + 1, "中品：使用手牌后应摸一张牌")
  end)
end)

return j_dingpin
