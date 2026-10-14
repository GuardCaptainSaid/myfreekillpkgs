-- 超人强二号 · 猛突（s_mengtu）
-- 你使用【杀】指定一个目标后，你可以令目标角色展示手牌，若其手牌中有能使用的【闪】，
-- 其必须使用【闪】抵消此【杀】，否则此【杀】伤害+1。
-- 其他角色使用牌抵消你使用的牌时，你可以摸一张牌，然后你与其展示手牌，
-- 若你手牌的花色数大于该角色的花色数，你对其造成差值点伤害，
-- 否则你随机获得其每种颜色的牌各一张。
local s_mengtu = fk.CreateSkill {
  name = "s_mengtu",
}

Fk:loadTranslationTable {
  ["s_mengtu"] = "猛突",
  [":s_mengtu"] = "你使用【杀】指定一个目标后，你可以令目标角色展示手牌，若其手牌中有能使用的【闪】，其必须使用【闪】抵消此【杀】，否则此【杀】伤害+1。其他角色使用牌抵消你使用的牌时，你可以摸一张牌，然后你与其展示手牌，若你手牌的花色数大于该角色的花色数，你对其造成差值点伤害，否则你随机获得其每种颜色的牌各一张。",
  ["#s_mengtu-invoke"] = "猛突：令 %dest 展示手牌，若其有【闪】则必须打出，否则此【杀】伤害+1",
  ["#s_mengtu-cancel"] = "猛突：%src 使用的牌被抵消，你可以摸一张牌并与 %dest 展示手牌",
  ["$s_mengtu1"] = "以力破巧，一往无前！",
  ["$s_mengtu2"] = "猛攻之下，无可阻挡！",
}

local function inMark(player, killId, targetId)
  local marks = player:getTableMark("@@s_mengtu_slash")
  for _, rec in ipairs(marks) do
    if rec[1] == killId and rec[2] == targetId then
      return true
    end
  end
  return false
end

local function removeMark(player, killId, targetId)
  local marks = player:getTableMark("@@s_mengtu_slash")
  for i = #marks, 1, -1 do
    if marks[i][1] == killId and marks[i][2] == targetId then
      table.remove(marks, i)
    end
  end
  player.room:setTableMark(player, "@@s_mengtu_slash", marks)
end

-- 部分1：你使用【杀】指定一个目标后
s_mengtu:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_mengtu.name) then return false end
    if not data.use or data.use.from ~= player then return false end
    if not data.card or data.card.trueName ~= "slash" then return false end
    if target.dead then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, s_mengtu.name, "#s_mengtu-invoke:::"..target.id) then
      return false
    end
    return {}
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 令目标展示手牌
    if #target:getCardIds("h") > 0 then
      room:showCards(target:getCardIds("h"), player, s_mengtu.name)
    end
    -- 若其手牌中有能使用的【闪】（有闪牌即视为能使用），则标记此杀：未抵消则伤害+1
    local hasJink = false
    for _, id in ipairs(target:getCardIds("h")) do
      if Fk:getCardById(id).trueName == "jink" then
        hasJink = true
        break
      end
    end
    if hasJink then
      local marks = player:getTableMark("@@s_mengtu_slash")
      table.insert(marks, { Card:getIdList(data.card)[1], target.id })
      room:setTableMark(player, "@@s_mengtu_slash", marks)
    end
  end,
})

-- 标记杀的伤害 +1
s_mengtu:addEffect(fk.DamageInflicted, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_mengtu.name) then return false end
    if data.to ~= target then return false end
    if not data.card then return false end
    local ids = Card:getIdList(data.card)
    if #ids == 0 then return false end
    return inMark(player, ids[1], target.id)
  end,
  on_use = function(self, event, target, player, data)
    data:changeDamage(1)
    removeMark(player, Card:getIdList(data.card)[1], target.id)
  end,
})

-- 兜底：杀使用结算完，清理残留标记
s_mengtu:addEffect(fk.CardUseFinished, {
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_mengtu.name) then return false end
    if not data.card or data.card.trueName ~= "slash" then return false end
    if data.from ~= player then return false end
    return #player:getTableMark("@@s_mengtu_slash") > 0
  end,
  on_use = function(self, event, target, player, data)
    player.room:setTableMark(player, "@@s_mengtu_slash", {})
  end,
})

