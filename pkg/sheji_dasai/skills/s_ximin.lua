-- 鲍三娘一号·恤民
-- 当场上两名及以上角色处于体力值≤2的状态时可发动：你移除所有「蛮」「疆」标记，令全场体力最低的两名角色回复1体力，然后你失去本回合全部出杀机会，每移除一枚标记，你摸一张牌。
local s_ximin = fk.CreateSkill {
  name = "s_ximin",
}

Fk:loadTranslationTable{
  ["s_ximin"] = "恤民",
  [":s_ximin"] = "当场上两名及以上角色处于体力值≤2的状态时可发动：你移除所有「蛮」「疆」标记，令全场体力最低的两名角色回复1体力，然后你失去本回合全部出杀机会，每移除一枚标记，你摸一张牌。",

  ["#s_ximin"] = "恤民：移除所有蛮疆标记，令体力最低的两名角色回复1体力",
  ["@@s_ximin_block"] = "恤民禁杀",
}

s_ximin:addEffect("active", {
  anim_type = "support",
  prompt = "#s_ximin",
  max_phase_use_time = 1,
  target_num = 0,
  on_use = function(self, room, effect)
    local player = effect.from
    -- 条件：场上两名及以上角色体力≤2
    local count = 0
    for _, p in ipairs(room.alive_players) do
      if p.hp <= 2 then count = count + 1 end
    end
    if count < 2 then return end
    -- 移除所有蛮疆标记
    local jiang = player:getMark("@s_wujiang_jiang")
    local man = player:getMark("@s_wujiang_man")
    room:setPlayerMark(player, "@s_wujiang_jiang", 0)
    room:setPlayerMark(player, "@s_wujiang_man", 0)
    -- 全场体力最低的两名角色回复1体力
    local lowest = {}
    for _, p in ipairs(room.alive_players) do
      if not p.dead then table.insert(lowest, p) end
    end
    table.sort(lowest, function(a, b) return a.hp < b.hp end)
    local healed = 0
    for i = 1, 2 do
      local p = lowest[i]
      if p and not p.dead and p.hp < p.maxHp then
        room:recover{ who = p, num = 1, recoverBy = player, skillName = s_ximin.name }
        healed = healed + 1
        if healed >= 2 then break end
      end
    end
    -- 失去本回合全部出杀机会
    room:setPlayerMark(player, "@@s_ximin_block", 1)
    -- 每移除一枚标记摸一张牌
    player:drawCards(jiang + man, s_ximin.name)
  end,
})

-- 禁杀：本回合杀次数归零
s_ximin:addEffect("targetmod", {
  residue_func = function(self, player, scope, card)
    if scope ~= Player.HistoryPhase then return 0 end
    if player:getMark("@@s_ximin_block") <= 0 then return 0 end
    if card and card.trueName ~= "slash" then return 0 end
    return -99
  end,
})

-- 下回合开始恢复出杀
s_ximin:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and data.to == Player.Start and player:getMark("@@s_ximin_block") > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@@s_ximin_block", 0)
  end,
})

-- 测试1：满足条件（含自己在内≥2名hp≤2）→ 移除标记、最低两名回1、禁杀、摸牌
s_ximin:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_ximin.name)
    me.maxHp = 4
    me.hp = 1
    comp2.maxHp = 4
    comp2.hp = 4
    comp3.maxHp = 4
    comp3.hp = 2
    room:setPlayerMark(me, "@s_wujiang_jiang", 2)
    room:setPlayerMark(me, "@s_wujiang_man", 1)
  end)
  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local before = #me:getCardIds("h")
    s_ximin:onUse(room, { from = me, tos = {}, cards = {}, cost_data = {} })
    lu.assertEquals(me:getMark("@s_wujiang_jiang"), 0, "恤民：疆应清零")
    lu.assertEquals(me:getMark("@s_wujiang_man"), 0, "恤民：蛮应清零")
    -- 全场最低两名（me hp1、comp3 hp2）各回1
    lu.assertEquals(me.hp, 2, "恤民：体力最低角色应回复1")
    lu.assertEquals(comp3.hp, 3, "恤民：第二名最低角色应回复1")
    lu.assertEquals(me:getMark("@@s_ximin_block"), 1, "恤民：应禁杀")
    lu.assertEquals(#me:getCardIds("h"), before + 3, "恤民：每移除一枚标记摸一张")
  end)
end)

-- 测试2：条件不满足（仅1名≤2）→ 无效果
s_ximin:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_ximin.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 1
    room:setPlayerMark(me, "@s_wujiang_jiang", 1)
  end)
  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    s_ximin:onUse(room, { from = me, tos = {}, cards = {}, cost_data = {} })
    lu.assertEquals(me:getMark("@s_wujiang_jiang"), 1, "恤民：条件不足不应移除标记")
    lu.assertEquals(comp2.hp, 1, "恤民：条件不足不应回复")
  end)
end)

return s_ximin