-- 计毛玠·正色
-- 锁定技，你使用一张牌后，若你的手牌中：
--   红桃牌最多，你摸两张牌；
--   方块牌最多，你使用下一张牌无距离次数限制；
--   黑桃牌最多，你弃置两张牌；
--   梅花牌最多，你重铸两张牌；
--   无手牌，你摸一张牌。
local j_maojie_zhengse = fk.CreateSkill {
  name = "j_maojie_zhengse",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_maojie_zhengse"] = "正色",
  [":j_maojie_zhengse"] = "锁定技，你使用一张牌后，若你的手牌中：红桃牌最多，你摸两张牌；" ..
    "方块牌最多，你使用下一张牌无距离次数限制；黑桃牌最多，你弃置两张牌；" ..
    "梅花牌最多，你重铸两张牌；无手牌，你摸一张牌。",

  ["#j_maojie_zhengse-discard"] = "正色：请弃置两张牌",
  ["#j_maojie_zhengse-recast"] = "正色：请重铸两张牌",
  ["@@j_maojie_zhengse-free-turn"] = "正色",
}

-- 「下一张牌无距离次数限制」：用引擎内置标记，并在下一次使用牌时清除
local FREE_DIST = MarkEnum.BypassDistancesLimit .. "-turn"
local FREE_TIMES = MarkEnum.BypassTimesLimit .. "-turn"

j_maojie_zhengse:addEffect(fk.CardUseFinished, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player
      and player:hasSkill(j_maojie_zhengse.name)
      and not player.dead
      and data.card ~= nil
  end,
  -- 锁定技：无条件发动
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local skillName = j_maojie_zhengse.name
    local hand = player:getCardIds("h")

    -- 无手牌：摸一张牌
    if #hand == 0 then
      room:drawCards(player, 1, skillName)
      return
    end

    -- 统计手牌花色
    local counts = {
      [Card.Heart] = 0,
      [Card.Diamond] = 0,
      [Card.Spade] = 0,
      [Card.Club] = 0,
    }
    for _, id in ipairs(hand) do
      local c = Fk:getCardById(id)
      if c and counts[c.suit] ~= nil then
        counts[c.suit] = counts[c.suit] + 1
      end
    end
    local maxNum = 0
    for _, n in pairs(counts) do
      if n > maxNum then maxNum = n end
    end
    if maxNum == 0 then return end

    local order = { Card.Heart, Card.Diamond, Card.Spade, Card.Club }
    for _, suit in ipairs(order) do
      if player.dead then break end
      if counts[suit] == maxNum then
        if suit == Card.Heart then
          -- 红桃最多：摸两张牌
          room:drawCards(player, 2, skillName)

        elseif suit == Card.Diamond then
          -- 方块最多：下一张牌无距离次数限制
          room:setPlayerMark(player, FREE_DIST, 1)
          room:setPlayerMark(player, FREE_TIMES, 1)

        elseif suit == Card.Spade then
          -- 黑桃最多：弃置两张牌
          local able = #player:getCardIds("he")
          if able > 0 then
            local n = math.min(2, able)
            room:askToDiscard(player, {
              min_num = n,
              max_num = n,
              include_equip = true,
              skill_name = skillName,
              prompt = "#j_maojie_zhengse-discard",
              cancelable = false,
            })
          end

        elseif suit == Card.Club then
          -- 梅花最多：重铸两张牌
          local able = #player:getCardIds("h")
          if able > 0 then
            local n = math.min(2, able)
            local cards = room:askToCards(player, {
              min_num = n,
              max_num = n,
              include_equip = false,
              skill_name = skillName,
              prompt = "#j_maojie_zhengse-recast",
              cancelable = false,
            })
            if cards and #cards > 0 then
              room:recastCard(cards, player, skillName)
            end
          end
        end
      end
    end
  end,
})

-- 使用下一张牌时清除「无距离次数限制」，保证只对下一张牌生效
j_maojie_zhengse:addEffect(fk.CardUsing, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player
      and player:hasSkill(j_maojie_zhengse.name)
      and (player:getMark(FREE_DIST) > 0 or player:getMark(FREE_TIMES) > 0)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, FREE_DIST, 0)
    room:setPlayerMark(player, FREE_TIMES, 0)
  end,
})

-- 测试1：红桃最多 → 摸两张牌
j_maojie_zhengse:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_maojie_zhengse.name)
    room.current = me
    -- 清空手牌，构造 3 红桃 + 1 黑桃
    for _, id in ipairs(me:getCardIds("he")) do
      room:throwCard({ id }, "test", me, me)
    end
    local c1 = room:printCard("slash", Card.Heart, 1)
    local c2 = room:printCard("jink", Card.Heart, 2)
    local c3 = room:printCard("peach", Card.Heart, 3)
    local c4 = room:printCard("dismantlement", Card.Spade, 4)
    room:obtainCard(me, { c1.id, c2.id, c3.id, c4.id }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local before = #me:getCardIds("h")
    local use = { from = me, tos = {}, card = room:printCard("ex_nihilo", Card.Club, 5) }
    room.logic:trigger(fk.CardUseFinished, me, use)
    lu.assertEquals(#me:getCardIds("h"), before + 2, "红桃最多应摸两张牌")
  end)
end)

-- 测试2：方块最多 → 获得无距离次数限制，且使用下一张牌后清除
j_maojie_zhengse:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_maojie_zhengse.name)
    room.current = me
    for _, id in ipairs(me:getCardIds("he")) do
      room:throwCard({ id }, "test", me, me)
    end
    local c1 = room:printCard("slash", Card.Diamond, 1)
    local c2 = room:printCard("jink", Card.Diamond, 2)
    local c3 = room:printCard("dismantlement", Card.Spade, 4)
    room:obtainCard(me, { c1.id, c2.id, c3.id }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local freeDist = MarkEnum.BypassDistancesLimit .. "-turn"
    local freeTimes = MarkEnum.BypassTimesLimit .. "-turn"
    local use = { from = me, tos = {}, card = room:printCard("ex_nihilo", Card.Club, 5) }
    room.logic:trigger(fk.CardUseFinished, me, use)
    lu.assertTrue(me:getMark(freeDist) > 0, "方块最多应获得无距离限制")
    lu.assertTrue(me:getMark(freeTimes) > 0, "方块最多应获得无次数限制")

    local use2 = { from = me, tos = {}, card = room:printCard("peach", Card.Heart, 6) }
    room.logic:trigger(fk.CardUsing, me, use2)
    lu.assertEquals(me:getMark(freeDist), 0, "使用下一张牌后应清除无距离限制")
    lu.assertEquals(me:getMark(freeTimes), 0, "使用下一张牌后应清除无次数限制")
  end)
end)

-- 测试3：无手牌 → 摸一张牌
j_maojie_zhengse:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_maojie_zhengse.name)
    room.current = me
    for _, id in ipairs(me:getCardIds("he")) do
      room:throwCard({ id }, "test", me, me)
    end
  end)
  FkTest.runInRoom(function()
    lu.assertEquals(#me:getCardIds("h"), 0, "前置：手牌应为空")
    local use = { from = me, tos = {}, card = room:printCard("ex_nihilo", Card.Club, 5) }
    room.logic:trigger(fk.CardUseFinished, me, use)
    lu.assertEquals(#me:getCardIds("h"), 1, "无手牌应摸一张牌")
  end)
end)

return j_maojie_zhengse
