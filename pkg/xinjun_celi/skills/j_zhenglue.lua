-- 君袁术·征掠
-- 出牌阶段每名角色限一次，你可弃两枚"粮"，令一名其他角色选择：1.弃置两张牌并令你获得弃牌堆一张装备；2.受到你造成的1点火焰伤害并令你摸一张牌。
local j_zhenglue = fk.CreateSkill {
  name = "j_zhenglue",
}

Fk:loadTranslationTable{
  ["j_zhenglue"] = "征掠",
  [":j_zhenglue"] = "出牌阶段每名角色限一次，你可弃两枚“粮”，令一名其他角色选择：1.弃置两张牌并令你获得弃牌堆一张装备；2.受到你造成的1点火焰伤害并令你摸一张牌。",

  ["#j_zhenglue-choice"] = "征掠：请选择一项（1.弃置两张牌，袁术获得弃牌堆一张装备 2.受到1点火焰伤害，袁术摸一张牌）",
  ["#j_zhenglue-discard"] = "征掠：弃置两张牌",
  ["@j_zhenglue_used"] = "征掠",

  ["$j_zhenglue1"] = "粮秣所向，皆为吾用！",
  ["$j_zhenglue2"] = "掠取四方，充实府库！",
}

j_zhenglue:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    return player:getMark("@j_jiaochi_liang") >= 2
  end,
  target_filter = function(self, player, to_select, selected)
    if to_select == player then return false end
    if to_select:getMark("@j_zhenglue_used-turn") > 0 then return false end
    return true
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    if not target then return end
    -- 弃两枚粮
    j_jiaochi.loseLiang(room, player, 2)
    -- 每名角色限一次：记录目标
    room:setPlayerMark(target, "@j_zhenglue_used-turn", 1)
    -- 目标二选一
    local choice = room:askToChoice(target, { choices = { "1", "2" }, skill_name = j_zhenglue.name, prompt = "#j_zhenglue-choice" })
    if choice == "1" then
      -- 弃置两张牌
      local tc = target:getCardIds("hej")
      if #tc >= 2 then
        local c = room:askToChooseCards(target, {
          target = target,
          flag = "hej",
          min = 2,
          max = 2,
          cancelable = false,
          pattern = ".",
          skill_name = j_zhenglue.name,
          prompt = "#j_zhenglue-discard",
        })
        if c and #c > 0 then
          room:throwCard(c, j_zhenglue.name, target, target)
        end
      end
      -- 你获得弃牌堆一张装备
      local eqs = room:getCardsFromPileByRule("equip", 1, "discardPile")
      if #eqs > 0 then
        room:obtainCard(player, eqs, true, fk.ReasonGive, nil, j_zhenglue.name)
      end
    else
      -- 受到你造成的1点火焰伤害
      room:damage{ from = player, to = target, damage = 1, damageType = fk.FireDamage, skillName = j_zhenglue.name }
      if not player.dead then
        player:drawCards(1, j_zhenglue.name)
      end
    end
  end,
})

-- 测试：目标选2 → 火伤 + 你摸1
j_zhenglue:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhenglue.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "@j_jiaochi_liang", 3)
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local handBefore = #me:getCardIds("h")
    local hpBefore = comp2.hp
    FkTest.setNextReplies(comp2, { { "2" } })
    room:useActiveSkill(me, j_zhenglue.name, {}, { comp2 })
    lu.assertEquals(me:getMark("@j_jiaochi_liang"), 1, "征掠：应弃2枚粮")
    lu.assertEquals(comp2.hp, hpBefore - 1, "征掠：目标应受1点火焰伤害")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 1, "征掠：应摸1张牌")
    lu.assertEquals(comp2:getMark("@j_zhenglue_used-turn"), 1, "征掠：应记录目标限次")
  end)
end)

-- 测试：目标选1 → 弃2牌 + 你获得弃牌堆装备
j_zhenglue:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhenglue.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "@j_jiaochi_liang", 2)
    -- comp2 两张手牌
    local h1 = room:printCard("slash", Card.Spade, 5)
    local h2 = room:printCard("jink", Card.Heart, 6)
    room:obtainCard(comp2, { h1, h2 }, true, fk.ReasonDraw, comp2, "test")
    -- 弃牌堆放一张装备（crossbow）
    local eq = room:printCard("crossbow", Card.Diamond, 7)
    room:throwCard({ eq }, fk.ReasonDiscard, comp2, nil)
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local handBefore = #me:getCardIds("h")
    local c2hand = comp2:getCardIds("h")
    FkTest.setNextReplies(comp2, { { "1" }, c2hand })
    room:useActiveSkill(me, j_zhenglue.name, {}, { comp2 })
    lu.assertEquals(me:getMark("@j_jiaochi_liang"), 0, "征掠：应弃2枚粮")
    lu.assertEquals(#comp2:getCardIds("hej"), 0, "征掠：目标应弃置两张牌")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 1, "征掠：应获得弃牌堆一张装备")
  end)
end)

return j_zhenglue