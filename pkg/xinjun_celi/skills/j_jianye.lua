-- 君孙权·建业
-- 限定技，出牌阶段，你可将装备区所有【长江天堑】置于牌堆底，称为“建业”。然后你从牌堆摸等同于“建业”数量的牌，且本回合使用牌无距离次数限制。若“建业”中包含四种花色，你令至多四名角色各弃两张牌并令你获得“安吴”和“连破”直到下回合开始。
local j_jianye = fk.CreateSkill {
  name = "j_jianye",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["j_jianye"] = "建业",
  [":j_jianye"] = "限定技，出牌阶段，你可将装备区所有【长江天堑】置于牌堆底，称为“建业”。然后你从牌堆摸等同于“建业”数量的牌，且本回合使用牌无距离次数限制。若“建业”中包含四种花色，你令至多四名角色各弃两张牌并令你获得“安吴”和“连破”直到下回合开始。",

  ["#j_jianye-targets"] = "建业：选择至多四名角色，令其各弃置两张牌",
  ["#j_jianye-discard"] = "建业：弃置两张牌",
  ["@j_jianye_longjian"] = "建业",

  ["$j_jianye1"] = "承父兄之业，建不朽之功！",
  ["$j_jianye2"] = "鼎足江东，坐断东南！",
}

local function isChangjiang(player, id)
  local ve = player:getVirtualEquip(id)
  if ve then return ve.name == "j_changjiang" end
  return Fk:getCardById(id).name == "j_changjiang"
end

j_jianye:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    if player:getMark("@j_jianye_used") > 0 then return false end
    if player.phase ~= Player.Play then return false end
    for _, id in ipairs(player:getCardIds(Player.Equip)) do
      if isChangjiang(player, id) then return true end
    end
    return false
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    room:setPlayerMark(player, "@j_jianye_used", 1)
    local cjs = {}
    for _, id in ipairs(player:getCardIds(Player.Equip)) do
      if isChangjiang(player, id) then table.insert(cjs, id) end
    end
    if #cjs == 0 then return end
    -- 置于牌堆底（建业）
    room:moveCards{
      ids = cjs,
      toArea = Card.DrawPile,
      moveReason = fk.ReasonPut,
      skillName = j_jianye.name,
      proposer = player,
      drawPilePosition = -1,
    }
    -- 摸等同于建业数量的牌
    player:drawCards(#cjs, j_jianye.name)
    -- 本回合使用牌无距离次数限制
    room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 1)
    room:setPlayerMark(player, MarkEnum.BypassDistancesLimit, 1)
    room:setPlayerMark(player, "@j_jianye_bypass-turn", 1)
    -- 花色集合
    local suits = {}
    for _, id in ipairs(cjs) do
      local s = Fk:getCardById(id).suit
      if not table.contains(suits, s) then table.insert(suits, s) end
    end
    if #suits == 4 then
      -- 令至多四名角色各弃两张牌
      local targets = room:askToChoosePlayers(player, {
        targets = room:getOtherPlayers(player),
        min_num = 0,
        max_num = 4,
        cancelable = true,
        skill_name = j_jianye.name,
        prompt = "#j_jianye-targets",
      })
      for _, t in ipairs(targets) do
        if not t.dead and not t:isAllNude() then
          local tc = t:getCardIds("hej")
          local n = math.min(2, #tc)
          if n > 0 then
            local c = room:askToChooseCards(t, {
              target = t,
              flag = "hej",
              min = n,
              max = n,
              cancelable = false,
              pattern = ".",
              skill_name = j_jianye.name,
              prompt = "#j_jianye-discard",
            })
            if c and #c > 0 then
              room:throwCard(c, j_jianye.name, t, t)
            end
          end
        end
      end
      -- 获得安吴和连破直到下回合开始
      room:handleAddLoseSkills(player, "j_anwu|j_lianpo2", nil, false, true)
      room:setPlayerMark(player, "@j_jianye_skills-turn", 1)
    end
  end,
})

-- 回合结束时清除无距离次数限制
j_jianye:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    return player:getMark("@j_jianye_bypass-turn") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 0)
    room:setPlayerMark(player, MarkEnum.BypassDistancesLimit, 0)
    room:setPlayerMark(player, "@j_jianye_bypass-turn", 0)
  end,
})

