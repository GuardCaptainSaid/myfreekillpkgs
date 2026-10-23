-- 计桓范·矫出（限定技）
-- 当你获得谋策牌时，你可以弃置任意张花色互不相同的手牌，视为使用等量的【杀】。
local j_jiaochu = fk.CreateSkill {
  name = "j_jiaochu",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["j_jiaochu"] = "矫出",
  [":j_jiaochu"] = "限定技，当你获得“谋策”牌时（献策结算完成后），你可以弃置任意张花色互不相同的手牌，视为使用等量的【杀】。",

  ["#j_jiaochu-invoke"] = "矫出：是否发动（弃置花色互不相同的手牌，视为使用等量【杀】）？",
  ["#j_jiaochu-discard"] = "矫出：请弃置一张与已选花色不同的手牌（点取消结束）",
  ["j_xiance_cand"] = "手牌",
}

-- 时机：献策（或收回谋策）结算完成后，若此时手中已获得谋策牌
j_jiaochu:addEffect(fk.AfterSkillEffect, {
  global = true,
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jiaochu.name) or player.dead then return false end
    -- 限定技：整局游戏限一次
    if player:getMark("j_jiaochu_used") > 0 then return false end
    local sk = data and data.skill
    if not sk then return false end
    local skel = sk.getSkeleton and sk:getSkeleton() or sk
    if not skel or skel.name ~= "j_xiance" then return false end
    -- 结算完成后手中确有“谋策”牌
    for _, cid in ipairs(player:getCardIds("h")) do
      local card = Fk:getCardById(cid)
      if card and card:getMark("@@j_xiance_mouli") > 0 then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_jiaochu.name,
      prompt = "#j_jiaochu-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_jiaochu_used", 1)
    -- 弃置任意张花色互不相同的手牌（逐张选择，已选花色排除，可取消结束）
    local chosen = {}
    while true do
      local usedSuits = {}
      for _, cid in ipairs(chosen) do
        table.insert(usedSuits, Fk:getCardById(cid):getSuitString())
      end
      local candidates = table.filter(player:getCardIds("h"), function(cid)
        return not table.contains(chosen, cid)
          and not table.contains(usedSuits, Fk:getCardById(cid):getSuitString())
      end)
      if #candidates == 0 then break end
      local pick = room:askToChooseCards(player, {
        target = player,
        flag = { card_data = { { "j_xiance_cand", candidates } } },
        min = 1,
        max = 1,
        cancelable = true,
        skill_name = j_jiaochu.name,
        prompt = "#j_jiaochu-discard",
      })
      if not pick or #pick == 0 then break end
      table.insert(chosen, pick[1])
    end
    if #chosen == 0 then return end
    room:throwCard(chosen, j_jiaochu.name, player, player)
    -- 视为使用等量的【杀】
    for _ = 1, #chosen do
      if player.dead then break end
      local use = room:askToUseVirtualCard(player, {
        name = "slash",
        skill_name = j_jiaochu.name,
        cancelable = true,
      })
      if not use then break end
    end
  end,
})

-- 测试：获得谋策牌 → 发动矫出，弃2张不同花色手牌 → 询问2次杀；限定技仅一次
j_jiaochu:addTest(function(room, me)
  local c1, c2, m1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiaochu.name)
    c1 = room:printCard("slash", Card.Spade, 7)
    c2 = room:printCard("jink", Card.Heart, 8)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    m1 = room:printCard("ex_nihilo", Card.Club, 9)
    room:setCardMark(Fk:getCardById(m1.id), "@@j_xiance_mouli", 1)
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChooseCards = room.askToChooseCards
    local origUseVirtual = room.askToUseVirtualCard
    local slashAsks = 0
    room.askToSkillInvoke = function(self, who, params)
      if who == me then return true end
      return origInvoke(self, who, params)
    end
    -- 依次选两张（黑桃、红桃，花色互不相同），然后取消
    local picks = { c1.id, c2.id }
    room.askToChooseCards = function(self, who, params)
      if who == me then return { table.remove(picks, 1) or c1.id } end
      return origChooseCards(self, who, params)
    end
    room.askToUseVirtualCard = function(self, who, params)
      if who == me and params.name == "slash" then
        slashAsks = slashAsks + 1
        return true
      end
      return origUseVirtual(self, who, params)
    end

    -- 桓范获得谋策牌，随后献策结算完成
    room:moveCardTo(m1.id, Card.PlayerHand, me, fk.ReasonGive, "test", nil, true, room.players[3])
    room.logic:trigger(fk.AfterSkillEffect, me, { skill = { name = "j_xiance" }, who = me })

    room.askToSkillInvoke = origInvoke
    room.askToChooseCards = origChooseCards
    room.askToUseVirtualCard = origUseVirtual

    lu.assertEquals(slashAsks, 2, "弃2张应视为使用2张杀")
    lu.assertTrue(me:getMark("j_jiaochu_used") > 0, "限定技应记录已使用")
    lu.assertFalse(table.contains(me:getCardIds("h"), c1.id), "所选手牌应被弃置")

    -- 再次获得谋策牌：限定技不再发动
    local m2 = room:printCard("snatch", Card.Diamond, 6)
    room:setCardMark(Fk:getCardById(m2.id), "@@j_xiance_mouli", 1)
    room:moveCardTo(m2.id, Card.PlayerHand, me, fk.ReasonGive, "test", nil, true, room.players[3])
    room.logic:trigger(fk.AfterSkillEffect, me, { skill = { name = "j_xiance" }, who = me })
    lu.assertEquals(slashAsks, 2, "限定技整局限一次，不应再次发动")
  end)
end)

-- 测试：手中没有谋策牌 → 献策结算后不触发
j_jiaochu:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiaochu.name)
    c1 = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local invoked = false
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params)
      if who == me then invoked = true end
      return origInvoke(self, who, params)
    end
    room.logic:trigger(fk.AfterSkillEffect, me, { skill = { name = "j_xiance" }, who = me })
    room.askToSkillInvoke = origInvoke
    lu.assertFalse(invoked, "手中无谋策牌时不应触发矫出")
    lu.assertEquals(me:getMark("j_jiaochu_used"), 0, "限定技未消耗")
  end)
end)

return j_jiaochu
