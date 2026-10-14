-- 舒邵二号·争义
-- 锁定技，当你濒死时，你可以选择一名有"廪"标记的角色，令其代替你承受本次濒死伤害；若如此做，移除全部"廪"。每移除一张"廪"，你回复1点体力。
local s_zhengyi = fk.CreateSkill {
  name = "s_zhengyi",
}

Fk:loadTranslationTable{
  ["s_zhengyi"] = "争义",
  [":s_zhengyi"] = "锁定技，当你濒死时，你可以选择一名有“廪”标记的角色，令其代替你承受本次濒死伤害；若如此做，移除全部“廪”。每移除一张“廪”，你回复1点体力。",

  ["#s_zhengyi-target"] = "争义：选择一名有“廪”的角色代替你承受本次濒死伤害",

  ["$s_zhengyi1"] = "受人之恩，当以命相酬！",
  ["$s_zhengyi2"] = "义之所至，生死相托！",
}

-- 濒死时：转移濒死伤害给有廪角色
s_zhengyi:addEffect(fk.EnterDying, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(s_zhengyi.name) then return false end
    if player.dead then return false end
    -- 需由伤害致濒死且场上有廪角色
    if not data.damage then return false end
    for _, p in ipairs(player.room.alive_players) do
      if p ~= player and p:getMark("@s_sanlin_lin") > 0 then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    -- 锁定技：直接发动（无需询问）
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local candidates = {}
    for _, p in ipairs(room.alive_players) do
      if p ~= player and not p.dead and p:getMark("@s_sanlin_lin") > 0 then
        table.insert(candidates, p)
      end
    end
    if #candidates == 0 then return end
    local tos = room:askToChoosePlayers(player, {
      targets = candidates,
      min_num = 1,
      max_num = 1,
      cancelable = false,
      skill_name = s_zhengyi.name,
      prompt = "#s_zhengyi-target",
    })
    local target = tos[1]
    if not target then return end
    -- 移除全部廪
    local total = 0
    for _, p in ipairs(room.alive_players) do
      local n = p:getMark("@s_sanlin_lin")
      if n > 0 then
        room:setPlayerMark(p, "@s_sanlin_lin", 0)
        total = total + n
      end
    end
    -- 每移除一张廪，回复1点体力
    if total > 0 and not player.dead then
      room:recover{ who = player, num = total }
    end
    -- 令其代替你承受本次濒死伤害（对目标造成等量伤害）
    if not target.dead then
      local dmg = data.damage
      room:damage{ from = dmg.from, to = target, damage = dmg.damage, damageType = dmg.damageType, card = dmg.card, skillName = s_zhengyi.name }
    end
  end,
})

-- 测试：濒死时转移给有廪角色并移除全部廪回复
s_zhengyi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_zhengyi.name)
    me.maxHp = 3
    me.hp = 1
    comp2.maxHp = 3
    comp2.hp = 3
    room:setPlayerMark(comp2, "@s_sanlin_lin", 2)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { { card = { subcards = {} }, targets = { comp2.id } } })
    room:damage{ from = comp2, to = me, damage = 2, damageType = fk.NormalDamage }
    -- 回复2点：hp 1-2(濒死)+2 = 2
    lu.assertEquals(me.hp, 1, "争义：移除2张廪应回复2点体力（1-2+2=1）")
    lu.assertEquals(comp2:getMark("@s_sanlin_lin"), 0, "争义：应移除全部廪")
    lu.assertEquals(comp2.hp, 1, "争义：目标应代替承受2点伤害")
  end)
end)

-- 测试：多个角色有廪 → 全部移除
s_zhengyi:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_zhengyi.name)
    me.maxHp = 3
    me.hp = 1
    comp2.maxHp = 3
    comp2.hp = 3
    comp3.maxHp = 3
    comp3.hp = 3
    room:setPlayerMark(comp2, "@s_sanlin_lin", 1)
    room:setPlayerMark(comp3, "@s_sanlin_lin", 2)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { { card = { subcards = {} }, targets = { comp2.id } } })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    -- 移除3张廪 → 回复3点 → hp 1-1(濒死)+3 = 3
    lu.assertEquals(me.hp, 3, "争义：移除3张廪应回复3点体力")
    lu.assertEquals(comp2:getMark("@s_sanlin_lin"), 0, "争义：comp2的廪应移除")
    lu.assertEquals(comp3:getMark("@s_sanlin_lin"), 0, "争义：comp3的廪应移除")
    lu.assertEquals(comp2.hp, 2, "争义：目标应代替承受1点伤害")
  end)
end)

return s_zhengyi