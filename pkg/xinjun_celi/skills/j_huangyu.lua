-- 君刘备·皇誉
-- 游戏开始时，你获得3枚“汉祚”。出牌阶段每名角色限一次，你可弃1枚“汉祚”，令一名其他角色选择一项：1.展示所有手牌，你挑选一张加入手牌；2.令你此回合可多使用一张【杀】。当你于回合外失去牌时，可获得1枚“汉祚”（上限5）。
local j_huangyu = fk.CreateSkill {
  name = "j_huangyu",
}

Fk:loadTranslationTable{
  ["j_huangyu"] = "皇誉",
  [":j_huangyu"] = "游戏开始时，你获得3枚“汉祚”。出牌阶段每名角色限一次，你可弃1枚“汉祚”，令一名其他角色选择一项：1.展示所有手牌，你挑选一张加入手牌；2.令你此回合可多使用一张【杀】。当你于回合外失去牌时，可获得1枚“汉祚”（上限5）。",

  ["#j_huangyu-choice"] = "皇誉：请选择一项（1.展示所有手牌由刘备挑选 2.令刘备本回合可多使用一张杀）",
  ["#j_huangyu-get"] = "皇誉：选择获得其一张手牌",
  ["@j_huangyu_hanzuo"] = "汉祚",
  ["@j_huangyu_target"] = "皇誉",

  ["$j_huangyu1"] = "汉室宗亲，当续汉祚！",
  ["$j_huangyu2"] = "兴复汉室，还于旧都！",
}

-- 游戏开始时获得3枚汉祚
j_huangyu:addEffect(fk.GameStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_huangyu.name, true)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@j_huangyu_hanzuo", 3)
  end,
})

-- 出牌阶段主动技：弃1枚汉祚，令一名其他角色选择
j_huangyu:addEffect("active", {
  anim_type = "control",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:getMark("@j_huangyu_hanzuo") <= 0 then return false end
    local room = player.room
    for _, p in ipairs(room:getOtherPlayers(player)) do
      if not p.dead and p:getMark("@j_huangyu_target-turn") == 0 then return true end
    end
    return false
  end,
  target_filter = function(self, player, to_select, selected, selected_cards, card, extra_data)
    if to_select == player then return false end
    if to_select:getMark("@j_huangyu_target-turn") > 0 then return false end
    return #selected < 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local t = effect.tos[1]
    room:setPlayerMark(player, "@j_huangyu_hanzuo", -1)
    room:setPlayerMark(t, "@j_huangyu_target-turn", 1)
    local choice = room:askForChoice(t, { "1", "2" }, j_huangyu.name, "#j_huangyu-choice")
    if choice == "1" then
      -- 展示所有手牌，你挑选一张加入手牌
      local hand = t:getCardIds("h")
      room:showCards(hand, t)
      if #hand > 0 then
        local c = room:askToChooseCards(player, {
          target = t,
          flag = "h",
          min = 1,
          max = 1,
          cancelable = false,
          pattern = ".",
          skill_name = j_huangyu.name,
          prompt = "#j_huangyu-get",
        })
        if c and #c > 0 then
          room:obtainCard(player, c, true, fk.ReasonGive, t, j_huangyu.name)
        end
      end
    else
      -- 令你此回合可多使用一张杀
      room:setPlayerMark(player, "@j_huangyu_slash-turn", 1)
    end
  end,
})

-- 本回合多使用一张杀（TargetMod 修正次数）
j_huangyu:addEffect("targetmod", {
  residue_func = function(self, player, card)
    if player:getMark("@j_huangyu_slash-turn") > 0 and card and card.name == "slash" then
      return 1
    end
    return 0
  end,
})

