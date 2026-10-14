-- 舒邵一号·散济
-- 出牌阶段限一次，你可以将任意张牌置于牌堆底并令等量名角色回复1点体力。若你本回合置于牌堆底的牌≥3张，你跳过本回合弃牌阶段并摸三张牌。
local s_shushao_sanji = fk.CreateSkill {
  name = "s_shushao_sanji",
}

Fk:loadTranslationTable{
  ["s_shushao_sanji"] = "散济",
  [":s_shushao_sanji"] = "出牌阶段限一次，你可以将任意张牌置于牌堆底并令等量名角色回复1点体力。若你本回合置于牌堆底的牌≥3张，你跳过本回合弃牌阶段并摸三张牌。",

  ["#s_sanji-put"] = "散济：选择任意张牌置于牌堆底",
  ["#s_sanji-target"] = "散济：选择等量名角色回复1点体力",
  ["@s_sanji_used"] = "散济",
  ["@s_sanji_bonus"] = "散济·益",

  ["$s_sanji1"] = "散粮济荒，活人无数！",
  ["$s_sanji2"] = "开仓放粮，以安民心！",
}

-- 回合开始：重置本回合标记
s_shushao_sanji:addEffect(fk.TurnStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    return player:hasSkill(s_shushao_sanji.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "@s_sanji_used-turn", 0)
    room:setPlayerMark(player, "@s_sanji_placed-turn", 0)
  end,
})

-- 主动技
s_shushao_sanji:addEffect("active", {
  anim_type = "support",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    local used = player:getMark("@s_sanji_used-turn")
    local limit = 1 + player:getMark("@s_sanji_bonus")
    return used < limit
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player.dead then return end
    local hand = player:getCardIds("hej")
    if #hand == 0 then return end
    -- 选任意张牌置于牌堆底
    local c = room:askToChooseCards(player, {
      target = player,
      flag = "hej",
      min = 1,
      max = #hand,
      cancelable = false,
      pattern = ".",
      skill_name = s_shushao_sanji.name,
      prompt = "#s_sanji-put",
    })
    if not c or #c == 0 then return end
    room:moveCards{ ids = c, toArea = Card.DrawPile, drawPilePosition = -1 }
    -- 累计本回合置于牌堆底的牌
    local placed = player:getMark("@s_sanji_placed-turn") + #c
    room:setPlayerMark(player, "@s_sanji_placed-turn", placed)
    -- 令等量名角色回复1点体力
    local targets = room:askToChoosePlayers(player, {
      targets = room.alive_players,
      min_num = #c,
      max_num = #c,
      cancelable = false,
      skill_name = s_shushao_sanji.name,
      prompt = "#s_sanji-target",
    })
    for _, p in ipairs(targets) do
      if not p.dead then
        room:recover{ who = p, num = 1, skillName = s_shushao_sanji.name }
      end
    end
    -- 次数消耗（第2次起消耗争赴加成）
    local used = player:getMark("@s_sanji_used-turn")
    room:setPlayerMark(player, "@s_sanji_used-turn", used + 1)
    if used + 1 > 1 and player:getMark("@s_sanji_bonus") > 0 then
      room:setPlayerMark(player, "@s_sanji_bonus", player:getMark("@s_sanji_bonus") - 1)
    end
    -- 若本回合置于牌堆底≥3：跳过弃牌阶段并摸三张
    if placed >= 3 and player:getMark("@s_sanji_skip-turn") == 0 and not player.dead then
      room:setPlayerMark(player, "@s_sanji_skip-turn", 1)
      player:skip(Player.Discard)
      player:drawCards(3, s_shushao_sanji.name)
    end
  end,
})

-- 测试：散济放置2张，令2名角色回复
s_shushao_sanji:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_shushao_sanji.name)
    me.maxHp = 3
    me.hp = 1
    comp2.maxHp = 3
    comp2.hp = 1
    room.current = me
    me.phase = Player.Play
    local h1 = room:printCard("slash", Card.Spade, 3)
    local h2 = room:printCard("slash", Card.Heart, 4)
    room:obtainCard(me, { h1, h2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local h = me:getCardIds("h")
    -- 一次传入全部回复：回复1=选2张牌（askToChooseCards 纯数组）；回复2=选目标
    FkTest.setNextReplies(me, { { h[1], h[2] }, { card = { subcards = {} }, targets = { me.id, comp2.id } } } )
    -- 找到主动技子技能并调用 onUse
    local active_sk
    for _, sk in ipairs(s_shushao_sanji.effects) do
      if sk:isInstanceOf(ActiveSkill) then active_sk = sk break end
    end
    lu.assertNotNil(active_sk, "散济：应存在主动技子技能")
    local eff = { from = me, tos = {}, cards = {} }
    active_sk:onUse(room, eff)
    lu.assertEquals(me.hp, 2, "散济：应回复1点体力")
    lu.assertEquals(comp2.hp, 2, "散济：目标角色应回复1点体力")
    lu.assertEquals(me:getMark("@s_sanji_used-turn"), 1, "散济：应消耗1次次数")
    lu.assertEquals(me:getMark("@s_sanji_placed-turn"), 2, "散济：应累计放置2张")
    lu.assertEquals(me:getMark("@s_sanji_skip-turn"), 0, "散济：未达3张不应跳过弃牌阶段")
  end)
end)

-- 测试：放置3张 → 跳过弃牌阶段并摸3
s_shushao_sanji:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_shushao_sanji.name)
    me.maxHp = 3
    me.hp = 1
    room.current = me
    me.phase = Player.Play
    local h1 = room:printCard("slash", Card.Spade, 3)
    local h2 = room:printCard("slash", Card.Heart, 4)
    local h3 = room:printCard("dodge", Card.Club, 5)
    room:obtainCard(me, { h1, h2, h3 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local h = me:getCardIds("h")
    local handBefore = #me:getCardIds("h")
    -- 一次传入全部回复：回复1=选3张牌；回复2=选目标
    FkTest.setNextReplies(me, { { h[1], h[2], h[3] }, { card = { subcards = {} }, targets = { me.id } } })
    local active_sk
    for _, sk in ipairs(s_shushao_sanji.effects) do
      if sk:isInstanceOf(ActiveSkill) then active_sk = sk break end
    end
    lu.assertNotNil(active_sk, "散济：应存在主动技子技能")
    local eff = { from = me, tos = {}, cards = {} }
    active_sk:onUse(room, eff)
    lu.assertEquals(me:getMark("@s_sanji_placed-turn"), 3, "散济：应累计放置3张")
    lu.assertEquals(me:getMark("@s_sanji_skip-turn"), 1, "散济：达3张应跳过弃牌阶段")
    lu.assertEquals(#me:getCardIds("h"), handBefore - 3 + 3, "散济：应摸三张牌")
    lu.assertEquals(me.hp, 2, "散济：应回复1点体力")
  end)
end)

return s_shushao_sanji