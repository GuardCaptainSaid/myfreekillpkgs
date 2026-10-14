-- 君孙权·铸防
-- 出牌阶段限一次，你可将两张的手牌当作【长江天堑】使用（可重叠）然后摸一张牌。每轮限一次，若你的装备区有【长江天堑】，其他角色对你使用【杀】时，你可以弃置一张牌并令其展示两张手牌（不足则全展示），若花色与你弃置的手牌相同，你获得其展示的牌。
local j_zhufang = fk.CreateSkill {
  name = "j_zhufang",
}

Fk:loadTranslationTable{
  ["j_zhufang"] = "铸防",
  [":j_zhufang"] = "出牌阶段限一次，你可将两张手牌当作【长江天堑】使用（可重叠）然后摸一张牌。每轮限一次，若你的装备区有【长江天堑】，其他角色对你使用【杀】时，你可以弃置一张牌并令其展示两张手牌（不足则全展示），若花色与你弃置的手牌相同，你获得其展示的牌。",

  ["#j_zhufang-viewas"] = "铸防：将两张手牌当作【长江天堑】使用",
  ["#j_zhufang-invoke"] = "铸防：是否弃置一张牌并令其展示两张手牌？",
  ["#j_zhufang-discard"] = "铸防：弃置一张牌",
  ["#j_zhufang-show"] = "铸防：选择要展示的两张手牌（不足则全展示）",
  ["@j_zhufang_round"] = "铸防",

  ["$j_zhufang1"] = "铁锁横江，天堑自固！",
  ["$j_zhufang2"] = "固若金汤，安如磐石！",
}

-- 装备区长江天堑判断（支持虚拟装备）
local function isChangjiang(player, id)
  local ve = player:getVirtualEquip(id)
  if ve then return ve.name == "j_changjiang" end
  return Fk:getCardById(id).name == "j_changjiang"
end
j_zhufang.isChangjiang = isChangjiang

local function countChangjiang(player)
  local n = 0
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    if isChangjiang(player, id) then n = n + 1 end
  end
  return n
end
j_zhufang.countChangjiang = countChangjiang

-- 出牌阶段限一次：两张手牌当长江天堑使用，然后摸一张牌（可重叠）
j_zhufang:addEffect("viewas", {
  anim_type = "defensive",
  prompt = "#j_zhufang-viewas",
  pattern = "j_changjiang",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    return #selected < 2
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play and player:usedSkillTimes(j_zhufang.name, Player.HistoryPhase) == 0
  end,
  view_as = function(self, player, cards)
    if #cards ~= 2 then return nil end
    local new_card = Fk:cloneCard("j_changjiang")
    new_card:addSubcards(cards)
    new_card.skillName = j_zhufang.name
    return new_card
  end,
})

-- 使用后：摸一张牌；若装备区已有长江天堑则加宝物槽实现重叠
j_zhufang:addEffect(fk.CardUsing, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zhufang.name) then return false end
    return data.card and data.card.skillName == j_zhufang.name
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 可重叠：装备区已有长江天堑时增加宝物槽，避免被替换
    if countChangjiang(player) > 0 then
      room:addPlayerEquipSlots(player, { Player.TreasureSlot })
    end
    player:drawCards(1, j_zhufang.name)
  end,
})

-- 每轮限一次：装备区有长江天堑时，其他角色对你使用【杀】→ 弃置一张牌令其展示两张手牌
j_zhufang:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zhufang.name, true) or player.dead then return false end
    if player:getMark("@j_zhufang_round-round") > 0 then return false end
    if countChangjiang(player) == 0 then return false end
    if not data.card or not data.from or data.from == player then return false end
    local n = data.card.name
    if n ~= "slash" and n ~= "fire__slash" and n ~= "thunder__slash" then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_zhufang.name, prompt = "#j_zhufang-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    room:setPlayerMark(player, "@j_zhufang_round-round", 1)
    if player:isAllNude() then return end
    local c = room:askToChooseCards(player, {
      target = player,
      flag = "hej",
      min = 1,
      max = 1,
      cancelable = false,
      pattern = ".",
      skill_name = j_zhufang.name,
      prompt = "#j_zhufang-discard",
    })
    if not c or #c == 0 then return end
    room:throwCard(c, j_zhufang.name, player, player)
    local suit = Fk:getCardById(c[1]).suit
    -- 令其展示两张手牌（不足则全展示）
    local hand = from:getCardIds("h")
    if #hand == 0 then return end
    local n = math.min(2, #hand)
    local shown = room:askToChooseCards(from, {
      target = from,
      flag = "h",
      min = n,
      max = n,
      cancelable = false,
      pattern = ".",
      skill_name = j_zhufang.name,
      prompt = "#j_zhufang-show",
    })
    room:showCards(shown, from)
    -- 花色相同则获得其展示的牌
    local match = false
    for _, id in ipairs(shown) do
      if Fk:getCardById(id).suit == suit then match = true break end
    end
    if match then
      room:obtainCard(player, shown, true, fk.ReasonGive, from, j_zhufang.name)
    end
  end,
})

