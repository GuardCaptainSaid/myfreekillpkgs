local j_jiesheng = fk.CreateSkill {
  name = "j_jiesheng",
}

Fk:loadTranslationTable{
  ["j_jiesheng"] = "洁生",
  [":j_jiesheng"] = "所有角色的回合各限一次，其他角色受到伤害时你可受到一点无来源伤害并防止其受到的伤害。每轮结束时，若你本轮未发动过此技能，则你恢复1点体力。",

  ["#j_jiesheng-invoke"] = "洁生：是否代其承受伤害？",

  ["$j_jiesheng1"] = "此间之痛，吾愿代受！",
  ["$j_jiesheng2"] = "宁负己身，不负君恩！",
}

j_jiesheng:addEffect(fk.DamageInflicted, {
  anim_type = "defensive",
  max_turn_use_time = 1,
  can_trigger = function(self, event, target, player, data)
    if target == player then return false end
    if not player:hasSkill(j_jiesheng.name) then return false end
    return target and target:isAlive() and data.damage >= 1
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_jiesheng.name, prompt = "#j_jiesheng-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 防止其受到的伤害
    data:preventDamage()
    -- 自己受到一点无来源伤害
    room:damage{
      to = player,
      damage = 1,
      damageType = fk.NormalDamage,
      skillName = j_jiesheng.name,
    }
    room:addPlayerMark(player, "j_jiesheng_round", 1)
  end,
})

-- 每轮结束：本轮未发动过则恢复 1 点体力
j_jiesheng:addEffect(fk.RoundEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_jiesheng.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player:getMark("j_jiesheng_round") == 0 then
      room:recover{ who = player, num = 1, recoverBy = player, skillName = j_jiesheng.name }
    end
    room:setPlayerMark(player, "j_jiesheng_round", 0)
  end,
})

return j_jiesheng
