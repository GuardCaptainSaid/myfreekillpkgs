local j_sangu = fk.CreateSkill {
  name = "j_sangu",
  tags = { Skill.Wake },
}

Fk:loadTranslationTable{
  ["j_sangu"] = "三顾",
  [":j_sangu"] = "觉醒技，准备阶段，若有其他角色与你距离为1且使用牌指定过你为目标，你失去“隐居”，然后获得“智计”。",

  ["#j_sangu-invoke"] = "三顾：你已得明主三顾，觉醒获得“智计”！",

  ["$j_sangu1"] = "三顾频烦天下计，两朝开济老臣心。",
  ["$j_sangu2"] = "备不才，愿得先生出山相助！",
}

-- 记录：其他角色使用牌指定过你为目标
j_sangu:addEffect(fk.TargetSpecified, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_sangu.name) then return false end
    if target ~= player or player.dead then return false end
    if not data or not data.from or data.from == player then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local t = room:getTag("j_sangu_targeted") or {}
    t[data.from.id] = true
    room:setTag("j_sangu_targeted", t)
  end,
})

-- 觉醒：准备阶段，有距离1的角色指定过我为目标
j_sangu:addEffect(fk.EventPhaseStart, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.phase ~= Player.Start then return false end
    if player.dead then return false end
    if not player:hasSkill(j_sangu.name) then return false end
    if not player:hasSkill("j_yinju") then return false end
    local t = player.room:getTag("j_sangu_targeted") or {}
    for _, p in ipairs(player.room.alive_players) do
      -- 觉醒条件按“实际距离为1”判定，不受隐居自身的距离修正影响
      if p ~= player and t[p.id] and player:distanceTo(p, "both", false, nil, { "j_yinju" }) == 1 then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_sangu.name, prompt = "#j_sangu-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:handleAddLoseSkills(player, "-j_yinju|j_zhiji")
    room:setPlayerMark(player, "j_sangu_used", 1)
  end,
})

return j_sangu
