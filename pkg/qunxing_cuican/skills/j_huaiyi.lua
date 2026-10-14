local j_huaiyi = fk.CreateSkill {
  name = "j_huaiyi",
}

Fk:loadTranslationTable{
  ["j_huaiyi"] = "怀异",
  [":j_huaiyi"] = "出牌阶段限一次，你可以展示所有手牌。若只有一种颜色，你摸一张牌；若有两种颜色，你弃置其中一种颜色的牌，然后获得一名角色的至多X张牌（X为你弃置的手牌数）。若你获得的牌大于一张，则你失去1点体力。",

  ["#j_huaiyi-color"] = "怀异：弃置一种颜色的全部手牌",
  ["#j_huaiyi-target"] = "怀异：选择一名角色获得其牌",
  ["#j_huaiyi-get"] = "怀异：获得该角色至多 %arg 张牌",
  ["j_huaiyi:red"] = "红色牌",
  ["j_huaiyi:black"] = "黑色牌",

  ["$j_huaiyi1"] = "心怀异志，岂甘人下。",
  ["$j_huaiyi2"] = "此计若成，大事可期。",
}

-- 主动技：出牌阶段限一次（点击技能直接释放，无需额外询问）
j_huaiyi:addEffect("active", {
  anim_type = "drawcard",
  card_num = 0,
  can_use = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local hand = player:getCardIds("h")
    room:showCards(hand, player)

    -- 统计手牌颜色种类
    local colors = {}
    for _, id in ipairs(hand) do
      local color = Fk:getCardById(id).color
      if color ~= Card.NoColor and not table.contains(colors, color) then
        table.insert(colors, color)
      end
    end

    if #colors <= 1 then
      -- 只有一种颜色 → 摸一张牌
      player:drawCards(1, j_huaiyi.name)
      return
    end

    -- 两种颜色 → 选择弃置其中一种颜色的全部手牌
    local choice = room:askToChoice(player, {
      choices = { "j_huaiyi:red", "j_huaiyi:black" },
      skill_name = j_huaiyi.name,
      prompt = "#j_huaiyi-color",
    })
    local wantColor = (choice == "j_huaiyi:red") and Card.Red or Card.Black
    local toDiscard = {}
    for _, id in ipairs(hand) do
      if Fk:getCardById(id).color == wantColor then
        table.insert(toDiscard, id)
      end
    end
    room:throwCard(toDiscard, j_huaiyi.name, player, player)
    local x = #toDiscard
    if x == 0 then return end

    -- 获得一名角色的至多X张牌（该角色须有牌）
    local candidates = {}
    for _, p in ipairs(room.alive_players) do
      if not p:isAllNude() then table.insert(candidates, p) end
    end
    if #candidates == 0 then return end

    local target = room:askToChoosePlayers(player, {
      targets = candidates,
      min_num = 1,
      max_num = 1,
      cancelable = false,
      skill_name = j_huaiyi.name,
      prompt = "#j_huaiyi-target",
    })[1]
    if not target then return end

    local ids = room:askToChooseCards(player, {
      target = target,
      flag = "hej",
      min = 0,
      max = x,
      cancelable = true,
      skill_name = j_huaiyi.name,
      prompt = "#j_huaiyi-get::" .. x,
    })
    if ids and #ids > 0 then
      room:obtainCard(player, ids, true, fk.ReasonGot, target, j_huaiyi.name)
      if #ids > 1 then
        -- 获得牌大于一张 → 失去1点体力
        room:loseHp(player, 1, j_huaiyi.name, player)
      end
    end
  end,
})

j_huaiyi:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_huaiyi.name,
  think = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0
  end,
})

-- 测试：单色手牌 → 摸1张
j_huaiyi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_huaiyi.name)
    local c1 = room:printCard("slash", Card.Club, 2)  -- 黑
    local c2 = room:printCard("jink", Card.Spade, 3)  -- 黑
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    local before = #me:getCardIds("h")
    local sk = Fk.skills[j_huaiyi.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(#me:getCardIds("h"), before + 1, "单色手牌应摸1张")
  end)
end)

-- 测试：双色手牌 → 弃一种颜色全部 + 获得他人至多X张 + 获得>1张失去1体力
j_huaiyi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_huaiyi.name)
    local c1 = room:printCard("slash", Card.Club, 2)    -- 黑
    local c2 = room:printCard("jink", Card.Spade, 3)    -- 黑
    local c3 = room:printCard("peach", Card.Heart, 4)   -- 红
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
    -- comp2 给3张牌供获得
    local t1 = room:printCard("slash", Card.Diamond, 5)
    local t2 = room:printCard("jink", Card.Club, 6)
    local t3 = room:printCard("peach", Card.Spade, 7)
    room:obtainCard(comp2, { t1, t2, t3 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    local hpBefore = me.hp
    local compHand = comp2:getCardIds("h")
    -- 选红色弃置（红色只有1张）→ 弃1张 → X=1 → 获得至多1张 → 获得1张不失去体力
    FkTest.setNextReplies(me, { { "j_huaiyi:red" }, FkTest.ReplyChoosePlayer({ comp2 }), { compHand[1] } })
    local sk = Fk.skills[j_huaiyi.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(me.hp, hpBefore, "获得1张不应失去体力")
    lu.assertEquals(#comp2:getCardIds("h"), 2, "应获得comp2一张牌")
  end)
end)

-- 测试：双色手牌弃2张、获得3张（>1）→ 失去1体力
j_huaiyi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_huaiyi.name)
    local c1 = room:printCard("slash", Card.Club, 2)    -- 黑
    local c2 = room:printCard("jink", Card.Spade, 3)    -- 黑
    local c3 = room:printCard("peach", Card.Heart, 4)   -- 红
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
    local t1 = room:printCard("slash", Card.Diamond, 5)
    local t2 = room:printCard("jink", Card.Club, 6)
    local t3 = room:printCard("peach", Card.Spade, 7)
    room:obtainCard(comp2, { t1, t2, t3 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    local hpBefore = me.hp
    local compHand = comp2:getCardIds("h")
    -- 选黑色弃置（黑2张）→ 弃2张 → X=2 → 获得至多2张
    FkTest.setNextReplies(me, { { "j_huaiyi:black" }, FkTest.ReplyChoosePlayer({ comp2 }), { compHand[1], compHand[2] } })
    local sk = Fk.skills[j_huaiyi.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(me.hp, hpBefore - 1, "获得2张应失去1点体力")
  end)
end)

return j_huaiyi