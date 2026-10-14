-- 舒邵三号·散廪（锁定技）
-- 每个回合结束时，若你本回合因其他角色的技能获得了牌，则你将手牌中的这些牌分配给
-- 其他角色（每名其他角色获得的牌数之差需不大于1），然后你将手牌摸至体力上限。
local s_sanlin2 = fk.CreateSkill {
  name = "s_sanlin2",
}

Fk:loadTranslationTable{
  ["s_sanlin2"] = "散廪",
  [":s_sanlin2"] = "锁定技，每个回合结束时，若你本回合因其他角色的技能获得了牌，则你将手牌中的这些牌分配给其他角色（每名其他角色获得的牌数之差需不大于1），然后你将手牌摸至体力上限。",

  ["#s_sanlin2-distribute_log"] = "散廪：%arg 将 %arg2 张牌分配给其他角色",

  ["$s_sanlin21"] = "廪有余粮，当散诸众！",
  ["$s_sanlin22"] = "均贫富，济孤寡！",
}

-- 回合开始：清空本回合记录
s_sanlin2:addEffect(fk.TurnStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(s_sanlin2.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@@s_sanlin2_got", {})
  end,
})

-- 因其他角色的技能获得牌时：记录牌id
s_sanlin2:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_sanlin2.name) then return false end
    if not data then return false end
    for _, move in ipairs(data) do
      if move.to == player and move.toArea == Card.PlayerHand then
        -- 因其他角色的技能获得：来源为其他角色且为技能移动
        if move.from and move.from ~= player and move.moveReason == fk.ReasonSkill then
          return true
        end
        if move.skillName and move.skillName ~= "" and move.from and move.from ~= player then
          return true
        end
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local got = player:getTableMark("@@s_sanlin2_got")
    for _, move in ipairs(data) do
      if move.to == player and move.toArea == Card.PlayerHand then
        local isSkill = (move.moveReason == fk.ReasonSkill) or
          (move.skillName and move.skillName ~= "" and move.from and move.from ~= player)
        if isSkill and move.from and move.from ~= player then
          for _, info in ipairs(move.moveInfo) do
            if not table.contains(got, info.cardId) then
              table.insert(got, info.cardId)
            end
          end
        end
      end
    end
    player.room:setPlayerMark(player, "@@s_sanlin2_got", got)
  end,
})

-- 每个回合结束时：分配本回合所得牌，然后手牌摸至体力上限
s_sanlin2:addEffect(fk.TurnEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_sanlin2.name) then return false end
    return #player:getTableMark("@@s_sanlin2_got") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local got = player:getTableMark("@@s_sanlin2_got")
    room:setPlayerMark(player, "@@s_sanlin2_got", {})
    -- 仍在我手牌中的牌
    local inHand = table.filter(got, function(id)
      return table.contains(player:getCardIds("h"), id)
    end)
    local others = table.filter(room:getOtherPlayers(player), function(p)
      return not p.dead
    end)
    if #inHand > 0 and #others > 0 then
      -- 平均分配：每名其他角色获得 floor/ceil 张，差不超过1
      local per = math.floor(#inHand / #others)
      local rem = #inHand % #others
      for i, p in ipairs(others) do
        local n = per + (i <= rem and 1 or 0)
        if n > 0 then
          local ids = {}
          for _ = 1, n do
            table.insert(ids, table.remove(inHand, 1))
          end
          room:obtainCard(p, ids, true, fk.ReasonGive, player, s_sanlin2.name)
        end
      end
    end
    -- 手牌摸至体力上限
    local need = math.max(player.maxHp - #player:getCardIds("h"), 0)
    if need > 0 then
      player:drawCards(need, s_sanlin2.name)
    end
  end,
})

-- 测试：回合结束未因技能得牌 → 不触发
s_sanlin2:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_sanlin2.name)
    me.maxHp = 3
    me.hp = 3
    room:setPlayerMark(me, "@@s_sanlin2_got", {})
    local c1 = room:printCard("slash", Card.Spade, 3)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local hBefore = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, me, { who = me })
    lu.assertEquals(#me:getCardIds("h"), hBefore, "散廪：无技能所得牌时不触发")
  end)
end)

-- 测试：本回合因技能获得牌 → 平均分配后摸至体力上限
s_sanlin2:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_sanlin2.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 3
    comp3.maxHp = 3
    comp3.hp = 3
    -- 其他角色标死，使存活的其他角色仅为 comp2/comp3
    for i = 4, #room.players do
      room.players[i].dead = true
    end
    -- 记录3张"因技能获得"的牌并放入手牌（存数字id）
    local ids = {}
    for _, s in ipairs({ Card.Spade, Card.Heart, Card.Club }) do
      local c = room:printCard("slash", s, 4)
      table.insert(ids, c.id)
    end
    room:obtainCard(me, ids, true, fk.ReasonDraw, me, "test")
    room:setPlayerMark(me, "@@s_sanlin2_got", ids)
  end)
  FkTest.runInRoom(function()
    room.logic:trigger(fk.TurnEnd, me, { who = me })
    -- 3张牌分给2名其他角色：1张+2张（差≤1）
    lu.assertEquals(#comp2:getCardIds("h"), 2, "散廪：一名角色应获2张")
    lu.assertEquals(#comp3:getCardIds("h"), 1, "散廪：另一名角色应获1张")
    -- 分配后手牌摸至体力上限（3）
    lu.assertEquals(#me:getCardIds("h"), 3, "散廪：应摸至体力上限")
    lu.assertEquals(#me:getTableMark("@@s_sanlin2_got"), 0, "散廪：记录应清空")
  end)
end)

return s_sanlin2