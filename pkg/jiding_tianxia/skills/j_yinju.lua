local j_yinju = fk.CreateSkill {
  name = "j_yinju",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_yinju"] = "隐居",
  [":j_yinju"] = "锁定技，其他角色与你和你与其他角色的距离均+X（X为3-游戏轮数）。",

  ["$j_yinju1"] = "大梦谁先觉，平生我自知。",
  ["$j_yinju2"] = "隐居隆中，静待天时。",
}

-- 距离修正：其他角色与你、你与其他角色距离均 +X（X = 3 - 游戏轮数，不小于0）
j_yinju:addEffect("distance", {
  correct_func = function(self, from, to)
    if not from or not to then return 0 end
    local room = from.room
    if not room then return 0 end
    local round = room:getBanner("RoundCount") or 0
    local X = 3 - round
    if X <= 0 then return 0 end
    if from:hasSkill(j_yinju.name) or to:hasSkill(j_yinju.name) then
      return X
    end
    return 0
  end,
})

return j_yinju
