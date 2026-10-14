local w_wuxian = fk.CreateSkill {
  name = "w_wuxian",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["w_wuxian"] = "武贤",
  [":w_wuxian"] = "限定技，出牌阶段，你可以重铸手上一种颜色的牌并令其伤害加一，另一种颜色手牌点数均视为三。",

  ["w_wuxian_red"] = "红色牌",
  ["w_wuxian_black"] = "黑色牌",

  ["$w_wuxian1"] = "贤者不以力胜，而兵戈自此生威！",
  ["$w_wuxian2"] = "颜色之变，亦为杀伐之道！",
}

-- 限定技：选择一种颜色，重铸该颜色手牌；该颜色牌伤害+1；另一颜色手牌点数视为3
w_wuxian:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    return player.phase == Player.Play
      and player:usedSkillTimes(w_wuxian.name, Player.HistoryGame) == 0
  end,
  interaction = UI.OptionBox {
    options = { "w_wuxian_red", "w_wuxian_black" },
    direct_send = true,
  },
  on_use = function(self, room, effect)
    local player = effect.from
    local chosen_color = self.interaction.data == "w_wuxian_red" and Card.Red or Card.Black

    -- 重铸手中该颜色牌
    local recast = table.filter(player:getCardIds("h"), function(id)
      return Fk:getCardById(id).color == chosen_color
    end)
    if #recast > 0 then
      room:recastCard(recast, player, w_wuxian.name)
    end

    -- 标记：该颜色牌伤害+1；另一颜色手牌点数视为三
    room:setPlayerMark(player, "w_wuxian_color", chosen_color)
    for _, id in ipairs(player:getCardIds("h")) do
      local c = Fk:getCardById(id)
      if c.color ~= chosen_color and c:getMark("w_wuxian_num3") == 0 then
        room:setCardMark(c, "w_wuxian_num3", 1)
      end
    end
  end,
})

-- 该颜色牌造成伤害+1
w_wuxian:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(w_wuxian.name) then return false end
    local color_mark = player:getMark("w_wuxian_color")
    if color_mark == 0 then return false end
    return data and data.card and data.card.color == color_mark
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data:changeDamage(1)
  end,
})

-- 测试：选择红色 → 重铸红色手牌、标记黑色手牌点数视为3
w_wuxian:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, w_wuxian.name)
    local r1 = room:printCard("peach", Card.Heart, 4)       -- 红
    local b1 = room:printCard("slash", Card.Spade, 5)       -- 黑
    room:obtainCard(me, { r1, b1 }, true, fk.ReasonDraw, me, "test")
    room:setPlayerMark(me, "w_wuxian_used", 1)
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[w_wuxian.name]:getSkeleton()
    local act_eff
    for _, spec in ipairs(skel.effect_spec_list) do
      if spec[1] == "active" then act_eff = spec[3] break end
    end
    act_eff.interaction.data = "w_wuxian_red"
    local hand = me:getCardIds("h")
    lu.assertEquals(#hand, 2)
    local red_id, black_id
    for _, id in ipairs(hand) do
      if Fk:getCardById(id).color == Card.Red then red_id = id else black_id = id end
    end
    lu.assertNotNil(red_id)
    lu.assertNotNil(black_id)
    act_eff.on_use(act_eff, room, { from = me })

    -- 红色牌被重铸（不再在手牌，换成新摸的牌），黑色牌保留且点数视为3
    local kept_ids = me:getCardIds("h")
    lu.assertFalse(table.contains(kept_ids, red_id), "红色手牌应被重铸弃置")
    lu.assertTrue(table.contains(kept_ids, black_id), "黑色手牌应保留")
    local kept = Fk:getCardById(black_id)
    lu.assertEquals(kept:getMark("w_wuxian_num3"), 1, "另一颜色手牌应标记点数视为3")
    lu.assertEquals(me:getMark("w_wuxian_color"), Card.Red, "应记录所选颜色为红色")
  end)
end)

-- 测试：红色牌造成伤害+1
w_wuxian:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, w_wuxian.name)
    room:setPlayerMark(me, "w_wuxian_color", Card.Red)
  end)
  FkTest.runInRoom(function()
    local red_card = Fk:cloneCard("slash", Card.Heart, 5)
    local dmg = DamageData:new{ from = me, to = comp2, damage = 1, damageType = fk.NormalDamage, card = red_card }
    room.logic:trigger(fk.DamageCaused, me, dmg)
    lu.assertEquals(dmg.damage, 2, "武贤所选颜色牌伤害+1")

    local black_card = Fk:cloneCard("slash", Card.Spade, 5)
    local dmg2 = DamageData:new{ from = me, to = comp2, damage = 1, damageType = fk.NormalDamage, card = black_card }
    room.logic:trigger(fk.DamageCaused, me, dmg2)
    lu.assertEquals(dmg2.damage, 1, "非所选颜色牌伤害不变")
  end)
end)

return w_wuxian