-- 测试：铸防装备重叠 + 摸牌
j_zhufang:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhufang.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    local h1 = room:printCard("slash", Card.Spade, 2)
    local h2 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(me, { h1, h2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local eff
    for _, spec in ipairs(j_zhufang.effect_spec_list) do
      if spec[1] == "viewas" then eff = spec[3] break end
    end
    lu.assertTrue(eff.enabled_at_play(eff, me), "铸防：出牌阶段应可使用")
    local hand = me:getCardIds("h")
    local handBefore = #hand
    local vc = eff.view_as(eff, me, hand)
    lu.assertTrue(vc ~= nil and vc.name == "j_changjiang", "铸防：应转化为长江天堑")
    room:useCard{ from = me, card = vc, tos = { me } }
    lu.assertEquals(countChangjiang(me), 1, "铸防：装备区应有1张长江天堑")
    lu.assertEquals(#me:getCardIds("h"), handBefore - 2 + 1, "铸防：使用后应摸1张牌")
    -- 第二次铸防：重叠（加槽）
    room:setPlayerMark(me, "@j_zhufang_round-round", 0)
    local h3 = room:printCard("slash", Card.Club, 4)
    local h4 = room:printCard("peach", Card.Diamond, 5)
    room:obtainCard(me, { h3, h4 }, true, fk.ReasonDraw, me, "test")
    local slotsBefore = 0
    for _, s in ipairs(me.equipSlots) do if s == Player.TreasureSlot then slotsBefore = slotsBefore + 1 end end
    local vc2 = eff.view_as(eff, me, me:getCardIds("h"))
    room:useCard{ from = me, card = vc2, tos = { me } }
    lu.assertEquals(countChangjiang(me), 2, "铸防：应可重叠装备2张长江天堑")
    local slotsAfter = 0
    for _, s in ipairs(me.equipSlots) do if s == Player.TreasureSlot then slotsAfter = slotsAfter + 1 end end
    lu.assertEquals(slotsAfter, slotsBefore + 1, "铸防：重叠时应增加宝物槽")
  end)
end)

-- 测试：被杀时展示手牌、花色相同则获得
j_zhufang:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhufang.name)
    me.maxHp = 4
    me.hp = 4
    room.current = comp2
    comp2.phase = Player.Play
    -- me 装备长江天堑（虚拟装备：用真实宝物代替——直接用卡定义实体）
    local cj = room:printCard("j_changjiang", Card.Spade, 7)
    room:moveCardTo(cj, Player.Equip, me, fk.ReasonPut, j_zhufang.name)
    -- me 手牌一张黑桃闪（弃牌）
    local d = room:printCard("jink", Card.Spade, 3)
    room:obtainCard(me, { d }, true, fk.ReasonDraw, me, "test")
    -- comp2 手牌两张：一张黑桃杀一张方块桃（展示两张黑桃? 造同花色：黑桃杀+黑桃闪）
    local s1 = room:printCard("slash", Card.Spade, 5)
    local s2 = room:printCard("jink", Card.Spade, 6)
    room:obtainCard(comp2, { s1, s2 }, true, fk.ReasonDraw, comp2, "test")
    -- 使用杀
    FkTest.setNextReplies(me, { "1", { d }, { s1, s2 } })
    room:useCard{ from = comp2, card = comp2:getCardIds("h")[1], tos = { me } }
    lu.assertTrue(table.contains(me:getCardIds("h"), s1), "铸防：应获得展示的同花色牌")
    lu.assertTrue(table.contains(me:getCardIds("h"), s2), "铸防：应获得展示的全部牌")
    lu.assertEquals(me:getMark("@j_zhufang_round-round"), 1, "铸防：每轮限一次应记录")
  end)
end)

return j_zhufang