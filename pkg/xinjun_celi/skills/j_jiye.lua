-- 君刘备·继业
-- 限定技，出牌阶段，若场上无群势力角色，则你可将所有“汉祚”转化为“龙威”。拥有“龙威”时，你使用牌无距离限制。每当你失去“龙威”时，你令所有其他角色各交给你一张牌。
local j_jiye = fk.CreateSkill {
  name = "j_jiye",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["j_jiye"] = "继业",
  [":j_jiye"] = "限定技，出牌阶段，若场上无群势力角色，则你可将所有“汉祚”转化为“龙威”。拥有“龙威”时，你使用牌无距离限制。每当你失去“龙威”时，你令所有其他角色各交给你一张牌。",

  ["@j_jiye_longwei"] = "龙威",

  ["$j_jiye1"] = "承先帝之志，继汉室之业！",
  ["$j_jiye2"] = "龙威既显，四海宾服！",
}

-- 失去龙威时：令所有其他角色各交给你一张牌
-- 注意：目前“龙威”为永久状态（除本函数外无清零路径）。
-- 若后续需要设计龙威的失去方式（如轮末失去、使用后消耗等），
-- 在清零龙威标记（@j_jiye_longwei）处调用本函数即可。
local function loseLongwei(room, player)
  room:setPlayerMark(player, "@j_jiye_longwei", 0)
  room:setPlayerMark(player, MarkEnum.BypassDistancesLimit, 0)
  if player.dead then return end
  local gained = 0
  for _, p in ipairs(room:getOtherPlayers(player)) do
    if not p.dead and not p:isAllNude() then
      local c = room:askToChooseCards(p, {
        target = p,
        flag = "hej",
        min = 0,
        max = 1,
        cancelable = true,
        pattern = ".",
        skill_name = j_jiye.name,
        prompt = "#j_jiye-give",
      })
      if c and #c > 0 then
        room:obtainCard(player, c, true, fk.ReasonGive, p, j_jiye.name)
        gained = gained + 1
      end
    end
  end
  return gained
end
j_jiye.loseLongwei = loseLongwei

Fk:loadTranslationTable{
  ["#j_jiye-give"] = "继业：是否交给刘备一张牌？",
}

-- 限定技：出牌阶段，若场上无群势力角色，将汉祚转化为龙威
j_jiye:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    if player:getMark("@j_jiye_used") > 0 then return false end
    if player.phase ~= Player.Play then return false end
    if player:getMark("@j_huangyu_hanzuo") <= 0 then return false end
    local room = player.room
    for _, p in ipairs(room.alive_players) do
      if p.kingdom == "qun" then return false end
    end
    return true
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local n = player:getMark("@j_huangyu_hanzuo")
    room:setPlayerMark(player, "@j_huangyu_hanzuo", 0)
    room:setPlayerMark(player, "@j_jiye_longwei", n)
    room:setPlayerMark(player, MarkEnum.BypassDistancesLimit, 1)
    room:setPlayerMark(player, "@j_jiye_used", 1)
  end,
})

-- 测试：can_use 条件（无群势力可发动 / 有群势力不可发动 / 无汉祚不可发动）
j_jiye:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiye.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    -- 场上所有角色改成非群势力（蜀）
    for _, p in ipairs(room.alive_players) do
      p.kingdom = "shu"
    end
    room:setPlayerMark(me, "@j_huangyu_hanzuo", 3)
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local eff
    for _, spec in ipairs(j_jiye.effect_spec_list) do
      if spec[1] == "active" then eff = spec[3] break end
    end
    lu.assertTrue(eff.can_use(eff, me), "继业：无群势力且出牌阶段有汉祚应可使用")
    -- 有群势力不可用
    room.players[2].kingdom = "qun"
    lu.assertFalse(eff.can_use(eff, me), "继业：场上有群势力角色不可发动")
    -- 无汉祚不可用
    room.players[2].kingdom = "shu"
    room:setPlayerMark(me, "@j_huangyu_hanzuo", 0)
    lu.assertFalse(eff.can_use(eff, me), "继业：无汉祚不可发动")
  end)
end)

-- 测试：发动后汉祚转龙威、使用牌无距离限制
j_jiye:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiye.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    for _, p in ipairs(room.alive_players) do
      p.kingdom = "shu"
    end
    room:setPlayerMark(me, "@j_huangyu_hanzuo", 3)
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local eff
    for _, spec in ipairs(j_jiye.effect_spec_list) do
      if spec[1] == "active" then eff = spec[3] break end
    end
    eff.on_use(eff, room, { from = me, tos = {}, cards = {} })
    lu.assertEquals(me:getMark("@j_huangyu_hanzuo"), 0, "继业：汉祚应清零")
    lu.assertEquals(me:getMark("@j_jiye_longwei"), 3, "继业：应获得3枚龙威")
    lu.assertEquals(me:getMark(MarkEnum.BypassDistancesLimit), 1, "继业：使用牌应无距离限制")
    lu.assertEquals(me:getMark("@j_jiye_used"), 1, "继业：限定技已发动")
    -- 失去龙威：收全场牌
    local comp2 = room.players[2]
    local h = room:printCard("slash", Card.Spade, 2)
    room:obtainCard(comp2, { h }, true, fk.ReasonDraw, comp2, "test")
    FkTest.setNextReplies(me, { { h } })
    j_jiye.loseLongwei(room, me)
    lu.assertEquals(me:getMark("@j_jiye_longwei"), 0, "继业：失去龙威后标记清零")
    lu.assertEquals(me:getMark(MarkEnum.BypassDistancesLimit), 0, "继业：失去龙威后距离限制恢复")
    lu.assertTrue(table.contains(me:getCardIds("h"), h), "继业：失去龙威应收取全场交牌")
  end)
end)

return j_jiye