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

return j_jizhi2