-- 下回合开始时移除安吴与连破
j_jianye:addEffect(fk.TurnStart, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    return player:getMark("@j_jianye_skills-turn") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:handleAddLoseSkills(player, "-j_anwu|-j_lianpo2", nil, false, true)
    room:setPlayerMark(player, "@j_jianye_skills-turn", 0)
  end,
})

-- 测试：建业置牌堆底、摸牌、无距离次数限制
j_jianye:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianye.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    -- me 装备两张长江天堑（花色不同）
    local cj1 = room:printCard("j_changjiang", Card.Spade, 7)
    local cj2 = room:printCard("j_changjiang", Card.Diamond, 8)
    room:moveCardTo(cj1, Player.Equip, me, fk.ReasonPut, j_jianye.name)
    room:moveCardTo(cj2, Player.Equip, me, fk.ReasonPut, j_jianye.name)
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local eff
    for _, spec in ipairs(j_jianye.effect_spec_list) do
      if spec[1] == "active" then eff = spec[3] break end
    end
    lu.assertTrue(eff.can_use(eff, me), "建业：出牌阶段有长江天堑应可使用")
    local handBefore = #me:getCardIds("h")
    eff.on_use(eff, room, { from = me, tos = {}, cards = {} })
    lu.assertEquals(#me:getCardIds(Player.Equip), 0, "建业：装备区长江天堑应清空")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 2, "建业：应摸等同于建业数量的牌")
    lu.assertEquals(me:getMark(MarkEnum.BypassTimesLimit), 1, "建业：本回合应无次数限制")
    lu.assertEquals(me:getMark(MarkEnum.BypassDistancesLimit), 1, "建业：本回合应无距离限制")
    lu.assertFalse(me:hasSkill("j_anwu"), "建业：未含四花色不应获得安吴")
    -- 回合结束清除限制
    room.logic:trigger(fk.TurnEnd, me, {})
    lu.assertEquals(me:getMark(MarkEnum.BypassTimesLimit), 0, "建业：回合结束应恢复次数限制")
    lu.assertEquals(me:getMark(MarkEnum.BypassDistancesLimit), 0, "建业：回合结束应恢复距离限制")
  end)
end)

-- 测试：四花色时弃牌并获得安吴与连破、下回合开始移除
j_jianye:addTest(function(room, me)
  local comp2, comp3 = room.players[2], room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianye.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    -- 四张不同花色长江天堑
    local suits = { Card.Spade, Card.Heart, Card.Club, Card.Diamond }
    for i, s in ipairs(suits) do
      local cj = room:printCard("j_changjiang", s, 5 + i)
      room:moveCardTo(cj, Player.Equip, me, fk.ReasonPut, j_jianye.name)
    end
    -- comp2 有两张牌可弃
    local h1 = room:printCard("slash", Card.Spade, 2)
    local h2 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(comp2, { h1, h2 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local eff
    for _, spec in ipairs(j_jianye.effect_spec_list) do
      if spec[1] == "active" then eff = spec[3] break end
    end
    local comp2Hand = comp2:getCardIds("h")
    FkTest.setNextReplies(me, { { comp2.id }, { comp2Hand[1], comp2Hand[2] } })
    eff.on_use(eff, room, { from = me, tos = {}, cards = {} })
    lu.assertEquals(me:getMark("@j_jianye_used"), 1, "建业：限定技已发动")
    lu.assertTrue(me:hasSkill("j_anwu"), "建业：四花色应获得安吴")
    lu.assertTrue(me:hasSkill("j_lianpo2"), "建业：四花色应获得连破")
    lu.assertEquals(#comp2:getCardIds("hej"), 0, "建业：被选角色应弃置两张牌")
    -- 下回合开始移除
    room.logic:trigger(fk.TurnStart, me, {})
    lu.assertFalse(me:hasSkill("j_anwu"), "建业：下回合开始应移除安吴")
    lu.assertFalse(me:hasSkill("j_lianpo2"), "建业：下回合开始应移除连破")
  end)
end)

return j_jianye