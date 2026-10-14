-- 舒邵二号·散廪
-- 出牌阶段限一次，你可以将任意张牌交给一名其他角色，称为"廪"。拥有"廪"的角色回合结束时，须将等量牌交给你，否则受到1点伤害。若其因此受到伤害，你可令一名角色摸两张牌。
local s_sanlin = fk.CreateSkill {
  name = "s_sanlin",
}

Fk:loadTranslationTable{
  ["s_sanlin"] = "散廪",
  [":s_sanlin"] = "出牌阶段限一次，你可以将任意张牌交给一名其他角色，称为“廪”。拥有“廪”的角色回合结束时，须将等量牌交给你，否则受到1点伤害。若其因此受到伤害，你可令一名角色摸两张牌。",

  ["#s_sanlin-give"] = "散廪：选择任意张牌交给一名其他角色",
  ["#s_sanlin-target"] = "散廪：选择一名其他角色获得“廪”",
  ["#s_sanlin-return"] = "散廪：将等量牌交给舒邵（不给将受到1点伤害）",
  ["#s_sanlin-draw"] = "散廪：是否令一名角色摸两张牌？",
  ["#s_sanlin-draw-target"] = "散廪：选择一名角色摸两张牌",
  ["#s_sanlin_log"] = "散廪：%arg 获得 %arg2 枚“廪”",
  ["@s_sanlin_lin"] = "廪",
  ["@s_sanlin_used"] = "散廪",

  ["$s_sanlin1"] = "开廪散粮，以济困乏！",
  ["$s_sanlin2"] = "所散之廪，当有回报！",
}

-- 回合开始：重置本回合已用标记
s_sanlin:addEffect(fk.TurnStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    return player:hasSkill(s_sanlin.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@s_sanlin_used-turn", 0)
  end,
})

-- 主动技：将任意张牌交给一名其他角色，称为廪
s_sanlin:addEffect("active", {
  anim_type = "support",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    return player:getMark("@s_sanlin_used-turn") == 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player.dead then return end
    local hand = player:getCardIds("hej")
    if #hand == 0 then return end
    -- 选任意张牌
    local c = room:askToChooseCards(player, {
      target = player,
      flag = "hej",
      min = 1,
      max = #hand,
      cancelable = false,
      pattern = ".",
      skill_name = s_sanlin.name,
      prompt = "#s_sanlin-give",
    })
    if not c or #c == 0 then return end
    -- 选一名其他角色
    local tos = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player),
      min_num = 1,
      max_num = 1,
      cancelable = false,
      skill_name = s_sanlin.name,
      prompt = "#s_sanlin-target",
    })
    local target = tos[1]
    if not target then return end
    -- 交给目标，称为廪
    room:obtainCard(target, c, true, fk.ReasonGive, player, s_sanlin.name)
    room:setPlayerMark(player, "@s_sanlin_used-turn", 1)
    -- 增加廪计数
    local lin = target:getMark("@s_sanlin_lin") + #c
    room:setPlayerMark(target, "@s_sanlin_lin", lin)
    -- 提示廪数
    room:sendLog{ type = "#s_sanlin_log", from = player.id, to = { target.id }, arg = target.id, arg2 = lin }
  end,
})

-- 拥有廪的角色回合结束时：须将等量牌交给你，否则受1点伤害，受伤则可令一名角色摸2
s_sanlin:addEffect(fk.EventPhaseEnd, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    -- 只有技能持有者结算（避免全局触发时每个玩家都执行）
    if not player:hasSkill(s_sanlin.name) then return false end
    if player.dead then return false end
    -- 只有拥有廪的角色自己的回合结束阶段结算
    if data.to ~= Player.Finish then return false end
    local n = target:getMark("@s_sanlin_lin")
    if n <= 0 then return false end
    -- 寻找散廪者（技能持有者存活）
    for _, p in ipairs(target.room.alive_players) do
      if p:hasSkill(s_sanlin.name) then
        return not p.dead
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = target.room
    local n = target:getMark("@s_sanlin_lin")
    -- 寻找散廪者
    local owner = nil
    for _, p in ipairs(room.alive_players) do
      if p:hasSkill(s_sanlin.name) and not p.dead then
        owner = p
        break
      end
    end
    if not owner then return end
    -- 选等量牌交还（可取消=不给）
    local maxn = math.min(n, #target:getCardIds("h"))
    local returned = 0
    if maxn > 0 then
      local c = room:askToChooseCards(target, {
        target = target,
        flag = "h",
        min = 0,
        max = maxn,
        cancelable = true,
        pattern = ".",
        skill_name = s_sanlin.name,
        prompt = "#s_sanlin-return",
      })
      if c and #c > 0 then
        returned = #c
        room:obtainCard(owner, c, true, fk.ReasonGive, target, s_sanlin.name)
      end
    end
    -- 未还足等量 → 受到1点伤害
    if returned < n then
      room:damage{ from = nil, to = target, damage = 1, damageType = fk.NormalDamage, skillName = s_sanlin.name }
      -- 若其因此受到伤害，散廪者可令一名角色摸两张牌
      if not target.dead and owner and not owner.dead then
        if room:askToSkillInvoke(owner, { skill_name = s_sanlin.name, prompt = "#s_sanlin-draw" }) then
          local tos = room:askToChoosePlayers(owner, {
            targets = room.alive_players,
            min_num = 1,
            max_num = 1,
            cancelable = false,
            skill_name = s_sanlin.name,
            prompt = "#s_sanlin-draw-target",
          })
          if tos[1] and not tos[1].dead then
            tos[1]:drawCards(2, s_sanlin.name)
          end
        end
      end
    end
    -- 结算完毕，清除廪标记
    room:setPlayerMark(target, "@s_sanlin_lin", 0)
  end,
})

