-- 轲比能二号·慕汉（限定技）
-- 限定技，你可以选择一个武将，随机获得其一个武将技能。然后你失去技能"寇边"。
local s_muhan = fk.CreateSkill {
  name = "s_muhan",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["s_muhan"] = "慕汉",
  [":s_muhan"] = "限定技，你可以选择一个武将，随机获得其一个武将技能。然后你失去技能“寇边”。",

  ["#s_muhan"] = "慕汉：选择一名角色，随机获得其一个武将技能",
}

s_muhan:addEffect("active", {
  anim_type = "control",
  prompt = "#s_muhan",
  max_phase_use_time = 1,
  target_num = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player and not to_select.dead
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    -- 随机获得目标一个武将技能（排除 # 派生技与已拥有技能）
    local candidates = {}
    for _, sname in ipairs(target:getSkillNameList()) do
      if not sname:startsWith("#") and not player:hasSkill(sname) then
        table.insert(candidates, sname)
      end
    end
    if #candidates > 0 then
      local sname = table.randomPick(candidates)
      room:handleAddLoseSkills(player, sname, nil, false, true)
    end
    -- 然后失去寇边
    room:handleAddLoseSkills(player, "-s_koubian2", nil, false, true)
  end,
})

-- 测试1：随机获得目标一个武将技能并失去寇边
s_muhan:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_koubian2.name)
    room:handleAddLoseSkills(comp2, "qiangxi")
  end)
  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    s_muhan:onUse(room, { from = me, tos = { comp2 }, cards = {}, cost_data = {} })
    lu.assertTrue(me:hasSkill("qiangxi"), "慕汉：应随机获得目标一个武将技能")
    lu.assertFalse(me:hasSkill("s_koubian2"), "慕汉：使用后应失去寇边")
  end)
end)

-- 测试2：目标无技能时仅失去寇边，不报错
s_muhan:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_koubian2.name)
  end)
  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    s_muhan:onUse(room, { from = me, tos = { comp2 }, cards = {}, cost_data = {} })
    lu.assertFalse(me:hasSkill("s_koubian2"), "慕汉：目标无技能时仍应失去寇边")
  end)
end)

return s_muhan