-- 君袁术·僭业（限定技）
-- 出牌阶段，你可以弃置所有"粮"，若本回合弃置的"粮"大于10，你令一名角色死亡；否则，你减2点体力上限并选择一名角色与其获得"饥馑"。
local j_jianye2 = fk.CreateSkill {
  name = "j_jianye2",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["j_jianye2"] = "僭业",
  [":j_jianye2"] = "限定技，出牌阶段，你可以弃置所有“粮”，若本回合弃置的“粮”大于10，你令一名角色死亡；否则，你减2点体力上限并选择一名角色与其获得“饥馑”。",

  ["#j_jianye2-target"] = "僭业：选择一名角色，令其死亡",
  ["#j_jianye2-jihui"] = "僭业：选择一名角色与其获得“饥馑”",
  ["@j_jianye2"] = "僭业",

  ["$j_jianye2_1"] = "吾既僭号，何妨代汉！",
  ["$j_jianye2_2"] = "仲氏之业，自此而始！",
}

j_jianye2:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    if player:getMark("@j_jianye2_used") > 0 then return false end
    if player.phase ~= Player.Play then return false end
    return player:getMark("@j_jiaochi_liang") > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    room:setPlayerMark(player, "@j_jianye2_used", 1)
    -- 弃置所有粮
    local n = player:getMark("@j_jiaochi_liang")
    j_jiaochi.loseLiang(room, player, n)
    -- 本回合弃置的粮累计
    local total = player:getMark("j_jianye2_discard-round")
    if total > 10 then
      -- 令一名角色死亡
      local targets = room:askToChoosePlayers(player, {
        targets = room.alive_players,
        min_num = 1,
        max_num = 1,
        cancelable = false,
        skill_name = j_jianye2.name,
        prompt = "#j_jianye2-target",
      })
      if #targets > 0 then
        room:killPlayer{ who = targets[1], killer = player, reason = j_jianye2.name }
      end
    else
      -- 减2点体力上限
      room:changeMaxHp(player, -2)
      -- 选择一名角色与其获得饥馑
      local sel = room:askToChoosePlayers(player, {
        targets = room.alive_players,
        min_num = 1,
        max_num = 1,
        cancelable = false,
        skill_name = j_jianye2.name,
        prompt = "#j_jianye2-jihui",
      })
      if #sel > 0 then
        room:handleAddLoseSkills(player, "j_jihui", nil, false, true)
        room:handleAddLoseSkills(sel[1], "j_jihui", nil, false, true)
      end
    end
  end,
})

-- 测试：本回合弃粮>10 → 令一名角色死亡
j_jianye2:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianye2.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "@j_jiaochi_liang", 6)
    room:setPlayerMark(me, "j_jianye2_discard-round", 5) -- 本回合已弃5枚
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    FkTest.setNextReplies(me, { { comp2.id } })
    room:useActiveSkill(me, j_jianye2.name, {}, {})
    lu.assertEquals(me:getMark("@j_jiaochi_liang"), 0, "僭业：应弃置所有粮")
    lu.assertTrue(comp2.dead, "僭业：本回合弃粮>10应令角色死亡")
  end)
end)

-- 测试：本回合弃粮≤10 → 减上限 + 双方获得饥馑
j_jianye2:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianye2.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "@j_jiaochi_liang", 2)
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local maxBefore = me.maxHp
    FkTest.setNextReplies(me, { { comp2.id } })
    room:useActiveSkill(me, j_jianye2.name, {}, {})
    lu.assertEquals(me.maxHp, maxBefore - 2, "僭业：应减2点体力上限")
    lu.assertTrue(me:hasSkill("j_jihui"), "僭业：袁术应获得饥馑")
    lu.assertTrue(comp2:hasSkill("j_jihui"), "僭业：所选角色应获得饥馑")
  end)
end)

return j_jianye2