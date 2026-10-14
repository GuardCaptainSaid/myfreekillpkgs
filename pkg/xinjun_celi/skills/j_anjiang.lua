-- 君刘备·安疆
-- 当其他角色对你使用牌时，你可令其选择：1.此牌结算后，你摸一张牌并与其各弃一张牌；2.此牌对你无效，你交给其一张非基本牌然后本轮移除此项。若同一阶段内有两项被选择，你回复1点体力。
local j_anjiang = fk.CreateSkill {
  name = "j_anjiang",
}

Fk:loadTranslationTable{
  ["j_anjiang"] = "安疆",
  [":j_anjiang"] = "当其他角色对你使用牌时，你可令其选择：1.此牌结算后，你摸一张牌并与其各弃一张牌；2.此牌对你无效，你交给其一张非基本牌然后本轮移除此项。若同一阶段内有两项被选择，你回复1点体力。",

  ["#j_anjiang-invoke"] = "安疆：是否令其选择一项？",
  ["#j_anjiang-choice"] = "安疆：请选择一项（1.结算后你摸一张牌并各弃一张牌 2.此牌对你无效，其交给你一张非基本牌）",
  ["#j_anjiang-give"] = "安疆：交给其一张非基本牌",
  ["#j_anjiang-discard"] = "安疆：弃置一张牌",
  ["@j_anjiang_p1"] = "安疆",

  ["$j_anjiang1"] = "安民恤众，疆土永固！",
  ["$j_anjiang2"] = "以德安邦，以仁定疆！",
}

-- 其他角色对你使用牌时
j_anjiang:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_anjiang.name, true) or player.dead then return false end
    if not data.card or not data.from or data.from == player then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_anjiang.name, prompt = "#j_anjiang-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    -- 选项2本轮已移除则只能选1
    local choice = "1"
    if player:getMark("@j_anjiang_p2-round") == 0 then
      choice = room:askForChoice(from, { "1", "2" }, j_anjiang.name, "#j_anjiang-choice")
    end
    if choice == "1" then
      -- 此牌结算后：你摸一张牌并与其各弃一张牌
      room:setPlayerMark(player, "@j_anjiang_pending_id", data.card.id)
      room:setPlayerMark(player, "@j_anjiang_pending_from", from.id)
      room:setPlayerMark(player, "@j_anjiang_p1-phase", 1)
    else
      -- 此牌对你无效，你交给其一张非基本牌，本轮移除此项
      data:cancelCurrentTarget()
      if not player:isAllNude() then
        local c = room:askToChooseCards(player, {
          target = player,
          flag = "hej",
          min = 0,
          max = 1,
          cancelable = true,
          pattern = "trick,equip",
          skill_name = j_anjiang.name,
          prompt = "#j_anjiang-give",
        })
        if c and #c > 0 then
          room:obtainCard(from, c, true, fk.ReasonGive, player, j_anjiang.name)
        end
      end
      room:setPlayerMark(player, "@j_anjiang_p2-round", 1)
      room:setPlayerMark(player, "@j_anjiang_p2-phase", 1)
    end
    -- 同一阶段内两项都被选择：回复1点体力
    if player:getMark("@j_anjiang_p1-phase") > 0 and player:getMark("@j_anjiang_p2-phase") > 0 then
      if not player.dead and player:isWounded() then
        room:recover{ who = player, num = 1, recoverBy = player, skillName = j_anjiang.name }
      end
      room:setPlayerMark(player, "@j_anjiang_p1-phase", 0)
      room:setPlayerMark(player, "@j_anjiang_p2-phase", 0)
    end
  end,
})

-- 选项1：此牌结算后摸一张牌并与其各弃一张牌
j_anjiang:addEffect(fk.CardUseFinished, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player:getMark("@j_anjiang_pending_id") == 0 then return false end
    return data.card and data.card.id == player:getMark("@j_anjiang_pending_id")
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = room:getPlayerById(player:getMark("@j_anjiang_pending_from"))
    room:setPlayerMark(player, "@j_anjiang_pending_id", 0)
    room:setPlayerMark(player, "@j_anjiang_pending_from", 0)
    if player.dead then return end
    player:drawCards(1, j_anjiang.name)
    if not from or from.dead then return end
    if not player:isAllNude() then
      local c1 = room:askToChooseCards(player, {
        target = player,
        flag = "hej",
        min = 0,
        max = 1,
        cancelable = true,
        pattern = ".",
        skill_name = j_anjiang.name,
        prompt = "#j_anjiang-discard",
      })
      if c1 and #c1 > 0 then room:throwCard(c1, j_anjiang.name, player, player) end
    end
    if not from:isAllNude() then
      local c2 = room:askToChooseCards(from, {
        target = from,
        flag = "hej",
        min = 0,
        max = 1,
        cancelable = true,
        pattern = ".",
        skill_name = j_anjiang.name,
        prompt = "#j_anjiang-discard",
      })
      if c2 and #c2 > 0 then room:throwCard(c2, j_anjiang.name, from, from) end
    end
  end,
})

