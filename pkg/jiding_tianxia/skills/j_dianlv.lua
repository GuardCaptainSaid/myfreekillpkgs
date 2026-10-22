-- 计陈群·典律
-- 出牌阶段限一次，你可以弃置一张手牌，将其当做任意一张普通锦囊牌使用；
-- 若本回合你发动过【定品】，你可以额外将一张手牌当做【杀】使用。
local j_dianlv = fk.CreateSkill {
  name = "j_dianlv",
}

Fk:loadTranslationTable{
  ["j_dianlv"] = "典律",
  [":j_dianlv"] = "出牌阶段限一次，你可以弃置一张手牌，将其当做任意一张普通锦囊牌使用；若本回合你发动过【定品】，你可以额外将一张手牌当做【杀】使用。",

  ["#j_dianlv"] = "典律：弃置一张手牌当做普通锦囊使用",
  ["#j_dianlv-use"] = "典律：将该牌当做一张普通锦囊牌使用",
  ["#j_dianlv-slash"] = "典律（本回合发动过定品）：可将一张手牌当做【杀】使用",
}

-- 所有普通锦囊牌名（收集引擎已注册的卡牌类型，排除延时锦囊）
local function commonTrickNames()
  local names = {}
  for _, card in pairs(Fk.all_card_types) do
    if card.type == Card.TypeTrick and card.sub_type ~= Card.SubtypeDelayedTrick
      and Fk.all_card_types[card.trueName] then
      table.insertIfNeed(names, card.trueName)
    end
  end
  return names
end

j_dianlv:addEffect("active", {
  anim_type = "control",
  prompt = "#j_dianlv",
  min_card_num = 1,
  max_card_num = 1,
  target_num = 0,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:usedSkillTimes(j_dianlv.name, Player.HistoryPhase) > 0 then return false end
    return #player:getCardIds("h") > 0
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and table.contains(player:getCardIds("h"), to_select)
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_cards == 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local cardId = effect.cards and effect.cards[1]
    if not cardId then return end
    -- 弃置该手牌，当做任意一张普通锦囊牌使用（namebox 只列出当前有合法目标的锦囊）
    local use = room:askToUseVirtualCard(player, {
      name = commonTrickNames(),
      skill_name = j_dianlv.name,
      subcards = { cardId },
      cancelable = true,
      prompt = "#j_dianlv-use",
    })
    if not use then return end -- 取消则牌仍留在手中
    -- 若本回合发动过定品：可额外将一张手牌当做【杀】使用
    if player.dead then return end
    if player:getMark("j_dingpin_used-turn") > 0 then
      room:askToUseVirtualCard(player, {
        name = "slash",
        skill_name = j_dianlv.name,
        cancelable = true,
        card_filter = { n = { 1, 1 }, pattern = ".", cards = player:getCardIds("h") },
        prompt = "#j_dianlv-slash",
      })
    end
  end,
})

-- 测试：发动典律 → 询问普通锦囊（含弃置的手牌作为实体牌）；发动过定品则追加询问手牌当杀
j_dianlv:addTest(function(room, me)
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_dianlv.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)
    c2 = room:printCard("jink", Card.Heart, 8)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local calls = {}
    local origUse = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then
        table.insert(calls, params)
        return { from = me, card = Fk:cloneCard("ex_nihilo") }
      end
      return origUse(self, who, params)
    end

    local skel = Fk.skills[j_dianlv.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")

    -- 未发动定品：只有一次锦囊询问
    spec:on_use(room, { from = me, cards = { c1.id } })
    lu.assertEquals(#calls, 1, "未发动定品只应有一次询问")
    lu.assertTrue(type(calls[1].name) == "table", "应以候选锦囊名列表询问")
    lu.assertTrue(#calls[1].name > 0, "候选应包含普通锦囊")
    lu.assertFalse(table.contains(calls[1].name, "lightning"), "不应包含延时锦囊")
    lu.assertTrue(table.contains(calls[1].subcards or {}, c1.id), "询问应带上弃置的手牌")

    -- 发动过定品：追加一次杀询问
    room:setPlayerMark(me, "j_dingpin_used-turn", 1)
    spec:on_use(room, { from = me, cards = { c2.id } })
    lu.assertEquals(#calls, 3, "发动定品后应有锦囊+杀两次询问")
    lu.assertEquals(calls[3].name, "slash", "第二次应为杀")
    lu.assertEquals(calls[3].card_filter.n[1], 1, "杀应从一张手牌转化")

    room.askToUseVirtualCard = origUse
  end)
end)

-- 测试：取消锦囊选择 → 牌仍在手中
j_dianlv:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_dianlv.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local origUse = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then return end -- 取消
      return origUse(self, who, params)
    end

    local skel = Fk.skills[j_dianlv.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    spec:on_use(room, { from = me, cards = { c1.id } })
    room.askToUseVirtualCard = origUse
    lu.assertTrue(table.contains(me:getCardIds("h"), c1.id), "取消后牌应仍在手中")
  end)
end)

return j_dianlv