-- 测试：散廪给牌建廪；其回合结束还牌
s_sanlin:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_sanlin.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 3
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
    -- 注意：setNextReplies 每次调用会重建回复队列，所有回复须一次传入
    -- 回复1：选2张牌（askToChooseCards 纯数组）；回复2：选目标（AskForUseActiveSkill 格式）
    FkTest.setNextReplies(me, { { h[1], h[2] }, { card = { subcards = {} }, targets = { comp2.id } } })
    -- 找到主动技子技能并调用 onUse
    local active_sk
    for _, sk in ipairs(s_sanlin.effects) do
      if sk:isInstanceOf(ActiveSkill) then active_sk = sk break end
    end
    lu.assertNotNil(active_sk, "散廪：应存在主动技子技能")
    local eff = { from = me, tos = {}, cards = {} }
    active_sk:onUse(room, eff)
    lu.assertEquals(comp2:getMark("@s_sanlin_lin"), 2, "散廪：应建立2枚廪")
    lu.assertEquals(#comp2:getCardIds("h"), 2, "散廪：目标应获得2张牌")
    lu.assertEquals(me:getMark("@s_sanlin_used-turn"), 1, "散廪：应记录已用")
  end)
end)

-- 测试：回合结束还牌成功 → 无伤害
s_sanlin:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_sanlin.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 3
    room:setPlayerMark(comp2, "@s_sanlin_lin", 1)
    local h1 = room:printCard("slash", Card.Spade, 3)
    room:obtainCard(comp2, { h1 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = comp2
    comp2.phase = Player.Finish
    local h = comp2:getCardIds("h")
    FkTest.setNextReplies(comp2, { { h[1] } })
    room.logic:trigger(fk.EventPhaseEnd, comp2, { from = Player.Discard, to = Player.Finish })
    lu.assertEquals(comp2.hp, 3, "散廪：还足牌不应受伤")
    lu.assertEquals(#me:getCardIds("h"), 1, "散廪：应收回1张牌")
    lu.assertEquals(comp2:getMark("@s_sanlin_lin"), 0, "散廪：结算后应清除廪标记")
  end)
end)

-- 测试：回合结束不还牌 → 受1伤 → 可令一名角色摸2
s_sanlin:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_sanlin.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 3
    room:setPlayerMark(comp2, "@s_sanlin_lin", 1)
  end)

  FkTest.runInRoom(function()
    room.current = comp2
    comp2.phase = Player.Finish
    -- comp2 不还牌（取消）
    FkTest.setNextReplies(comp2, { {} })
    -- me 发动摸牌（"1"），并选择 me 自己摸2（AskForUseActiveSkill 格式）
    FkTest.setNextReplies(me, { "1", { card = { subcards = {} }, targets = { me.id } } })
    local handBefore = #me:getCardIds("h")
    room.logic:trigger(fk.EventPhaseEnd, comp2, { from = Player.Discard, to = Player.Finish })
    lu.assertEquals(comp2.hp, 2, "散廪：不还牌应受1点伤害")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 2, "散廪：应令一名角色摸2张")
    lu.assertEquals(comp2:getMark("@s_sanlin_lin"), 0, "散廪：结算后应清除廪标记")
  end)
end)

return s_sanlin