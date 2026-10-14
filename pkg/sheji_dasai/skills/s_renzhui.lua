-- 舒邵三号·刃锥
-- 游戏开始时，你选择一名其他角色，其进入濒死时你摸1张牌；其阵亡时你摸体力值张牌，
-- 你对杀死其的角色使用牌不受距离和次数限制且无法被响应。
local s_renzhui = fk.CreateSkill {
  name = "s_renzhui",
}

Fk:loadTranslationTable{
  ["s_renzhui"] = "刃锥",
  [":s_renzhui"] = "游戏开始时，你选择一名其他角色，其进入濒死时你摸1张牌；其阵亡时你摸体力值张牌，你对杀死其的角色使用牌不受距离和次数限制且无法被响应。",

  ["#s_renzhui-target"] = "刃锥：选择一名其他角色",
  ["#s_renzhui-dying_log"] = "刃锥：%arg 进入濒死，摸1张牌",
  ["#s_renzhui-death_log"] = "刃锥：%arg 阵亡，摸 %arg2 张牌",

  ["$s_renzhui1"] = "锥刃所向，誓护其命！",
  ["$s_renzhui2"] = "亡者之仇，刃锥相报！",
}

-- 游戏开始时选择一名其他角色
s_renzhui:addEffect(fk.GameStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(s_renzhui.name) then return false end
    if player.dead then return false end
    return #player.room:getOtherPlayers(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local others = room:getOtherPlayers(player)
    if #others == 0 then return false end
    local t = room:askToChoosePlayers(player, {
      targets = others,
      min_num = 1,
      max_num = 1,
      skill_name = s_renzhui.name,
      prompt = "#s_renzhui-target",
    })
    if t and #t > 0 then
      event:setCostData(self, { to = t[1] })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local to = event:getCostData(self).to
    if to then
      player.room:setPlayerMark(player, "@s_renzhui_target", to.id)
    end
  end,
})

-- 目标进入濒死时：摸1张牌
s_renzhui:addEffect(fk.EnterDying, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_renzhui.name) then return false end
    if not data or not data.who then return false end
    return player:getMark("@s_renzhui_target") == data.who.id
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:sendLog{ type = "#s_renzhui-dying_log", from = player.id, arg = data.who.id }
    player:drawCards(1, s_renzhui.name)
  end,
})

-- 目标阵亡时：摸体力值张牌，对杀死其的角色使用牌无距离次数限制且无法被响应
s_renzhui:addEffect(fk.Death, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_renzhui.name) then return false end
    if not data or not data.who then return false end
    return player:getMark("@s_renzhui_target") == data.who.id
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local killer = data.killer
    if killer and not killer.dead then
      room:setPlayerMark(killer, "@s_renzhui_killer", 1)
    end
    local n = math.max(player.hp, 0)
    room:sendLog{ type = "#s_renzhui-death_log", from = player.id, arg = data.who.id, arg2 = n }
    player:drawCards(n, s_renzhui.name)
  end,
})

-- 对杀死其的角色使用牌：无距离、无次数限制（客户端判定，mark 同步）
s_renzhui:addEffect("targetmod", {
  bypass_distances = function(self, player, card, to)
    return to and to:getMark("@s_renzhui_killer") > 0
  end,
  bypass_times = function(self, player, card_skill, scope, card, to)
    return to and to:getMark("@s_renzhui_killer") > 0
  end,
})

-- 对杀死其的角色使用牌：无法被响应（该角色不能打出【闪】/【无懈可击】）
s_renzhui:addEffect("prohibit", {
  prohibit_response = function(self, player, card)
    if player:getMark("@s_renzhui_killer") == 0 then return false end
    return card.trueName == "jink" or card.trueName == "nullification"
  end,
})

-- 测试：游戏开始选择目标 → 目标濒死摸1、阵亡摸体力值张并标记凶手
s_renzhui:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_renzhui.name)
  end)
  FkTest.runInRoom(function()
    -- GameStart 选目标（AskForUseActiveSkill 格式）
    FkTest.setNextReplies(me, { { card = { subcards = {} }, targets = { comp2.id } } })
    room.logic:trigger(fk.GameStart, me, { from = nil, to = me })
    lu.assertEquals(me:getMark("@s_renzhui_target"), comp2.id, "刃锥：应记录目标")
  end)
end)

-- 测试：目标进入濒死 → 舒邵摸1；目标阵亡 → 摸体力值张，凶手被标记
s_renzhui:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_renzhui.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 1
    room:setPlayerMark(me, "@s_renzhui_target", comp2.id)
  end)
  FkTest.runInRoom(function()
    -- 濒死
    local dying = DyingData:new{ who = comp2 }
    room.logic:trigger(fk.EnterDying, comp2, dying)
    lu.assertEquals(me:getMark("@s_renzhui_target"), comp2.id, "刃锥：目标标记仍在")
    -- 死亡
    room:setPlayerMark(me, "@s_renzhui_target", comp2.id)
    local death = DeathData:new{ who = comp2, killer = comp3 }
    room.logic:trigger(fk.Death, comp2, death)
    lu.assertEquals(comp3:getMark("@s_renzhui_killer"), 1, "刃锥：凶手应被标记")
    -- 凶手被禁响应（出不了闪/无懈）
    lu.assertTrue(comp3:prohibitResponse(Fk:cloneCard("jink")), "刃锥：凶手不能出闪")
    lu.assertTrue(comp3:prohibitResponse(Fk:cloneCard("nullification")), "刃锥：凶手不能出无懈")
    lu.assertFalse(comp3:prohibitResponse(Fk:cloneCard("slash")), "刃锥：凶手仍可出杀")
  end)
end)

return s_renzhui