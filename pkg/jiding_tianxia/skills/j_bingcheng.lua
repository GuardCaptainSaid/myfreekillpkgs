-- 计娄圭·冰城（锁定技）
-- 当你受到伤害时，你回复等量体力；当你累计受到一点火焰伤害、一点雷属性伤害、一点无属性伤害后，此技能失效。
local j_bingcheng = fk.CreateSkill {
  name = "j_bingcheng",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_bingcheng"] = "冰城",
  [":j_bingcheng"] = "锁定技，当你受到伤害时，你回复等量体力；当你累计受到一点火焰伤害、一点雷属性伤害、一点无属性伤害后，此技能失效。",

  ["@@j_bingcheng_invalid"] = "冰城失效",
}

local TYPE_MARK = {
  [fk.FireDamage] = "j_bingcheng_fire",
  [fk.ThunderDamage] = "j_bingcheng_thunder",
  [fk.NormalDamage] = "j_bingcheng_normal",
}

j_bingcheng:addEffect(fk.Damaged, {
  anim_type = "defensive",
  -- 锁定技，自动执行
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_bingcheng.name) or player.dead then return false end
    if player:getMark("j_bingcheng_invalid") > 0 then return false end
    return (data.damage or 0) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local dmg = data.damage
    local dtype = data.damageType or fk.NormalDamage

    -- ① 回复等量体力
    room:recover{
      who = player,
      num = dmg,
      recoverBy = player,
      skillName = j_bingcheng.name,
    }

    -- ② 累计各属性受到的伤害
    local mark = TYPE_MARK[dtype]
    if mark then
      room:setPlayerMark(player, mark, player:getMark(mark) + dmg)
    end

    -- ③ 火、雷、无属性各累计 ≥1 → 此技能失效
    if player:getMark("j_bingcheng_fire") >= 1
      and player:getMark("j_bingcheng_thunder") >= 1
      and player:getMark("j_bingcheng_normal") >= 1 then
      room:setPlayerMark(player, "j_bingcheng_invalid", 1)
      room:setPlayerMark(player, "@@j_bingcheng_invalid", 1)
    end
  end,
})

-- 测试：受到1点伤害回复1点；累计三种属性后失效
j_bingcheng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_bingcheng.name)
    me.maxHp = 4
    me.hp = 2
  end)
  FkTest.runInRoom(function()
    -- 普通伤害：回复等量 → 体力不变
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me.hp, 2, "冰城：受到1点普通伤害应回复1点，体力不变")
    lu.assertEquals(me:getMark("j_bingcheng_normal"), 1, "应累计1点无属性伤害")
    lu.assertEquals(me:getMark("j_bingcheng_invalid"), 0, "尚未集齐三种属性")

    -- 火焰伤害
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.FireDamage }
    lu.assertEquals(me:getMark("j_bingcheng_fire"), 1, "应累计1点火焰伤害")

    -- 雷属性伤害 → 三类齐全，技能失效
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.ThunderDamage }
    lu.assertEquals(me:getMark("j_bingcheng_invalid"), 1, "集齐三种属性后冰城应失效")

    -- 失效后不再回复
    local hp = me.hp
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me.hp, hp - 1, "冰城失效后受到伤害不再回复")
  end)
end)

return j_bingcheng
