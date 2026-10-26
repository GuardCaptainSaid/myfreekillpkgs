-- 刘伶·陶兀
-- 出牌阶段每种花色限一次，你可以展示所有手牌，然后弃置其中一种花色的所有手牌（至少一张）视为你使用一张不计次数限制的【酒】或【杀】。
local j_taowu = fk.CreateSkill {
  name = "j_taowu",
}

local SUIT_MARKS = {
  [Card.Spade] = "@j_taowu_s",
  [Card.Heart] = "@j_taowu_h",
  [Card.Diamond] = "@j_taowu_d",
  [Card.Club] = "@j_taowu_c",
}
local SUIT_KEYS = {
  [Card.Spade] = "j_taowu__spade",
  [Card.Heart] = "j_taowu__heart",
  [Card.Diamond] = "j_taowu__diamond",
  [Card.Club] = "j_taowu__club",
}
local SUIT_ORDER = { Card.Spade, Card.Heart, Card.Diamond, Card.Club }

Fk:loadTranslationTable{
  ["j_taowu"] = "陶兀",
  [":j_taowu"] = "出牌阶段每种花色限一次，你可以展示所有手牌，然后弃置其中一种花色的所有手牌（至少一张）视为你使用一张不计次数限制的【酒】或【杀】。",

  ["#j_taowu-suit"] = "陶兀：选择要弃置的手牌花色",
  ["#j_taowu-kind"] = "陶兀：视为使用一张【酒】或【杀】",
  ["#j_taowu-slash"] = "陶兀：选择此【杀】的目标",
  ["j_taowu__spade"] = "黑桃",
  ["j_taowu__heart"] = "红桃",
  ["j_taowu__diamond"] = "方块",
  ["j_taowu__club"] = "梅花",
  ["j_taowu__analeptic"] = "酒",
  ["j_taowu__slash"] = "杀",

  ["$j_taowu1"] = "天地为席，醉卧乾坤。",
  ["$j_taowu2"] = "杯酒在手，万事皆休。",
}

j_taowu:addEffect("active", {
  anim_type = "offensive",
  card_filter = Util.FalseFunc,
  target_num = 0,
  can_use = function(self, player)
    -- 客户端刷新技能按钮时也会调用 can_use，客户端玩家无 room 字段，须用 Fk:currentRoom()
    local room = Fk:currentRoom()
    if player.phase ~= Player.Play or (room and room.current ~= player) then return false end
    if player.dead or #player:getCardIds("h") == 0 then return false end
    local hand = player:getCardIds("h")
    for _, suit in ipairs(SUIT_ORDER) do
      if player:getMark(SUIT_MARKS[suit]) == 0 and
        table.find(hand, function(id) return Fk:getCardById(id).suit == suit end) then
        return true
      end
    end
    return false
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local hand = player:getCardIds("h")
    room:showCards(hand, player)
    -- 选择一种有牌且未用过的花色
    local choices = {}
    local choiceSuits = {}
    for _, suit in ipairs(SUIT_ORDER) do
      if player:getMark(SUIT_MARKS[suit]) == 0 and
        table.find(hand, function(id) return Fk:getCardById(id).suit == suit end) then
        table.insert(choices, SUIT_KEYS[suit])
        table.insert(choiceSuits, suit)
      end
    end
    local choice = room:askToChoice(player, {
      choices = choices,
      skill_name = j_taowu.name,
      prompt = "#j_taowu-suit",
    })
    local suit
    for i, c in ipairs(choices) do
      if c == choice then suit = choiceSuits[i] break end
    end
    if not suit then return end
    room:setPlayerMark(player, SUIT_MARKS[suit], 1)
    local discardIds = table.filter(hand, function(id) return Fk:getCardById(id).suit == suit end)
    room:throwCard(discardIds, j_taowu.name, player, player)
    -- 选择视为【酒】或【杀】
    local kind = room:askToChoice(player, {
      choices = { "j_taowu__analeptic", "j_taowu__slash" },
      skill_name = j_taowu.name,
      prompt = "#j_taowu-kind",
    })
    local card
    if kind == "j_taowu__analeptic" then
      card = Fk:cloneCard("analeptic")
    else
      card = Fk:cloneCard("slash")
    end
    room:setCardMark(card, MarkEnum.BypassTimesLimit, 1)
    if card.name == "analeptic" then
      room:useCard{ from = player, card = card, tos = { player } }
    else
      local candidates = table.filter(room:getOtherPlayers(player), function(p) return not p.dead end)
      if #candidates > 0 then
        local tos = room:askToChoosePlayers(player, {
          targets = candidates,
          min_num = 1,
          max_num = 1,
          cancelable = true,
          skill_name = j_taowu.name,
          prompt = "#j_taowu-slash",
        })
        if tos and #tos > 0 then
          room:useCard{ from = player, card = card, tos = tos }
        end
      end
    end
  end,
})

-- 测试：弃黑桃手牌视为使用【酒】
j_taowu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_taowu.name)
    me.maxHp = 3
    me.hp = 3
    room.current = me
    me.phase = Player.Play
    local s1 = room:printCard("slash", Card.Spade, 2)
    local s2 = room:printCard("jink", Card.Spade, 3)
    local h1 = room:printCard("peach", Card.Heart, 4)
    room:obtainCard(me, { s1, s2, h1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { { "j_taowu__spade" }, { "j_taowu__analeptic" } })
    local sk = Fk.skills[j_taowu.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(#me:getCardIds("h"), handBefore - 2, "陶兀：应弃置2张黑桃手牌")
    lu.assertEquals(me:getMark("@j_taowu_s"), 1, "陶兀：黑桃花色应标记已用")
    lu.assertEquals(me.drank, 1, "陶兀：应视为使用一张酒")
  end)
end)

-- 测试：弃红桃手牌视为使用【杀】造成伤害
j_taowu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_taowu.name)
    me.maxHp = 3
    me.hp = 3
    room.current = me
    me.phase = Player.Play
    local h1 = room:printCard("peach", Card.Heart, 2)
    local h2 = room:printCard("peach", Card.Heart, 3)
    local d1 = room:printCard("jink", Card.Diamond, 4)
    room:obtainCard(me, { h1, h2, d1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    -- 清空 comp2 手牌，确保转化杀必中（排除初始手牌闪的影响）
    if #comp2:getCardIds("h") > 0 then
      room:throwCard(comp2:getCardIds("h"), "test", comp2, comp2)
    end
    local hpBefore = comp2.hp
    FkTest.setNextReplies(me, { { "j_taowu__heart" }, { "j_taowu__slash" }, FkTest.ReplyChoosePlayer({ comp2 }) })
    local sk = Fk.skills[j_taowu.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(me:getMark("@j_taowu_h"), 1, "陶兀：红桃花色应标记已用")
    lu.assertEquals(comp2.hp, hpBefore - 1, "陶兀：转化杀应对目标造成1点伤害")
  end)
end)

return j_taowu
