local j_jiance = fk.CreateSkill {
  name = "j_jiance",
}

Fk:loadTranslationTable{
  ["j_jiance"] = "谏策",
  [":j_jiance"] = "其他角色使用锦囊牌时，你可以弃置3-x张牌并令其选择一项：①令你摸y张牌；②令你视为对其使用y张【过河拆桥】。（x为本回合谏策发动过的次数，x>2时改为弃置0张，y为你拥有的冰数）",

  ["#j_jiance-invoke"] = "谏策：是否发动？",
  ["#j_jiance-discard"] = "谏策：弃置 %arg 张牌",
  ["#j_jiance-choice"] = "谏策：令其选择一项",
  ["j_jiance__draw"] = "令你摸 y 张牌",
  ["j_jiance__dismantle"] = "令你视为对其使用 y 张【过河拆桥】",
  ["#j_jiance-dismantle"] = "谏策：对 %arg 使用【过河拆桥】",

  ["$j_jiance1"] = "进言献策，愿君采纳。",
  ["$j_jiance2"] = "事有轻重，缓急有别。",
}

-- 其他角色使用锦囊牌时触发
j_jiance:addEffect(fk.CardUsing, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if target == player or player.dead then return false end
    if not player:hasSkill(j_jiance.name) then return false end
    if not data or not data.from or data.from ~= target then return false end
    if not data.card or data.card.type ~= Card.TypeTrick then return false end
    -- 需要有冰（y>=1）
    if #player:getPile("j_bing") == 0 then return false end
    -- 若需弃牌（x<=2），手牌至少1张
    local x = player:getMark("j_jiance_count")
    local base = player:getMark("j_zhongxiao_base")
    if base == 0 then base = 3 end
    local need = base - x
    if need > 0 and #player:getCardIds("h") == 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_jiance.name, prompt = "#j_jiance-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = player:getMark("j_jiance_count")
    local base = player:getMark("j_zhongxiao_base")
    if base == 0 then base = 3 end
    local need = base - x
    if need < 0 then need = 0 end

    -- 弃置 need 张手牌（不足则全弃）
    if need > 0 then
      local cards = room:askToChooseCards(player, {
        target = player, flag = "h", min = need, max = need,
        cancelable = false, skill_name = j_jiance.name, prompt = "#j_jiance-discard::" .. need,
      })
      if cards and #cards > 0 then
        room:throwCard(cards, j_jiance.name, player, target)
      end
    end

    -- 计数 +1
    room:setPlayerMark(player, "j_jiance_count", x + 1)
    local y = #player:getPile("j_bing")

    -- 令其选择一项
    local choice = room:askToChoice(target, {
      choices = { "j_jiance__draw", "j_jiance__dismantle" },
      skill_name = j_jiance.name,
      prompt = "#j_jiance-choice",
    })
    if choice == "j_jiance__draw" then
      -- 令你摸 y 张牌
      player:drawCards(y, j_jiance.name)
    else
      -- 令你视为对其使用 y 张【过河拆桥】
      for i = 1, y do
        room:useCard{ from = player, card = Fk:cloneCard("dismantlement"), tos = { target } }
      end
    end
  end,
})

-- 每回合开始重置谏策发动次数
j_jiance:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_jiance.name)
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_jiance_count", 0)
  end,
})

j_jiance:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_jiance.name,
  think = function(self, player)
    return #player:getPile("j_bing") > 0 and #player:getCardIds("h") >= 3
  end,
})

-- 测试：其他角色使用锦囊 → 弃牌并令其选择；x>2 时弃0张
j_jiance:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiance.name)
    local ice1 = room:printCard("slash", Card.Spade, 5)
    local ice2 = room:printCard("jink", Card.Heart, 1)
    me:addToPile("j_bing", { ice1.id, ice2.id }, true, j_jiance.name)
    local h1 = room:printCard("peach", Card.Club, 2)
    local h2 = room:printCard("slash", Card.Diamond, 3)
    local h3 = room:printCard("jink", Card.Club, 4)
    local h4 = room:printCard("peach", Card.Heart, 5)
    room:obtainCard(me, { h1, h2, h3, h4 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { room:printCard("jink", Card.Club, 6) }, true, fk.ReasonDraw, comp2, "test")
  end)

  -- 场景A：comp2 使用锦囊 → 弃3张、选①摸2张（y=2）→ 手牌 -3+2 = -1
  FkTest.runInRoom(function()
    local hand = me:getCardIds("h")
    local before = #hand
    local trick = Fk:cloneCard("dismantlement")
    local use = UseCardData:new{ from = comp2, card = trick, tos = { me } }
    FkTest.setNextReplies(me, { "1", { hand[1], hand[2], hand[3] }, { "j_jiance__draw" } })
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertEquals(#me:getCardIds("h"), before - 3 + 2, "弃3摸2后手牌应-1")
    lu.assertEquals(me:getMark("j_jiance_count"), 1, "谏策发动次数应记为1")
  end)

  -- 场景B：x=3 时弃0张（直接触发，摸2）
  FkTest.runInRoom(function()
    room:setPlayerMark(me, "j_jiance_count", 3)
    local before = #me:getCardIds("h")
    local trick = Fk:cloneCard("dismantlement")
    local use = UseCardData:new{ from = comp2, card = trick, tos = { me } }
    FkTest.setNextReplies(me, { "1", { "j_jiance__draw" } })
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertEquals(#me:getCardIds("h"), before + 2, "x>2时弃0张且摸2")
    room:setPlayerMark(me, "j_jiance_count", 0)
  end)
end)

-- 测试：选② → 对使用者使用 y 张【过河拆桥】
j_jiance:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiance.name)
    local ice1 = room:printCard("slash", Card.Spade, 5)
    local ice2 = room:printCard("jink", Card.Heart, 1)
    me:addToPile("j_bing", { ice1.id, ice2.id }, true, j_jiance.name)
    local h1 = room:printCard("peach", Card.Club, 2)
    local h2 = room:printCard("slash", Card.Diamond, 3)
    local h3 = room:printCard("jink", Card.Club, 4)
    room:obtainCard(me, { h1, h2, h3 }, true, fk.ReasonDraw, me, "test")
    local t1 = room:printCard("jink", Card.Club, 6)
    local t2 = room:printCard("slash", Card.Heart, 7)
    local t3 = room:printCard("peach", Card.Diamond, 8)
    room:obtainCard(comp2, { t1, t2, t3 }, true, fk.ReasonDraw, comp2, "test")
  end)

  -- comp2 使用锦囊 → 弃3张、选② → 对 comp2 依次使用 2 张过河拆桥（拆其2张牌）
  FkTest.runInRoom(function()
    local hand = me:getCardIds("h")
    local compHand = comp2:getCardIds("h")
    local trick = Fk:cloneCard("dismantlement")
    local use = UseCardData:new{ from = comp2, card = trick, tos = { me } }
    -- 弃牌与拆牌由使用者（me）选择；选项由目标（comp2）选择
    FkTest.setNextReplies(me, { "1", { hand[1], hand[2], hand[3] }, compHand[1], compHand[2] })
    FkTest.setNextReplies(comp2, { { "j_jiance__dismantle" } })
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertEquals(#comp2:getCardIds("h"), 1, "2张过河拆桥应拆掉使用者2张牌")
  end)
end)

return j_jiance
