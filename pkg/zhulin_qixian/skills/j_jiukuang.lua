-- 刘伶·酒狂
-- 你使用酒无次数限制，你使用酒时摸一张牌。
local j_jiukuang = fk.CreateSkill {
  name = "j_jiukuang",
}

Fk:loadTranslationTable{
  ["j_jiukuang"] = "酒狂",
  [":j_jiukuang"] = "你使用酒无次数限制，你使用酒时摸一张牌。",

  ["$j_jiukuang1"] = "酒逢知己千杯少。",
  ["$j_jiukuang2"] = "饮者留其名！",
}

-- 使用酒无次数限制（仅对酒生效）
j_jiukuang:addEffect("targetmod", {
  bypass_times = function(self, player, skill, scope, card)
    if skill and skill.name == "analeptic_skill" then return true end
    return false
  end,
})

-- 使用酒时摸一张牌
j_jiukuang:addEffect(fk.CardUsing, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_jiukuang.name) or player.dead then return false end
    return data.card and data.card.trueName == "analeptic"
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, j_jiukuang.name)
  end,
})

-- 测试：使用酒时摸一张牌
j_jiukuang:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiukuang.name)
    me.maxHp = 3
    me.hp = 3
    room.current = me
    me.phase = Player.Play
    local w = room:printCard("analeptic", Card.Spade, 3)
    room:obtainCard(me, { w }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local handBefore = #me:getCardIds("h")
    local c = Fk:getCardById(me:getCardIds("h")[1])
    lu.assertEquals(c.trueName, "analeptic", "酒狂：前置检查")
    room:useCard{ from = me, card = c, tos = { me } }
    -- 酒被消耗（-1）后摸1张 → 手牌数不变；若未摸牌则为 handBefore-1
    lu.assertEquals(#me:getCardIds("h"), handBefore, "酒狂：使用酒后应摸1张")
    lu.assertEquals(me.drank, 1, "酒狂：酒效果应生效")
  end)
end)

return j_jiukuang