-- 回合外失去牌时，可获得1枚汉祚（上限5）
j_huangyu:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_huangyu.name) or player.dead then return false end
    if player.room.current == player then return false end
    if player:getMark("@j_huangyu_hanzuo") >= 5 then return false end
    for _, move in ipairs(data) do
      if move.from == player and
        (move.fromArea == Player.Hand or move.fromArea == Player.Equip or move.fromArea == Player.Judge) then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_huangyu.name })
  end,
  on_use = function(self, event, target, player, data)
    local mark = player:getMark("@j_huangyu_hanzuo")
    if mark < 5 then
      player.room:setPlayerMark(player, "@j_huangyu_hanzuo", 1)
    end
  end,
})

-- 测试：游戏开始时获得3枚汉祚
j_huangyu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_huangyu.name)
    room.logic:trigger(fk.GameStart, me, {})
    lu.assertEquals(me:getMark("@j_huangyu_hanzuo"), 3, "皇誉：游戏开始应获得3枚汉祚")
  end)
end)

-- 测试：出牌阶段主动技两分支
j_huangyu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_huangyu.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "@j_huangyu_hanzuo", 3)
    local h1 = room:printCard("slash", Card.Spade, 2)
    local h2 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(comp2, { h1, h2 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local eff
    for _, spec in ipairs(j_huangyu.effect_spec_list) do
      if spec[1] == "active" then eff = spec[3] break end
    end
    lu.assertTrue(eff.can_use(eff, me), "皇誉：出牌阶段有汉祚应可使用")
    -- 目标选1：展示手牌并挑选一张
    local hand2 = comp2:getCardIds("h")
    FkTest.setNextReplies(me, { "1", { hand2[1] } }) -- comp2 选 1，me 挑一张
    eff.on_use(eff, room, { from = me, tos = { comp2 }, cards = {} })
    lu.assertEquals(me:getMark("@j_huangyu_hanzuo"), 2, "皇誉：应消耗1枚汉祚")
    lu.assertEquals(comp2:getMark("@j_huangyu_target-turn"), 1, "皇誉：该角色本回合应已使用过")
    lu.assertEquals(#comp2:getCardIds("h"), 1, "皇誉：应获得其一张手牌")
    -- 目标选2：本回合多使用一张杀
    me:getCardIds("h")
    room:setPlayerMark(me, "@j_huangyu_hanzuo", 2)
    FkTest.setNextReplies(me, { "2" })
    eff.on_use(eff, room, { from = me, tos = { comp2 }, cards = {} })
    lu.assertEquals(me:getMark("@j_huangyu_hanzuo"), 1, "皇誉：第二次应再消耗1枚汉祚")
    lu.assertEquals(me:getMark("@j_huangyu_slash-turn"), 1, "皇誉：本回合应可多使用一张杀")
    -- 已使用过的角色不可再选
    lu.assertFalse(eff.target_filter(eff, me, comp2, {}, {}, nil, {}), "皇誉：已使用过的角色不可再选")
  end)
end)

-- 测试：回合外失去牌获得汉祚（上限5）
j_huangyu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_huangyu.name)
    me.maxHp = 4
    me.hp = 4
    room.current = comp2
    room:setPlayerMark(me, "@j_huangyu_hanzuo", 5)
    local h = room:printCard("slash", Card.Spade, 2)
    room:obtainCard(me, { h }, true, fk.ReasonDraw, me, "test")
    -- 上限5时失去牌不再获得
    FkTest.setNextReplies(me, { "1" })
    room:throwCard(me:getCardIds("h"), j_huangyu.name, me, me)
    lu.assertEquals(me:getMark("@j_huangyu_hanzuo"), 5, "皇誉：已达上限5不再增加")
    -- 降到4后回合外失去牌可获得1枚
    room:setPlayerMark(me, "@j_huangyu_hanzuo", 4)
    local h2 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(me, { h2 }, true, fk.ReasonDraw, me, "test")
    FkTest.setNextReplies(me, { "1" })
    room:throwCard(me:getCardIds("h"), j_huangyu.name, me, me)
    lu.assertEquals(me:getMark("@j_huangyu_hanzuo"), 5, "皇誉：回合外失去牌应获得1枚汉祚")
  end)
end)

return j_huangyu