local j_youji = fk.CreateSkill {
  name = "j_youji",
}

Fk:loadTranslationTable{
  ["j_youji"] = "诱机",
  [":j_youji"] = "出牌阶段限一次，你可令一名其他角色摸至多X张牌，令你本回合对其使用的下X张牌其不能响应并不计入次数限制。回合结束时，若其本回合进入过濒死状态，你获得本回合进入弃牌堆的牌。（X为其体力上限）",

  ["#j_youji-target"] = "诱机：选择一名其他角色",
  ["#j_youji-number"] = "诱机：选择令其摸牌的数量（至多 %arg 张）",

  ["$j_youji1"] = "以饵诱之，待其乱而动。",
  ["$j_youji2"] = "机已设下，只待君入。",
}

-- 出牌阶段限一次：令一名其他角色摸至多X张牌，并标记本回合对其的下X张牌不可响应、不计入次数
j_youji:addEffect("active", {
  anim_type = "control",
  prompt = "#j_youji-target",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    return player.phase == Player.Play and player:usedSkillTimes(j_youji.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
  end,
  times = function(self, player)
    return 1 - player:usedSkillTimes(j_youji.name, Player.HistoryPhase)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    if not target or target.dead then return end
    local x = target.maxHp
    if x <= 0 then return end
    local num = room:askToNumber(player, {
      min = 1,
      max = x,
      cancelable = true,
      skill_name = j_youji.name,
      prompt = "#j_youji-number:::" .. x,
    })
    if not num then return end
    room:drawCards(target, num, j_youji.name)
    room:setPlayerMark(target, "j_youji_caster-turn", player.id)
    room:setPlayerMark(target, "j_youji_times-turn", x)
    -- 标记本回合已发动：后续触发效果（记录弃牌、回合结束结算）以此为闸门。
    -- 引擎会把任何触发效果都计入 usedSkillTimes，若不设闸门，出牌阶段任意一张牌
    -- 进入弃牌堆都会错误"发动"诱机并提前消耗"出牌阶段限一次"的次数
    room:setPlayerMark(player, "j_youji_used-turn", 1)
  end,
})

-- 本回合对其使用的下X张牌：不可响应 + 不计入次数限制
j_youji:addEffect(fk.PreCardUse, {
  global = true,
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(j_youji.name) or player.dead then return false end
    if data.from ~= player or not data.tos then return false end
    for _, to in ipairs(data.tos) do
      if to:getMark("j_youji_caster-turn") == player.id and to:getMark("j_youji_times-turn") > 0 then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.disresponsiveList = data.disresponsiveList or {}
    for _, to in ipairs(data.tos) do
      if to:getMark("j_youji_caster-turn") == player.id and to:getMark("j_youji_times-turn") > 0 then
        table.insertIfNeed(data.disresponsiveList, to)
        room:setPlayerMark(to, "j_youji_times-turn", to:getMark("j_youji_times-turn") - 1)
      end
    end
    data.extraUse = true
  end,
})

-- 记录其本回合是否进入过濒死状态
j_youji:addEffect(fk.EnterDying, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_youji.name) or player.dead then return false end
    return target:getMark("j_youji_caster-turn") == player.id
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(target, "j_youji_dying-turn", 1)
  end,
})

-- 记录本回合进入弃牌堆的牌（-turn 标记，回合结束自动清空）
-- 注意：仅诱机已发动后才记录；否则引擎会把"任意一张牌进弃牌堆"也计为诱机发动，
-- 导致后续无法使用
j_youji:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_youji.name) or player.dead then return false end
    if player:getMark("j_youji_used-turn") == 0 then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile and #move.moveInfo > 0 then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = player:getTableMark("j_youji_discard-turn")
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo) do
          table.insertIfNeed(ids, info.cardId)
        end
      end
    end
    room:setPlayerMark(player, "j_youji_discard-turn", ids)
  end,
})