-- 测试：其他角色用牌时选项1与选项2、阶段内两选回血
j_anjiang:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_anjiang.name)
    me.maxHp = 4
    me.hp = 3
    room.current = comp2
    comp2.phase = Player.Play
    local jn = room:printCard("dismantlement", Card.Spade, 2)
    room:obtainCard(comp2, { jn }, true, fk.ReasonDraw, comp2, "test")
    local h = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(me, { h }, true, fk.ReasonDraw, me, "test")
    local h2 = room:printCard("peach", Card.Heart, 4)
    room:obtainCard(me, { h2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = comp2
    comp2.phase = Player.Play
    local useData = { card = comp2:getCardIds("h")[1], from = comp2, tos = { me }, extra_data = {} }
    local cardId = useData.card
    -- 选项1：结算后摸一张并各弃一张
    FkTest.setNextReplies(me, { "1", "1" }) -- 安疆询问 yes；comp2 选 1
    room.logic:trigger(fk.TargetConfirming, comp2, useData)
    lu.assertEquals(me:getMark("@j_anjiang_pending_id"), cardId, "安疆：应记录待结算的牌")
    -- 触发结算完成
    FkTest.setNextReplies(me, { {}, {} }) -- 双方都不弃牌
    room.logic:trigger(fk.CardUseFinished, me, { card = Fk:getCardById(cardId) })
    lu.assertEquals(me:getMark("@j_anjiang_pending_id"), 0, "安疆：结算后应清除记录")

    -- 选项2：此牌对你无效 + 交给其一张非基本牌 + 本轮移除选项2
    -- me 只有基本牌（jink/peach）→ 无可交非基本牌（取消），但仍取消目标
    local useData2 = { card = comp2:getCardIds("h")[1], from = comp2, tos = { me }, extra_data = {} }
    FkTest.setNextReplies(me, { "1", "2", {} }) -- 安疆 yes；comp2 选 2；me 无可交取消
    room.logic:trigger(fk.TargetConfirming, comp2, useData2)
    lu.assertEquals(me:getMark("@j_anjiang_p2-round"), 1, "安疆：本轮应移除选项2")
  end)
end)

-- 测试：同一阶段两项都被选 → 回1血
j_anjiang:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_anjiang.name)
    me.maxHp = 4
    me.hp = 3
    room.current = comp2
    comp2.phase = Player.Play
    room:setPlayerMark(me, "@j_anjiang_p1-phase", 1)
    room:setPlayerMark(me, "@j_anjiang_p2-phase", 1)
  end)

  FkTest.runInRoom(function()
    local hpBefore = me.hp
    -- 直接触发一次安疆（任意用牌），进入 on_use 后检测两项已选 → 回血
    local jn = room:printCard("snatch", Card.Club, 5)
    room:obtainCard(comp2, { jn }, true, fk.ReasonDraw, comp2, "test")
    local useData = { card = jn, from = comp2, tos = { me }, extra_data = {} }
    -- me 有非基本牌可交：一张闪不行，给 me 一张装备/锦囊
    local eq = room:printCard("crossbow", Card.Diamond, 1)
    room:obtainCard(me, { eq }, true, fk.ReasonDraw, me, "test")
    -- 安疆 yes；comp2 选 2（me 已无手牌？有 eq）；me 交 eq
    FkTest.setNextReplies(me, { "1", "2", { eq } })
    room.logic:trigger(fk.TargetConfirming, comp2, useData)
    lu.assertEquals(me.hp, hpBefore + 1, "安疆：同一阶段两项被选应回复1点体力")
    lu.assertEquals(me:getMark("@j_anjiang_p1-phase"), 0, "安疆：回血后应清除阶段标记")
  end)
end)

return j_anjiang