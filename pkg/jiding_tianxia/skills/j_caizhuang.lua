-- 计陈群·采状
-- 每轮限一次，其他角色回合结束时，你可以令其选择交给你至多3张牌：
-- 0张，其减少1点体力上限；1张，其本轮不能打出闪；2张，其摸1张牌；3张，其回复一点体力并令你摸一张牌。
local j_caizhuang = fk.CreateSkill {
  name = "j_caizhuang",
}

Fk:loadTranslationTable{
  ["j_caizhuang"] = "采状",
  [":j_caizhuang"] = "每轮限一次，其他角色回合结束时，你可以令其选择交给你至多3张牌：0张，其减少1点体力上限；1张，其本轮不能打出【闪】；2张，其摸1张牌；3张，其回复1点体力并令你摸一张牌。",

  ["#j_caizhuang-invoke"] = "采状：是否发动（令其交给你至多3张牌）？",
  ["#j_caizhuang-give"] = "采状：交给其至多3张手牌（0张：减体力上限；1张：本轮不能打出闪；2张：摸1张牌；3张：回复1点体力且其摸1张牌）",
}

-- 每轮限一次，其他角色回合结束时
j_caizhuang:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_caizhuang.name) or player.dead then return false end
    if not target or target == player or target.dead then return false end
    -- 每轮限一次
    return player:getMark("j_caizhuang_used-round") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_caizhuang.name,
      prompt = "#j_caizhuang-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_caizhuang_used-round", 1)
    if target.dead then return end
    -- 令其选择交给你至多3张牌
    local ids = {}
    if #target:getCardIds("h") > 0 then
      ids = room:askToChooseCards(target, {
        target = target,
        flag = "h",
        min = 0,
        max = 3,
        cancelable = false,
        pattern = ".",
        skill_name = j_caizhuang.name,
        prompt = "#j_caizhuang-give",
      }) or {}
    end
    local n = #ids
    if n > 0 then
      room:moveCardTo(ids, Card.PlayerHand, player, fk.ReasonGive, j_caizhuang.name, nil, true, target)
    end
    if target.dead then return end
    if n == 0 then
      -- 减少1点体力上限
      room:changeMaxHp(target, -1)
    elseif n == 1 then
      -- 本轮不能打出闪
      room:setPlayerMark(target, "j_caizhuang_nojink-round", 1)
    elseif n == 2 then
      -- 摸1张牌
      room:drawCards(target, 1, j_caizhuang.name)
    else
      -- 回复1点体力并令你摸一张牌
      if target.hp < target.maxHp then
        room:recover{ who = target, num = 1, recoverBy = player, skillName = j_caizhuang.name }
      end
      room:drawCards(player, 1, j_caizhuang.name)
    end
  end,
})

-- 1张：本轮不能打出闪
j_caizhuang:addEffect("prohibit", {
  global = true,
  prohibit_response = function(self, player, card)
    if player:getMark("j_caizhuang_nojink-round") == 0 then return false end
    return card and card.trueName == "jink"
  end,
})

-- 测试：目标交1张牌 → 陈群获得该牌，目标本轮不能打出闪
j_caizhuang:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_caizhuang.name)
    c1 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChooseCards = room.askToChooseCards
    room.askToSkillInvoke = function(self, who, params)
      if who == me then return true end
      return origInvoke(self, who, params)
    end
    room.askToChooseCards = function(self, who, params)
      if who == comp2 then return { c1.id } end
      return origChooseCards(self, who, params)
    end

    room.logic:trigger(fk.TurnEnd, comp2, {})

    room.askToSkillInvoke = origInvoke
    room.askToChooseCards = origChooseCards

    lu.assertTrue(table.contains(me:getCardIds("h"), c1.id), "应获得目标交的牌")
    lu.assertEquals(comp2:getMark("j_caizhuang_nojink-round"), 1, "交1张应不能打出闪")
    lu.assertTrue(comp2:prohibitResponse(Fk:cloneCard("jink")), "应禁止目标打出闪")
    lu.assertFalse(comp2:prohibitResponse(Fk:cloneCard("slash")), "不应禁止打出其他牌")
    lu.assertEquals(me:getMark("j_caizhuang_used-round"), 1, "每轮限一次应记录")
  end)
end)

-- 测试：目标交0张牌 → 减少1点体力上限；交2张 → 摸1张牌；每轮仅限一次
j_caizhuang:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_caizhuang.name)
    c1 = room:printCard("slash", Card.Spade, 7)
    c2 = room:printCard("jink", Card.Club, 8)
    room:obtainCard(comp2, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChooseCards = room.askToChooseCards
    local giveQueue = { {}, { c1.id, c2.id } }
    room.askToSkillInvoke = function(self, who, params)
      if who == me then return true end
      return origInvoke(self, who, params)
    end
    room.askToChooseCards = function(self, who, params)
      if who == comp2 then return table.remove(giveQueue, 1) or {} end
      return origChooseCards(self, who, params)
    end

    -- 第一次：交0张 → 减少体力上限
    local maxBefore = comp2.maxHp
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(comp2.maxHp, maxBefore - 1, "交0张应减少1点体力上限")
    lu.assertEquals(me:getMark("j_caizhuang_used-round"), 1, "每轮限一次")

    -- 同轮再次结束回合：不再发动
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(comp2.maxHp, maxBefore - 1, "每轮限一次，不应再次发动")

    -- 新一轮：交2张 → 目标摸1张牌
    room:setPlayerMark(me, "j_caizhuang_used-round", 0)
    local handBefore = #comp2:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(#comp2:getCardIds("h"), handBefore - 2 + 1, "交2张：给2张后摸1张")
    lu.assertEquals(me:getMark("j_caizhuang_used-round"), 1, "新一轮应重新可用并记录")

    room.askToSkillInvoke = origInvoke
    room.askToChooseCards = origChooseCards
  end)
end)

-- 测试：目标交3张牌 → 回复体力且陈群摸一张牌
j_caizhuang:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2, c3
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_caizhuang.name)
    c1 = room:printCard("slash", Card.Spade, 7)
    c2 = room:printCard("jink", Card.Club, 8)
    c3 = room:printCard("peach", Card.Diamond, 9)
    room:obtainCard(comp2, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
    comp2.hp = comp2.hp - 1
    room:broadcastProperty(comp2, "hp")
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChooseCards = room.askToChooseCards
    room.askToSkillInvoke = function(self, who, params)
      if who == me then return true end
      return origInvoke(self, who, params)
    end
    room.askToChooseCards = function(self, who, params)
      if who == comp2 then return { c1.id, c2.id, c3.id } end
      return origChooseCards(self, who, params)
    end

    local myHand = #me:getCardIds("h")
    local hpBefore = comp2.hp
    room.logic:trigger(fk.TurnEnd, comp2, {})

    room.askToSkillInvoke = origInvoke
    room.askToChooseCards = origChooseCards

    lu.assertEquals(comp2.hp, hpBefore + 1, "交3张应回复1点体力")
    lu.assertEquals(#me:getCardIds("h"), myHand + 1, "交3张应令你摸一张牌")
  end)
end)

return j_caizhuang