-- 回合结束时：若其本回合进入过濒死状态，你获得本回合进入弃牌堆的牌
j_youji:addEffect(fk.TurnEnd, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_youji.name) and not player.dead
      and player:getMark("j_youji_used-turn") ~= 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 找到本回合被诱机的角色
    local marked
    for _, p in ipairs(room:getAlivePlayers()) do
      if p:getMark("j_youji_caster-turn") == player.id and p ~= player then
        marked = p
        break
      end
    end
    if not marked or marked:getMark("j_youji_dying-turn") ~= 1 then return end
    -- 仍留在弃牌堆中的牌
    local valid = table.filter(player:getTableMark("j_youji_discard-turn"), function(cid)
      return table.contains(room.discard_pile, cid)
    end)
    if #valid > 0 then
      room:obtainCard(player, valid, true, fk.ReasonDraw, player, j_youji.name)
    end
  end,
})

-- 测试辅助：askToNumber 回复
local function replyNumber(n)
  return { card = { skill = "spin_skill", subcards = {} }, targets = {}, interaction_data = n }
end

-- 回归测试：未发动诱机时，牌进入弃牌堆不应错误发动诱机、不应消耗出牌阶段限次
j_youji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_youji.name)
    me.phase = Player.Play
    local c = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(me, { c.id }, true, fk.ReasonDraw, me, "test")
    room:throwCard(c.id, j_youji.name, me, me)
    lu.assertEquals(me:usedSkillTimes(j_youji.name, Player.HistoryPhase), 0, "未发动时弃牌不应消耗出牌阶段限次")
    lu.assertEquals(me:getMark("j_youji_used-turn"), 0, "未发动时不应标记为已发动")
    local skel = Fk.skills[j_youji.name]:getSkeleton()
    lu.assertEquals(skel.effects[1]:canUse(me), true, "弃牌后诱机应仍可发动")
  end)
end)

-- 测试：发动诱机后标记已发动、目标摸 X 张牌，后续弃牌被记录
j_youji:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_youji.name)
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local handBefore = #comp2:getCardIds("h")
    local sk = Fk.skills[j_youji.name]
    FkTest.setNextReplies(me, { replyNumber(comp2.maxHp) })
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = { comp2 }, cards = {} })
    end, {})
    lu.assertEquals(me:usedSkillTimes(j_youji.name, Player.HistoryPhase), 1, "发动后应计一次限次")
    lu.assertEquals(me:getMark("j_youji_used-turn"), 1, "发动后应标记本回合已发动")
    lu.assertEquals(comp2:getMark("j_youji_caster-turn"), me.id, "目标应记录施法者")
    lu.assertEquals(comp2:getMark("j_youji_times-turn"), comp2.maxHp, "应记录下X张牌数")
    lu.assertEquals(#comp2:getCardIds("h"), handBefore + comp2.maxHp, "目标应摸X张牌")
    -- 发动后再有牌进弃牌堆：应被记录（供回合结束获得）
    local c = room:printCard("jink", Card.Heart, 2)
    room:obtainCard(me, { c.id }, true, fk.ReasonDraw, me, "test")
    room:throwCard(c.id, j_youji.name, me, me)
    lu.assertEquals(#me:getTableMark("j_youji_discard-turn"), 1, "发动后弃牌应被记录")
  end)
end)

-- 测试：目标本回合进入濒死后，回合结束获得本回合弃牌堆中的牌
j_youji:addTest(function(room, me)
  local comp2 = room.players[2]
  local discardedId
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_youji.name)
    me.phase = Player.Play
    local sk = Fk.skills[j_youji.name]
    FkTest.setNextReplies(me, { replyNumber(1) })
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = { comp2 }, cards = {} })
    end, {})
    local c = room:printCard("slash", Card.Spade, 7)
    discardedId = c.id
    room:obtainCard(me, { c.id }, true, fk.ReasonDraw, me, "test")
    room:throwCard(c.id, j_youji.name, me, me)
    -- 目标进入濒死（触发诱机的濒死记录效果）
    room.logic:trigger(fk.EnterDying, comp2, {})
  end)
  FkTest.runInRoom(function()
    lu.assertEquals(comp2:getMark("j_youji_dying-turn"), 1, "目标进入濒死应被记录")
    local before = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, me, {})
    lu.assertEquals(#me:getCardIds("h"), before + 1, "目标濒死后回合结束应获得弃牌堆中的牌")
    lu.assertFalse(table.contains(room.discard_pile, discardedId), "弃牌堆中的牌应被获得")
  end)
end)

return j_youji
