local w_yimeng = fk.CreateSkill {
  name = "w_yimeng",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["w_yimeng"] = "毅猛",
  [":w_yimeng"] = "锁定技。你使用点数不小于3的牌无次数限制。你使用点数不大于3的牌无距离限制。你使用点数为3的牌时摸一张牌。你使用的虚拟牌转化牌点数均视为3。（你可以重铸一张杀或点数为三倍数的牌并视为对一名角色使用一张杀，不计入次数）",

  ["#w_yimeng-viewas"] = "毅猛：重铸一张【杀】或点数为三倍数的牌，视为对一名角色使用【杀】",

  ["$w_yimeng1"] = "燕人张飞在此，谁敢放肆！",
  ["$w_yimeng2"] = "丈八蛇矛，扫尽天下不平！",
}

-- 点数辅助：武贤发动后“另一种颜色手牌点数均视为三”
local function effNumber(card)
  if card and card:getMark("w_wuxian_num3") > 0 then return 3 end
  return card and card.number or 0
end

-- 点数不小于3的牌无次数限制；点数不大于3的牌无距离限制
w_yimeng:addEffect("targetmod", {
  bypass_times = function(self, player, skill, scope, card, to)
    return player:hasSkill(w_yimeng.name) and card and effNumber(card) >= 3
  end,
  bypass_distances = function(self, player, skill, card, to)
    return player:hasSkill(w_yimeng.name) and card and effNumber(card) <= 3
  end,
})

-- 使用点数为3的牌时摸一张牌
w_yimeng:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(w_yimeng.name) and not player.dead
      and data and data.card and not data.responseToEvent and not data.toCard
      and effNumber(data.card) == 3
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, w_yimeng.name)
  end,
})

-- 重铸一张【杀】或点数为三倍数的牌，视为对一名角色使用【杀】（不计入次数）
w_yimeng:addEffect("viewas", {
  anim_type = "offensive",
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    local c = Fk:getCardById(to_select)
    return c.trueName == "slash" or c.number % 3 == 0
  end,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local card = Fk:cloneCard("slash")
    card.skillName = w_yimeng.name
    card:addSubcard(cards[1])
    card.number = 3 -- 虚拟牌点数视为3（须在加子牌后设置）
    return card
  end,
  prompt = "#w_yimeng-viewas",
})

-- 测试：点数不小于3的牌无次数限制，点数不大于3的牌无距离限制
w_yimeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, w_yimeng.name)
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[w_yimeng.name]:getSkeleton()
    local tm_eff
    for _, spec in ipairs(skel.effect_spec_list) do
      if spec[1] == "targetmod" then tm_eff = spec[3] break end
    end

    local c5 = Fk:cloneCard("slash")
    c5.number = 5
    lu.assertTrue(tm_eff.bypass_times(tm_eff, me, me, nil, c5, nil), "点数5的牌应无次数限制")
    lu.assertFalse(tm_eff.bypass_distances(tm_eff, me, me, c5, nil), "点数5的牌不应无距离")
    local c2 = Fk:cloneCard("slash")
    c2.number = 2
    lu.assertTrue(tm_eff.bypass_distances(tm_eff, me, me, c2, nil), "点数2的牌应无距离限制")
    lu.assertFalse(tm_eff.bypass_times(tm_eff, me, me, nil, c2, nil), "点数2的牌不应无次数")
    local c3 = Fk:cloneCard("slash")
    c3.number = 3
    lu.assertTrue(tm_eff.bypass_times(tm_eff, me, me, nil, c3, nil), "点数3的牌无次数限制")
    lu.assertTrue(tm_eff.bypass_distances(tm_eff, me, me, c3, nil), "点数3的牌无距离限制")
  end)
end)

-- 测试：使用点数为3的牌后摸一张
w_yimeng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, w_yimeng.name)
  end)
  FkTest.runInRoom(function()
    local c3 = room:printCard("slash")
    c3.number = 3
    local hand_before = #me:getCardIds("h")
    local use = UseCardData:new{ from = me, card = c3, tos = { comp2 } }
    room.logic:trigger(fk.CardUseFinished, me, use)
    lu.assertEquals(#me:getCardIds("h"), hand_before + 1, "使用点数3的牌应摸一张")
  end)
end)

-- 测试：重铸杀/三倍数牌视为【杀】使用（虚拟牌点数视为3）
w_yimeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, w_yimeng.name)
    local c1 = room:printCard("slash")
    local c6 = room:printCard("peach")
    c6.number = 6
    room:obtainCard(me, { c1, c6 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[w_yimeng.name]:getSkeleton()
    local va_eff
    for _, spec in ipairs(skel.effect_spec_list) do
      if spec[1] == "viewas" then va_eff = spec[3] break end
    end
    local card = va_eff.view_as(va_eff, me, { me:getCardIds("h")[1] })
    lu.assertNotNil(card, "杀/三倍数牌应能转化为杀")
    lu.assertEquals(card.name, "slash")
    lu.assertEquals(card.number, 3, "转化牌点数应视为3")
    lu.assertEquals(card.skillName, w_yimeng.name)
  end)
end)

return w_yimeng