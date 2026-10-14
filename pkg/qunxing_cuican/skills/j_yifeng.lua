local j_yifeng = fk.CreateSkill {
  name = "j_yifeng",
}

Fk:loadTranslationTable{
  ["j_yifeng"] = "遗风",
  [":j_yifeng"] = "每个势力限一次，一名角色进入濒死状态时，你可以从三名与其同势力角色的技能中选择一个技能替换一个已有技能。",

  ["#j_yifeng-choose"] = "遗风：选择一名与其同势力的角色",
  ["#j_yifeng-pick"] = "遗风：选择要获得的技能",
  ["#j_yifeng-replace"] = "遗风：选择要替换的已有技能",
}

-- 一名角色进入濒死状态时，从同势力角色技能中选一个替换已有技能（每个势力限一次）
j_yifeng:addEffect(fk.EnterDying, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_yifeng.name) then return false end
    local dying = data.who
    if not dying then return false end
    if not dying.kingdom then return false end
    local used = player:getTableMark("j_yifeng_kingdoms")
    if table.contains(used, dying.kingdom) then return false end
    local candidates = table.filter(player.room.alive_players, function(p)
      return p ~= player and p.kingdom == dying.kingdom and p:isAlive()
    end)
    return #candidates > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_yifeng.name })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local dying = data.who
    local kingdom = dying.kingdom

    -- 候选：与该角色同势力且非自己的角色（至多三名）
    local candidates = table.filter(room.alive_players, function(p)
      return p ~= player and p.kingdom == kingdom and p:isAlive()
    end)
    if #candidates > 3 then
      candidates = { candidates[1], candidates[2], candidates[3] }
    end
    if #candidates == 0 then return end

    local chosen = room:askToChoosePlayers(player, {
      targets = candidates,
      min_num = 1,
      max_num = 1,
      skill_name = j_yifeng.name,
      prompt = "#j_yifeng-choose",
      cancelable = false,
    })
    local src = chosen[1]

    -- 选择其一个技能（该角色当前拥有的主技能）
    local pool = src:getSkillNameList()
    if #pool == 0 then return end
    local picked = room:askToChoice(player, {
      choices = pool,
      skill_name = j_yifeng.name,
      prompt = "#j_yifeng-pick",
      cancelable = false,
    })
    if not picked then return end

    -- 选择要替换的已有技能（不能替换遗风自身）
    local own_pool = table.filter(player:getSkillNameList(), function(s)
      return s ~= j_yifeng.name and s ~= picked
    end)
    if #own_pool == 0 then return end
    local old = room:askToChoice(player, {
      choices = own_pool,
      skill_name = j_yifeng.name,
      prompt = "#j_yifeng-replace",
      cancelable = false,
    })
    if not old or old == picked then return end

    -- 替换技能（移除主技能时不传 source_skill，否则会走 derivative 分支移不掉）
    room:handleAddLoseSkills(player, "-" .. old)
    room:handleAddLoseSkills(player, picked, j_yifeng.name)

    -- 记录该势力已使用
    local used = player:getTableMark("j_yifeng_kingdoms")
    table.insert(used, kingdom)
    room:setPlayerMark(player, "j_yifeng_kingdoms", used)
  end,
})

-- 测试：濒死时从同势力角色处选择一个技能替换已有技能，并记录势力
j_yifeng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "j_jiedao|j_xiandao|j_yifeng")
  end)

  FkTest.runInRoom(function()
    -- comp2 为魏势力，拥有两个技能（奸雄+集智），保证"选技能"询问正常发出
    room:changeKingdom(comp2, "wei", false)
    room:handleAddLoseSkills(comp2, "jianxiong|jizhi")

    -- me 有借刀可替换
    FkTest.setNextReplies(me, {
      "1",                                       -- 遗风询问
      FkTest.ReplyChoosePlayer({ comp2 }),       -- 选择 comp2
      { "jianxiong" },                           -- 选择要获得的技能
      { "j_jiedao" },                            -- 选择要替换的技能（借刀）
      "",
    })

    -- 触发 EnterDying 事件（濒死角色 comp2），遗风应被驱动发动
    room.logic:trigger(fk.EnterDying, comp2, { who = comp2 })

    -- 濒死触发后：借刀被替换为奸雄
    lu.assertFalse(me:hasSkill("j_jiedao"), "遗风：借刀应被替换移除")
    lu.assertIsTrue(me:hasSkill("jianxiong"), "遗风：应获得所选技能奸雄")
    local used = me:getTableMark("j_yifeng_kingdoms")
    lu.assertIsTrue(table.contains(used, "wei"), "遗风：应记录魏势力已使用")
  end)
end)

-- 测试：同一势力第二次濒死不触发（每势力限一次）
j_yifeng:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "j_jiedao|j_xiandao|j_yifeng")
  end)

  FkTest.runInRoom(function()
    room:changeKingdom(comp2, "wei", false)
    room:changeKingdom(comp3, "wei", false)
    room:handleAddLoseSkills(comp2, "jianxiong")
    room:handleAddLoseSkills(comp3, "jizhi")
    -- 标记魏势力已使用
    room:setPlayerMark(me, "j_yifeng_kingdoms", { "wei" })

    -- 再次濒死（comp3 为魏），不应触发
    local sk = Fk.skills[j_yifeng.name]:getSkeleton()
    local eff
    for _, spec in ipairs(sk.effect_spec_list) do
      if spec[1] == fk.EnterDying then eff = spec[3] break end
    end
    local ok = eff:can_trigger({ room = room }, comp3, me, { who = comp3 })
    lu.assertFalse(ok, "遗风：同一势力第二次濒死不应触发")
  end)
end)

return j_yifeng