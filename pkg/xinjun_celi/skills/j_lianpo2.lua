-- 连破（君孙权建业临时技能，标准连破效果）
-- 当你杀死一名角色后，你可以于此回合结束后获得一个额外回合。
local j_lianpo2 = fk.CreateSkill {
  name = "j_lianpo2",
}

Fk:loadTranslationTable{
  ["j_lianpo2"] = "连破",
  [":j_lianpo2"] = "当你杀死一名角色后，你可以于此回合结束后获得一个额外回合。",

  ["#j_lianpo2-invoke"] = "连破：是否于此回合结束后获得一个额外回合？",

  ["$j_lianpo2_1"] = "乘胜追击，再破敌军！",
}

j_lianpo2:addEffect(fk.Death, {
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_lianpo2.name) or player.dead then return false end
    if not target or not target.dead then return false end
    if not data.killer or data.killer ~= player then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_lianpo2.name, prompt = "#j_lianpo2-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_lianpo2_pending-turn", 1)
  end,
})

j_lianpo2:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    return player:getMark("j_lianpo2_pending-turn") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_lianpo2_pending-turn", 0)
    player:gainAnExtraTurn(false, j_lianpo2.name)
  end,
})

-- 测试：杀死角色后获得额外回合
j_lianpo2:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lianpo2.name)
    me.maxHp = 4
    me.hp = 4
    comp3.hp = 1
    comp3.maxHp = 1
    -- 让 comp3 濒死死亡：直接 killPlayer（killer=me）
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room:killPlayer{ who = comp3, killer = me }
    lu.assertEquals(me:getMark("j_lianpo2_pending-turn"), 1, "连破：杀死角色后应记录待额外回合")
    -- 触发自己回合结束
    room.logic:trigger(fk.TurnEnd, me, {})
    lu.assertEquals(me:getMark("j_lianpo2_pending-turn"), 0, "连破：额外回合触发后应清除标记")
  end)
end)

return j_lianpo2