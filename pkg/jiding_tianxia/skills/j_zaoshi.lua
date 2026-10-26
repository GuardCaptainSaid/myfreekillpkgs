local j_zaoshi = fk.CreateSkill {
  name = "j_zaoshi",
}

Fk:loadTranslationTable{
  ["j_zaoshi"] = "造势",
  [":j_zaoshi"] = "当你成为一张牌的目标时，你可以将一张手牌置于牌堆顶或牌堆底，然后从牌堆顶或牌堆底摸一张牌。",

  ["#j_zaoshi-invoke"] = "造势：你可以将一张手牌置入牌堆并摸一张牌",
  ["#j_zaoshi-choose"] = "造势：选择一张手牌置于牌堆",
  ["#j_zaoshi-place"] = "造势：置于牌堆顶或牌堆底",
  ["#j_zaoshi-draw"] = "造势：从牌堆顶或牌堆底摸一张牌",
  ["j_zaoshi__top"] = "牌堆顶",
  ["j_zaoshi__bottom"] = "牌堆底",

  ["$j_zaoshi1"] = "虚实相生，攻守易势。",
  ["$j_zaoshi2"] = "造势而动，以静制动！",
}

-- "当你成为一张牌的目标时" 标准写法（同标准包流离 liuli.lua）：
-- 挂在 fk.TargetConfirming（成为目标时），该时机 trigger 的 target 参数就是目标角色，
-- 直接用 target == player 判定，不会误触发，也不会因遍历顺序/数据结构问题漏触发。
j_zaoshi:addEffect(fk.TargetConfirming, {
  global = true,
  anim_type = "defense",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zaoshi.name) then return false end
    if player.dead then return false end
    return #player:getCardIds("h") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, { skill_name = j_zaoshi.name, prompt = "#j_zaoshi-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = room:askToChooseCards(player, {
      target = player, flag = "h", min = 1, max = 1,
      cancelable = false, skill_name = j_zaoshi.name, prompt = "#j_zaoshi-choose",
    })
    if not cards or #cards ~= 1 then
      return end

    local where = room:askToChoice(player, {
      choices = { "牌堆顶", "牌堆底" },
      skill_name = j_zaoshi.name,
      prompt = "#j_zaoshi-place",
    })
    local ok
    if where == "牌堆底" then
      ok = room:moveCards { ids = cards, from = player, toArea = Card.DrawPile, moveReason = fk.ReasonPut, skillName = j_zaoshi.name, proposer = player, drawPilePosition = -1 }
    else
      ok = room:moveCards { ids = cards, from = player, toArea = Card.DrawPile, moveReason = fk.ReasonPut, skillName = j_zaoshi.name, proposer = player, drawPilePosition = 1 }
    end
    if not ok then return end

    local where2 = room:askToChoice(player, {
      choices = { "牌堆顶", "牌堆底" },
      skill_name = j_zaoshi.name,
      prompt = "#j_zaoshi-draw",
    })
    player:drawCards(1, j_zaoshi.name, where2 == "牌堆底" and "bottom" or "top")
  end,
})

-- AI 控制时也保持可发动：造势是"置1摸1"的换牌，只要手牌>0 就值得发动
j_zaoshi:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_zaoshi.name,
  think = function(self, player)
    return #player:getCardIds("h") > 0
  end,
})

-- 测试：真实对局完整流程——comp2 用【乐不思蜀】指定 me，造势应完整发动换牌（置入1摸1，手牌净不变）
j_zaoshi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zaoshi.name)
    -- me 至少两张手牌，保证 askToChooseCards 可选
    local c1 = room:printCard("slash", Card.Spade, 5)
    local c2 = room:printCard("jink", Card.Heart, 1)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    local trick = room:printCard("indulgence", Card.Heart, 3)
    room:obtainCard(comp2, { trick }, true, fk.ReasonDraw, comp2, "test")
    local choose = me:getCardIds("h")[1]
    FkTest.setNextReplies(me, { "1", choose, { "j_zaoshi__top" }, { "j_zaoshi__bottom" } })
    local pileBefore = #room.draw_pile
    local handBefore = #me:getCardIds("h")
    room:useCard{ from = comp2, card = trick, tos = { me } }
    -- 造势完整发动：置入1张（-1）又摸1张（+1）→ 净手牌不变；牌堆数也不变
    lu.assertEquals(#me:getCardIds("h"), handBefore, "造势发动后手牌数应不变")
    lu.assertEquals(#room.draw_pile, pileBefore, "置入一张又摸一张，牌堆数应不变")
  end)
end)

-- 测试：成为目标时可换牌（手牌减少1并摸回1，净持牌数不变）
j_zaoshi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zaoshi.name)
    local c1 = room:printCard("slash", Card.Spade, 5)
    local c2 = room:printCard("jink", Card.Heart, 1)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local hand = me:getCardIds("h")
    local choose = hand[1]
    local before = #me:getCardIds("h")
    local pileBefore = #room.draw_pile
    -- 回复格式：invoke="1"（裸串）、AskForCardChosen=裸id、两次AskForChoices=["j_zaoshi__top"/"j_zaoshi__bottom"]
    FkTest.setNextReplies(me, { "1", choose, { "j_zaoshi__top" }, { "j_zaoshi__bottom" } })
    local slash = Fk:cloneCard("slash")
    -- 构造真实 AimData（aimStruct）结构：tos 是 AimGroup
    local use = UseCardData:new{ from = comp2, card = slash, tos = { me } }
    local aimGroup = AimData:initAimGroup({ me })
    local aimStruct = AimData:new{ from = comp2, card = slash, to = me, use = use, tos = aimGroup, firstTarget = true }
    -- 真实对局中 TargetConfirming 的 target 参数是目标角色（me），data 是 AimData
    room.logic:trigger(fk.TargetConfirming, me, aimStruct)
    local after = #me:getCardIds("h")
    lu.assertEquals(after, before, "换牌后手牌数应不变")
    lu.assertEquals(#room.draw_pile, pileBefore, "牌堆数量应不变（置入一张又摸一张）")
  end)
end)

-- 测试：别人用牌指定别人时，自己不发动造势
j_zaoshi:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zaoshi.name)
    local c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local before = #me:getCardIds("h")
    local pileBefore = #room.draw_pile
    local slash = Fk:cloneCard("slash")
    -- 构造真实 AimData：目标是 comp3（不是 me）
    local use = UseCardData:new{ from = comp2, card = slash, tos = { comp3 } }
    local aimGroup = AimData:initAimGroup({ comp3 })
    local aimStruct = AimData:new{ from = comp2, card = slash, to = comp3, use = use, tos = aimGroup, firstTarget = true }
    -- TargetConfirming 的 target 是目标角色 comp3，不是 me → 不应触发
    room.logic:trigger(fk.TargetConfirming, comp3, aimStruct)
    lu.assertEquals(#me:getCardIds("h"), before, "自己不是目标时不应发动造势")
    lu.assertEquals(#room.draw_pile, pileBefore, "自己不是目标时牌堆不应变化")
  end)
end)

return j_zaoshi