-- 部分2：其他角色使用牌抵消你使用的牌时
s_mengtu:addEffect(fk.CardEffectCancelledOut, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_mengtu.name) then return false end
    -- target 为被抵消牌的使用者（你）
    if target ~= player then return false end
    return data ~= nil and data.card ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local canceler = data.to
    if not canceler or canceler.dead then return false end
    if not room:askToSkillInvoke(player, s_mengtu.name, "#s_mengtu-cancel:::"..data.to.id) then
      return false
    end
    return {}
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 移除被抵消的标记杀（被杀抵消则不再+1）
    if data.card.trueName == "slash" and data.to then
      removeMark(player, Card:getIdList(data.card)[1], data.to.id)
    end
    -- 摸一张牌
    player:drawCards(1, s_mengtu.name)
    local canceler = data.to
    if not canceler or canceler.dead then return end
    -- 展示双方手牌
    local myIds = player:getCardIds("h")
    local theirIds = canceler:getCardIds("h")
    if #myIds > 0 then room:showCards(myIds, player, s_mengtu.name) end
    if #theirIds > 0 then room:showCards(theirIds, player, s_mengtu.name) end
    -- 花色数比较
    local mySuits, theirSuits = {}, {}
    for _, id in ipairs(myIds) do mySuits[Fk:getCardById(id).suit] = true end
    for _, id in ipairs(theirIds) do theirSuits[Fk:getCardById(id).suit] = true end
    local myNum, theirNum = 0, 0
    for _ in pairs(mySuits) do myNum = myNum + 1 end
    for _ in pairs(theirSuits) do theirNum = theirNum + 1 end
    if myNum > theirNum then
      -- 对其造成差值点伤害
      room:damage{ from = player, to = canceler, damage = myNum - theirNum, skillName = s_mengtu.name }
    else
      -- 随机获得其每种颜色的牌各一张
      local reds, blacks = {}, {}
      for _, id in ipairs(theirIds) do
        local c = Fk:getCardById(id)
        if c.color == Card.Red then
          table.insert(reds, id)
        else
          table.insert(blacks, id)
        end
      end
      local gained = {}
      if #reds > 0 then table.insert(gained, room:tableRandomPick(reds)) end
      if #blacks > 0 then table.insert(gained, room:tableRandomPick(blacks)) end
      if #gained > 0 then
        room:obtainCard(player, gained, true, fk.ReasonPrey, canceler, s_mengtu.name)
      end
    end
  end,
})

-- 测试1：杀指定目标发动猛突，目标有闪但不出 → 伤害+1
s_mengtu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_mengtu.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    local sl = room:printCard("slash", Card.Spade, 3)
    local jink = room:printCard("jink", Card.Heart, 8)
    room:obtainCard(me, { sl }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { jink }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local slashId = me:getCardIds("h")[1]
    FkTest.setNextReplies(me, { "1" })
    FkTest.setNextReplies(comp2, { "0" })
    room:useCard{ from = me, tos = { comp2 }, card = Fk:getCardById(slashId) }
    lu.assertEquals(comp2.hp, 2, "猛突：目标有闪不出应伤害+1（共2点）")
  end)
end)

-- 测试2：目标手牌无闪 → 伤害+1
s_mengtu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_mengtu.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    local sl = room:printCard("slash", Card.Spade, 3)
    local sl2 = room:printCard("slash", Card.Club, 4)
    room:obtainCard(me, { sl }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { sl2 }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local slashId = me:getCardIds("h")[1]
    FkTest.setNextReplies(me, { "1" })
    FkTest.setNextReplies(comp2, { "0" })
    room:useCard{ from = me, tos = { comp2 }, card = Fk:getCardById(slashId) }
    lu.assertEquals(comp2.hp, 2, "猛突：目标无闪应伤害+1（共2点）")
  end)
end)

-- 测试3：其他角色用闪抵消你的杀 → 摸1 + 花色数大 → 差值伤害
s_mengtu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_mengtu.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    local sl = room:printCard("slash", Card.Spade, 3)
    local jink = room:printCard("jink", Card.Heart, 8)
    -- me 手牌：4种花色（杀+3张杂牌）→ 抵消后摸1，花色数仍可能多于 comp2
    local c1 = room:printCard("duel", Card.Heart, 2)
    local c2 = room:printCard("peach", Card.Club, 3)
    local c3 = room:printCard("slash", Card.Diamond, 5)
    room:obtainCard(me, { sl, c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { jink }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local hBefore = #me:getCardIds("h")
    local slashId = me:getCardIds("h")[1]
    local jink = Fk:getCardById(comp2:getCardIds("h")[1])
    FkTest.setNextReplies(comp2, { FkTest.ReplyCard(jink) })
    FkTest.setNextReplies(me, { "1" })
    room:useCard{ from = me, tos = { comp2 }, card = Fk:getCardById(slashId) }
    -- 摸1
    lu.assertEquals(#me:getCardIds("h"), hBefore + 1, "猛突：抵消后应摸1张牌")
    -- me 花色数（杀黑桃+红桃+梅花+方块=4）> comp2（仅闪红桃=1）→ 差值伤害3
    lu.assertEquals(comp2.hp, 1, "猛突：花色数差值为3应造成3点伤害")
  end)
end)

-- 测试4：花色数不大于对方 → 随机获得其每种颜色的牌各一张
s_mengtu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_mengtu.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    local sl = room:printCard("slash", Card.Spade, 3)
    local jink1 = room:printCard("jink", Card.Heart, 8)
    local jink2 = room:printCard("jink", Card.Club, 9)
    room:obtainCard(me, { sl }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { jink1, jink2 }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local hBefore = #me:getCardIds("h")
    local slashId = me:getCardIds("h")[1]
    local jink = Fk:getCardById(comp2:getCardIds("h")[1])
    FkTest.setNextReplies(comp2, { FkTest.ReplyCard(jink) })
    FkTest.setNextReplies(me, { "1" })
    room:useCard{ from = me, tos = { comp2 }, card = Fk:getCardById(slashId) }
    -- 摸1 + 获得红黑各一张（comp2 手牌红心+梅花）
    lu.assertEquals(#me:getCardIds("h"), hBefore + 3, "猛突：应摸1并随机获得其每种颜色牌各一张")
    lu.assertEquals(comp2.hp, 4, "猛突：花色数不大时不应造成伤害")
  end)
end)

return s_mengtu