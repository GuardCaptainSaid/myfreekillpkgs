local j_jianji = fk.CreateSkill {
  name = "j_jianji",
}

Fk:loadTranslationTable{
  ["j_jianji"] = "间计",
  [":j_jianji"] = "出牌阶段限一次，你可以弃两张牌并令两名有手牌的角色拼点，没赢的角色对另一名角色使用一张【决斗】否则失去一点体力，然后你获得两张拼点牌。",

  ["#j_jianji-discard"] = "间计：弃置两张牌",
  ["#j_jianji-target"] = "间计：选择两名有手牌的角色拼点",
  ["#j_jianji-duel"] = "间计：没赢的角色对另一名角色使用【决斗】",
}

local function jianji_trigger(player)
  local room = player.room

  -- 1. 弃两张牌
  local cards = room:askToDiscard(player, {
    min_num = 2,
    max_num = 2,
    include_equip = true,
    skill_name = j_jianji.name,
    prompt = "#j_jianji-discard",
    cancelable = true,
    skip = true,
  })
  if #cards ~= 2 then return end
  room:throwCard(cards, j_jianji.name, player, player)

  -- 2. 选两名有手牌的其他角色
  local candidates = table.filter(room.alive_players, function(p)
    return p ~= player and not p:isKongcheng()
  end)
  if #candidates < 2 then return end
  local tos = room:askToChoosePlayers(player, {
    targets = candidates,
    min_num = 2,
    max_num = 2,
    skill_name = j_jianji.name,
    prompt = "#j_jianji-target",
  })
  if #tos ~= 2 then return end

  -- 3. 拼点（结果写入传入的 pd 表）
  local pd = { from = tos[1], tos = { tos[2] }, reason = j_jianji.name, results = {} }
  room:pindian(pd)
  local fromCard = pd.fromCard
  local toCard = pd.results[tos[2]].toCard

  -- 4. 判胜负：没赢的角色对另一名角色使用【决斗】，否则失去一点体力
  local pairs = {}
  if fromCard.number > toCard.number then
    table.insert(pairs, { loser = tos[2], winner = tos[1] })
  elseif fromCard.number < toCard.number then
    table.insert(pairs, { loser = tos[1], winner = tos[2] })
  else
    -- 平局：双方都算没赢，各自对对方使用【决斗】
    table.insert(pairs, { loser = tos[1], winner = tos[2] })
    table.insert(pairs, { loser = tos[2], winner = tos[1] })
  end
  for _, pair in ipairs(pairs) do
    local loser, winner = pair.loser, pair.winner
    if loser:isAlive() and winner:isAlive() then
      local duel = Fk:cloneCard("duel")
      duel.skillName = j_jianji.name
      room:useCard{ from = loser, tos = { winner }, card = duel }
    elseif loser:isAlive() then
      room:loseHp(loser, 1, j_jianji.name)
    end
  end

  -- 5. 获得两张拼点牌（拼点结算后拼点牌进入弃牌堆）
  local ids = {}
  local fId = fromCard:getEffectiveId()
  if fId then table.insert(ids, fId) end
  local tId = toCard:getEffectiveId()
  if tId then table.insert(ids, tId) end
  if #ids > 0 then
    room:obtainCard(player, ids, false, fk.ReasonPrey, player, j_jianji.name)
  end

  room:setPlayerMark(player, "j_jianji_used", 1)
end

-- 出牌阶段限一次主动技
j_jianji:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  can_use = function(self, player)
    if player:getMark("j_jianji_used") ~= 0 then return false end
    if #player:getCardIds("he") < 2 then return false end
    local n = 0
    for _, p in ipairs(player.room.alive_players) do
      if p ~= player and not p:isKongcheng() then
        n = n + 1
        if n >= 2 then break end
      end
    end
    return n >= 2
  end,
  on_use = function(self, room, effect)
    jianji_trigger(effect.from)
  end,
})

-- 回合开始重置限次
j_jianji:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_jianji.name) and player.phase == Player.Start
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_jianji_used", 0)
  end,
})

-- 测试：完整发动间计——弃两张牌、选两名角色拼点、点数小者受决斗伤害、获得两张拼点牌
j_jianji:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  local c1, c2, p1, p2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianji.name)
    c1 = room:printCard("slash", Card.Spade, 3)
    c2 = room:printCard("peach", Card.Heart, 4)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    p1 = room:printCard("dismantlement", Card.Club, 5)
    p2 = room:printCard("snatch", Card.Diamond, 2)
    room:obtainCard(comp2, { p1 }, true, fk.ReasonDraw, comp2, "test")
    room:obtainCard(comp3, { p2 }, true, fk.ReasonDraw, comp3, "test")
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, {
      FkTest.ReplyDiscard({ c1.id, c2.id }),
      FkTest.ReplyChoosePlayer({ comp2, comp3 }),
    })
    FkTest.setNextReplies(comp2, { FkTest.ReplyChooseCards({ p1.id }) })
    FkTest.setNextReplies(comp3, { FkTest.ReplyChooseCards({ p2.id }) })

    local sk = Fk.skills[j_jianji.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(me:getMark("j_jianji_used"), 1, "应消耗出牌阶段限次")
    lu.assertEquals(comp2.hp, 3, "点数小者（无杀响应）应受决斗一点伤害")
    lu.assertEquals(#me:getCardIds("h"), 2, "应获得两张拼点牌")
  end)
end)

-- 测试：回合开始（Start 阶段）重置间计限次
j_jianji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianji.name)
    room:setPlayerMark(me, "j_jianji_used", 1)
    me.phase = Player.Start
  end)
  FkTest.runInRoom(function()
    room.logic:trigger(fk.EventPhaseStart, me, { phase = Player.Start })
    lu.assertEquals(me:getMark("j_jianji_used"), 0, "回合开始应重置间计限次")
  end)
end)

return j_jianji