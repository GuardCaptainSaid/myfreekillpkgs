local j_jizhi2 = fk.CreateSkill({
  name = "j_jizhi2",
  tags = { Skill.Compulsory },
})

Fk:loadTranslationTable{
  ["j_jizhi2"] = "继志",
  [":j_jizhi2"] = "锁定技，每轮开始时，你从“观星”、“空城”、“火计”、“看破”、“八阵”、“藏拙”、“祭风”中随机获得两个技能直到下一轮开始。",

  ["$j_jizhi21"] = "丞相遗志，我当继承！",
  ["$j_jizhi22"] = "继丞相之遗志，讨篡汉之逆贼！",
}

local SKILL_POOL = { "guanxing", "kongcheng", "huoji", "kanpo", "bazhen", "j_cangzhuo", "j_jifeng" }

local function get_random_skills(count)
  local pool = {}
  for _, skill in ipairs(SKILL_POOL) do
    table.insert(pool, skill)
  end
  local result = {}
  for i = 1, count do
    if #pool == 0 then break end
    local idx = math.random(1, #pool)
    table.insert(result, pool[idx])
    table.remove(pool, idx)
  end
  return result
end

j_jizhi2:addEffect(fk.RoundStart, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jizhi2.name) then return false end
    local round = player.room:getBanner("RoundCount") or 0
    return player:getMark("j_jizhi2_round") ~= round
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room

    local old_skills = player:getTableMark("j_jizhi2_skills")
    if #old_skills > 0 then
      for _, skill_name in ipairs(old_skills) do
        if player:hasSkill(skill_name, true, true) then
          room:handleAddLoseSkills(player, "-" .. skill_name, nil, false, true)
        end
      end
      room:setPlayerMark(player, "j_jizhi2_skills", {})
    end

    local new_skills = get_random_skills(2)
    if #new_skills > 0 then
      for _, skill_name in ipairs(new_skills) do
        local sk = Fk.skills[skill_name]
        if sk and not player:hasSkill(sk, true, true) then
          room:handleAddLoseSkills(player, skill_name, nil, false, true)
        end
      end
      room:setPlayerMark(player, "j_jizhi2_skills", new_skills)
    end
    room:setPlayerMark(player, "j_jizhi2_round", room:getBanner("RoundCount") or 0)
  end,
})

-- 测试：每轮开始时获得两个随机技能，下一轮开始时替换
j_jizhi2:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jizhi2.name)
  end)

  FkTest.runInRoom(function()
    -- mock 随机：第1轮固定取 pool[1]、pool[1]（guanxing、kongcheng），
    -- 第2轮固定取 pool[3]、pool[3]（huoji、kanpo），保证测试确定性
    local orig_random = math.random
    local calls = 0
    math.random = function(a, b)
      calls = calls + 1
      if calls <= 2 then return 1 end
      return 3
    end

    -- 模拟第 1 轮开始（引擎在 RoundStart 前先递增 RoundCount）
    room:setBanner("RoundCount", (room:getBanner("RoundCount") or 0) + 1)
    room.logic:trigger(fk.RoundStart, room.current, {
      from = room.current, to = room.current, turn_table = room.players,
    })

    -- 应获得 2 个技能：guanxing 与 kongcheng
    local marks = me:getTableMark("j_jizhi2_skills")
    lu.assertEquals(#marks, 2, "继志：每轮开始应获得两个技能")
    lu.assertIsTrue(table.contains(marks, "guanxing"), "继志：应获得观星")
    lu.assertIsTrue(table.contains(marks, "kongcheng"), "继志：应获得空城")
    for _, s in ipairs(marks) do
      lu.assertIsTrue(me:hasSkill(s, true, true), "继志：应拥有技能 " .. s)
    end
    -- 记录本轮已触发
    lu.assertEquals(me:getMark("j_jizhi2_round"), room:getBanner("RoundCount"), "继志：应记录轮次")

    -- 模拟第 2 轮开始：旧技能被移除并替换为新技能（huoji、kanpo）
    local old = table.simpleClone(marks)
    room:setBanner("RoundCount", (room:getBanner("RoundCount") or 0) + 1)
    room.logic:trigger(fk.RoundStart, room.current, {
      from = room.current, to = room.current, turn_table = room.players,
    })
    local new_marks = me:getTableMark("j_jizhi2_skills")
    lu.assertEquals(#new_marks, 2, "继志：下一轮应重新获得两个技能")
    lu.assertIsTrue(table.contains(new_marks, "huoji"), "继志：应获得火计")
    lu.assertIsTrue(table.contains(new_marks, "kanpo"), "继志：应获得看破")
    for _, s in ipairs(old) do
      lu.assertFalse(me:hasSkill(s, true, true), "继志：上一轮技能应被移除")
    end

    math.random = orig_random
  end)
end)

-- 测试：同一轮内不重复触发（每轮限一次）
j_jizhi2:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jizhi2.name)
  end)

  FkTest.runInRoom(function()
    -- 标记本轮已触发
    local round = room:getBanner("RoundCount") or 0
    room:setPlayerMark(me, "j_jizhi2_round", round)
    local sk = Fk.skills[j_jizhi2.name]:getSkeleton()
    local eff
    for _, spec in ipairs(sk.effect_spec_list) do
      if spec[1] == fk.RoundStart then eff = spec[3] break end
    end
    lu.assertNotIsNil(eff, "继志：应监听 RoundStart 事件")
    local ok = eff:can_trigger({ room = room }, room.current, me, {
      from = room.current, to = room.current, turn_table = room.players,
    })
    lu.assertFalse(ok, "继志：同一轮不应重复触发")
  end)
end)

return j_jizhi2