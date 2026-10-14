local j_juexiang = fk.CreateSkill {
  name = "j_juexiang",
}

Fk:loadTranslationTable{
  ["j_juexiang"] = "绝响",
  [":j_juexiang"] = "当你死亡后，你可以令一名角色随机获得“和弦”、“柔弦”、“烈弦”和“激弦”其中一个技能。然后直到其下回合开始，其不能成为其他角色使用梅花牌的目标。",

  ["#j_juexiang-target"] = "绝响：选择一名角色随机获得四弦之一",

  ["$j_juexiang1"] = "广陵一曲终成绝响。",
  ["$j_juexiang2"] = "弦断琴亡，余音犹在。",
}

-- 死亡后：令一名角色随机获得四弦之一
j_juexiang:addEffect(fk.Death, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if data.who ~= player then return false end
    return player:hasSkill(j_juexiang.name)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = room:askToChoosePlayers(player, {
      targets = room.alive_players,
      min_num = 1,
      max_num = 1,
      skill_name = j_juexiang.name,
      prompt = "#j_juexiang-target",
    })
    if #targets == 0 then return false end
    self.target = targets[1]
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local t = self.target
    self.target = nil
    if t == nil or t.dead then return end
    local pool = { "j_hexian", "j_rouxian", "j_liexian", "j_jixian" }
    local sk = pool[room:random(1, #pool)]
    room:handleAddLoseSkills(t, { sk })
    room:setPlayerMark(t, "j_juexiang_club", 1)
  end,
})

j_juexiang:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_juexiang.name,
  think = function(self, player)
    return false
  end,
})

-- 测试：死亡后指定角色获得四弦之一并挂梅花免疫标记
j_juexiang:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_juexiang.name)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { FkTest.ReplyChoosePlayer({ comp2 }) })
    local death = DeathData:new{ who = me, killer = comp2 }
    room.logic:trigger(fk.Death, me, death)

    local gained = { me:hasSkill("j_hexian"), me:hasSkill("j_rouxian"), me:hasSkill("j_liexian"), me:hasSkill("j_jixian") }
    local compGained = { comp2:hasSkill("j_hexian"), comp2:hasSkill("j_rouxian"), comp2:hasSkill("j_liexian"), comp2:hasSkill("j_jixian") }
    local meCount = 0
    for _, v in ipairs(gained) do if v then meCount = meCount + 1 end end
    local compCount = 0
    for _, v in ipairs(compGained) do if v then compCount = compCount + 1 end end
    lu.assertEquals(compCount, 1, "绝响：目标应获得四弦之一")
    lu.assertEquals(meCount, 0, "绝响：授予者自身不应获得四弦")
    lu.assertEquals(comp2:getMark("j_juexiang_club"), 1, "绝响：目标应有梅花免疫标记")
  end)
end)

return j_juexiang