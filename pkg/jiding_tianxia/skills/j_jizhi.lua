local j_jizhi = fk.CreateSkill {
  name = "j_jizhi",
}

Fk:loadTranslationTable{
  ["j_jizhi"] = "计智",
  [":j_jizhi"] = "出牌阶段，你可将X+1张花色不同的手牌当作一张本轮未使用过的普通锦囊牌使用。（X为本轮此技能发动的次数）",

  ["#j_jizhi-viewas"] = "计智：选择X+1张花色不同的手牌",

  ["$j_jizhi1"] = "运筹帷幄，决胜千里！",
  ["$j_jizhi2"] = "以智取胜，方为上策。",
}

-- 本轮未使用过的普通锦囊候选（核心自动按牌名记录本轮使用历史）
local function available_tricks(player)
  local names = {}
  for _, name in ipairs(Fk:getAllCardNames("t", true)) do
    if player:usedCardTimes(name, Player.HistoryRound) == 0 then
      table.insert(names, name)
    end
  end
  return names
end

j_jizhi:addEffect("viewas", {
  anim_type = "offensive",
  prompt = "#j_jizhi-viewas",
  pattern = ".",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    local X = player:getMark("j_jizhi_count-round") or 0
    if #selected >= X + 1 then return false end
    if not table.contains(player:getHandlyIds(), to_select) then return false end

    local card = Fk:getCardById(to_select)
    local suit = card.suit
    for _, cid in ipairs(selected) do
      if Fk:getCardById(cid).suit == suit then
        return false
      end
    end
    return true
  end,
  interaction = function(self, player)
    return UI.CardNameBox { choices = available_tricks(player) }
  end,
  view_as = function(self, player, cards)
    if not self.interaction.data or #cards < 1 then return nil end

    local X = player:getMark("j_jizhi_count-round") or 0
    if #cards ~= X + 1 then return nil end

    local suits = {}
    for _, cid in ipairs(cards) do
      local suit = Fk:getCardById(cid).suit
      if suits[suit] then return nil end
      suits[suit] = true
    end

    local new_card = Fk:cloneCard(self.interaction.data)
    new_card:addSubcards(cards)
    new_card.skillName = j_jizhi.name
    return new_card
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play
  end,
  enabled_at_response = function(self, player, response)
    return false
  end,
  before_use = function(self, player, use)
    local count = player:getMark("j_jizhi_count-round") or 0
    player.room:setPlayerMark(player, "j_jizhi_count-round", count + 1)
  end,
})

-- 测试：候选锦囊排除本轮已使用过的
j_jizhi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jizhi.name)
    me:addCardUseHistory("wufeng", 1)
  end)
  local names = available_tricks(me)
  lu.assertFalse(table.contains(names, "wufeng"), "已使用过的锦囊不应出现在候选")
  lu.assertTrue(#names > 0, "候选锦囊不应为空")
end)

-- 获取 viewas 效果实例（interaction/viewAs 所在）
local function viewas_effect()
  local skel = Fk.skills[j_jizhi.name]:getSkeleton()
  return skel.effects[1]
end

-- 测试：X=0 时用 1 张手牌转化为本轮未用过的普通锦囊
j_jizhi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jizhi.name)
    local c1 = room:printCard("slash", Card.Heart, 1)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    local eff = viewas_effect()
    local tricks = Fk:getAllCardNames("t", true)
    eff.interaction.data = tricks[1]
    local card = eff:viewAs(me, { c1.id })
    lu.assertNotNil(card, "X=0 时 1 张手牌应能转化为普通锦囊")
    lu.assertEquals(card.name, tricks[1])
    lu.assertEquals(#card.subcards, 1)
  end)
end)

-- 测试：超过 X+1 张或花色重复时不能转化
j_jizhi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jizhi.name)
    local c1 = room:printCard("slash", Card.Heart, 1)
    local c2 = room:printCard("slash", Card.Diamond, 2)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    local eff = viewas_effect()
    local tricks = Fk:getAllCardNames("t", true)
    eff.interaction.data = tricks[1]
    local card = eff:viewAs(me, { c1.id, c2.id })
    lu.assertNil(card, "X=0 时最多允许 1 张牌，2 张不应转化")
    local same = eff:viewAs(me, { c1.id })
    -- 单张不同花色仍可用
    lu.assertNotNil(same, "1 张手牌转化应成功")
  end)
end)

return j_jizhi