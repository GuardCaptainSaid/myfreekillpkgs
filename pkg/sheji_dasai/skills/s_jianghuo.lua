-- 轲比能一号 · 疆祸（s_jianghuo）
-- 每轮限一次，其他角色的出牌阶段开始时，你可以弃置任意张手牌，令其前X张手牌只能指定你为目标。
-- 若如此做，此阶段结束时，若你没有受到伤害，你可以对其使用X-1张【杀】（X为你弃置的手牌数量）。
local s_jianghuo = fk.CreateSkill {
  name = "s_jianghuo",
}

Fk:loadTranslationTable {
  ["s_jianghuo"] = "疆祸",
  [":s_jianghuo"] = "每轮限一次，其他角色的出牌阶段开始时，你可以弃置任意张手牌，令其前X张手牌只能指定你为目标。若如此做，此阶段结束时，若你没有受到伤害，你可以对其使用X-1张【杀】（X为你弃置的手牌数量）。",
  ["#s_jianghuo-invoke"] = "疆祸：弃置任意张手牌，令 %dest 前X张手牌只能指定你为目标",
  ["#s_jianghuo-discard"] = "疆祸：弃置任意张手牌（X=弃置数）",
  ["#s_jianghuo-slash"] = "疆祸：此阶段你没有受到伤害，可对其使用 %arg 张【杀】",
  ["$s_jianghuo1"] = "引狼入室，祸起萧墙！",
  ["$s_jianghuo2"] = "北疆之祸，自此始矣！",
}

s_jianghuo:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_jianghuo.name) then return false end
    if target == player or target.dead then return false end
    if target.phase ~= Player.Play then return false end
    -- 每轮限一次
    return player:usedSkillTimes(s_jianghuo.name, Player.HistoryRound) == 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if #player:getCardIds("h") == 0 then return false end
    return room:askToSkillInvoke(player, s_jianghuo.name, "#s_jianghuo-invoke:::"..target.id)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = room:askToDiscard(player, {
      min_num = 1,
      max_num = #player:getCardIds("h"),
      skill_name = s_jianghuo.name,
      prompt = "#s_jianghuo-discard",
      cancelable = false,
    })
    if #ids == 0 then return end
    local x = #ids
    player:setSkillUseHistory(s_jianghuo.name, 1, Player.HistoryRound)
    room:notifySkillInvoked(player, s_jianghuo.name, "control")
    player:broadcastSkillInvoke(s_jianghuo.name)
    -- 记录：令该角色前X张手牌只能指定我为目标；记录X；清空本阶段受伤害标记
    room:setTag("s_jianghuo_target_"..target.id, x)
    room:setTag("s_jianghuo_x_"..target.id, x)
    room:setTag("s_jianghuo_hurt_"..target.id, 0)
  end,
})

-- 该角色使用手牌时，前X张只能指定我为目标（强制移除其他目标并添加我）
s_jianghuo:addEffect(fk.TargetSpecifying, {
  can_trigger = function(self, event, target, player, data)
    if not data.use or not data.use.from then return false end
    local from = data.use.from
    local x = from.room:getTag("s_jianghuo_target_"..from.id)
    if not x or x <= 0 then return false end
    if not from:hasSkill("s_jianghuo") then return false end
    -- 我（轲比能）在场且该角色使用手牌
    if player.dead or not player:hasSkill(s_jianghuo.name) then return false end
    if not data.use:isUsingHandcard(from) then return false end
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.use.from
    local x = room:getTag("s_jianghuo_target_"..from.id)
    -- 强制目标：只能指定我为目标
    local hasMe = data:hasTarget(player)
    for _, p in ipairs(data:getAllTargets()) do
      if p ~= player then
        data:removeTarget(p)
      end
    end
    if not hasMe and player:isAlive() then
      data:addTarget(player)
    end
    -- 计数-1
    room:setTag("s_jianghuo_target_"..from.id, x - 1)
  end,
})

-- 记录本阶段我是否受到伤害
s_jianghuo:addEffect(fk.Damaged, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(s_jianghuo.name) then return false end
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room.alive_players) do
      local t = room:getTag("s_jianghuo_hurt_"..p.id)
      if t then
        room:setTag("s_jianghuo_hurt_"..p.id, t + 1)
      end
    end
  end,
})

