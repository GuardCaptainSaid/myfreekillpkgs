-- 狂骨（计杨修【显忌】授予的副本技能，避免跨包依赖）
--
-- ！！必须单独占一个文件！！
-- 引擎的技能加载器只注册「文件 return 的那个 skeleton」；同一文件里的第二个
-- fk.CreateSkill 不会进入 Fk.skills，handleAddLoseSkills("j_kuanggu") 会静默失败。
local j_kuanggu = fk.CreateSkill {
  name = "j_kuanggu",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_kuanggu"] = "狂骨",
  [":j_kuanggu"] = "锁定技，当你对距离1以内的一名角色造成伤害后，你回复等量体力。",
}

-- 锁定技：你对距离1以内的角色造成伤害后回复等量体力
j_kuanggu:addEffect(fk.Damage, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_kuanggu.name) and not player.dead
      and data.to ~= player and data.to ~= nil and player:isWounded()
      and player:distanceTo(data.to) <= 1
  end,
  trigger_times = function(self, event, target, player, data)
    return data.damage
  end,
  on_use = function(self, event, target, player, data)
    player.room:recover{
      who = player,
      num = 1,
      recoverBy = player,
      skillName = j_kuanggu.name,
    }
  end,
})

-- 测试：对距离1以内角色造成伤害后回复等量体力
j_kuanggu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_kuanggu.name)
    room:loseHp(me, 2)
  end)
  FkTest.runInRoom(function()
    lu.assertTrue(me:hasSkill("j_kuanggu"), "狂骨应能授予")
    local before = me.hp
    room:damage{ from = me, to = room.players[2], damage = 1 }
    lu.assertEquals(me.hp, before + 1, "对距离1以内角色造成伤害应回复1点体力")
  end)
end)

return j_kuanggu
