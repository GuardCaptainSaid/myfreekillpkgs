local j_huitian = fk.CreateSkill {
  name = "j_huitian",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["j_huitian"] = "回天",
  [":j_huitian"] = "限定技，当你进入濒死状态时，你增加一点体力上限并回复两点体力，并令当前回合角色跳过剩余阶段结束回合。然后你获得“化薪”并立即执行一个额外回合，回合结束时，你失去因此获得的技能。",

  ["#j_huitian-invoke"] = "回天：是否发动？",

  ["$j_huitian1"] = "天不亡我！",
  ["$j_huitian2"] = "姜维在此，谁敢来战！",
}

j_huitian:addEffect(fk.AskForPeachesDone, {
  anim_type = "wake",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_huitian.name) and player.hp <= 0
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, { skill_name = j_huitian.name, prompt = "#j_huitian-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = event.room

    room:changeMaxHp(player, 1)
    room:recover({
      who = player,
      num = 2,
    })

    local current_player = room.current
    if current_player and current_player:isAlive() then
      room:setPlayerMark(current_player, "j_huitian_end-turn", 1)
    end

    room:handleAddLoseSkills(player, "j_huaxin", j_huitian.name, false, true)

    room:setPlayerMark(player, "j_huitian_extra-turn", 1)
    room:setPlayerMark(player, "j_huitian_skills-turn", { "j_huaxin" })

    player:gainAnExtraTurn(false, j_huitian.name)
  end,
})

j_huitian:addEffect(fk.EventPhaseChanging, {
  anim_type = "wake",
  can_trigger = function(self, event, target, player, data)
    local mark = target:getMark("j_huitian_end-turn")
    return mark == 1 and data.to ~= Player.Finish
  end,
  on_use = function(self, event, target, player, data)
    target.room:setPlayerMark(target, "j_huitian_end-turn", 0)
    data.to = Player.Finish
  end,
})

j_huitian:addEffect(fk.EventPhaseEnd, {
  anim_type = "wake",
  can_trigger = function(self, event, target, player, data)
    local mark = player:getMark("j_huitian_extra-turn")
    return target == player and mark == 1 and player.phase == Player.Finish
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local skills_mark = player:getMark("j_huitian_skills-turn")
    local skills = type(skills_mark) == "table" and skills_mark or {}
    if #skills > 0 then
      for _, skill in ipairs(skills) do
        room:handleAddLoseSkills(player, "-" .. skill, j_huitian.name, false, true)
      end
    end
    room:setPlayerMark(player, "j_huitian_extra-turn", 0)
    room:setPlayerMark(player, "j_huitian_skills-turn", {})
  end,
})

return j_huitian