-- 出牌阶段结束时：未受伤害则对其使用 X-1 张杀
s_jianghuo:addEffect(fk.EventPhaseEnd, {
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_jianghuo.name) then return false end
    -- 只响应出牌阶段结束
    if not data or data.phase ~= Player.Play then return false end
    local x = player.room:getTag("s_jianghuo_x_"..target.id)
    return x ~= nil and x > 1
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local x = room:getTag("s_jianghuo_x_"..target.id)
    if not x or x <= 1 then return false end
    return room:askToSkillInvoke(player, s_jianghuo.name, "#s_jianghuo-slash:::"..(x - 1))
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = room:getTag("s_jianghuo_x_"..target.id) or 0
    local hurt = room:getTag("s_jianghuo_hurt_"..target.id) or 0
    room:setTag("s_jianghuo_target_"..target.id, nil)
    room:setTag("s_jianghuo_x_"..target.id, nil)
    room:setTag("s_jianghuo_hurt_"..target.id, nil)
    if hurt > 0 or target.dead then return end
    for _ = 1, x - 1 do
      if player.dead or target.dead then break end
      local slash = Fk:cloneCard("slash")
      room:useCard{ from = player, tos = { target }, card = slash, extraUse = true }
    end
  end,
})

-- 测试1：他人出牌阶段开始弃牌，其手牌目标强制为你；阶段结束未受伤则对其使用X-1张杀
s_jianghuo:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_jianghuo.name)
    me.maxHp = 5
    me.hp = 3
    comp2.maxHp = 4
    comp2.hp = 4
    room.current = comp2
    comp2.phase = Player.Play
    local d1 = room:printCard("slash", Card.Spade, 3)
    local d2 = room:printCard("peach", Card.Heart, 4)
    room:obtainCard(me, { d1, d2 }, true, fk.ReasonDraw, me, "test")
    local s1 = room:printCard("slash", Card.Club, 5)
    room:obtainCard(comp2, { s1 }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    -- me 弃2张 → X=2 → comp2 使用杀目标强制为 me → 阶段结束 me 未受伤 → me 对其使用1张杀
    FkTest.setNextReplies(me, { "1", FkTest.ReplyDiscard(me:getCardIds("h")) })
    room.logic:trigger(fk.EventPhaseStart, comp2, {})
    lu.assertEquals(room:getTag("s_jianghuo_target_"..comp2.id), 2, "疆祸：应记录X=2")
    -- comp2 使用手牌杀（目标选 comp3？—— 只有 me/comp2 存活 → 目标强制 me）
    local slashId = comp2:getCardIds("h")[1]
    FkTest.setNextReplies(me, { "0" })
    room:useCard{ from = comp2, tos = { me }, card = Fk:getCardById(slashId) }
    -- 目标强制为 me：me 不出闪 → me 受1伤害 → 阶段结束（受伤害）不触发杀
    lu.assertEquals(me.hp, 2, "疆祸：comp2 的杀应指定 me 造成1点伤害")
    -- 阶段结束：受伤害 → 不触发 X-1 杀
    room.logic:trigger(fk.EventPhaseEnd, comp2, { phase = Player.Play })
    lu.assertEquals(comp2.hp, 4, "疆祸：受伤害后不应触发追加杀")
  end)
end)

-- 测试2：未受伤时阶段结束，对其使用X-1张杀
s_jianghuo:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_jianghuo.name)
    me.maxHp = 5
    me.hp = 3
    comp2.maxHp = 4
    comp2.hp = 4
    room.current = comp2
    comp2.phase = Player.Play
    local d1 = room:printCard("slash", Card.Spade, 3)
    local d2 = room:printCard("peach", Card.Heart, 4)
    room:obtainCard(me, { d1, d2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1", FkTest.ReplyDiscard(me:getCardIds("h")) })
    room.logic:trigger(fk.EventPhaseStart, comp2, {})
    -- 阶段结束（未受伤）→ 触发：me 对其使用 X-1=1 张杀
    FkTest.setNextReplies(me, { "1" })
    FkTest.setNextReplies(comp2, { "0" })
    room.logic:trigger(fk.EventPhaseEnd, comp2, { phase = Player.Play })
    lu.assertEquals(comp2.hp, 3, "疆祸：未受伤应对其使用X-1张杀（1点伤害）")
  end)
end)

return s_jianghuo