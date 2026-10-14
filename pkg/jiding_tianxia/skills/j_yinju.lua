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

-- 测试：持有隐居时，与其他角色的距离应 +X
j_yinju:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yinju.name)
    -- 测试环境无 RoundCount banner → X = 3 - 0 = 3
    local X = 3 - (room:getBanner("RoundCount") or 0)
    -- 座次 me->comp2->comp3（3人）距离1；有隐居时 me→comp2 距离应 +X
    lu.assertEquals(me:distanceTo(comp2), math.max(1 + X, 1), "你到相邻角色距离应+X")
    lu.assertEquals(comp2:distanceTo(me), math.max(1 + X, 1), "其他角色到你距离应+X")
    -- comp2 与 comp3 之间无隐居 → 距离不受影响
    lu.assertEquals(comp2:distanceTo(comp3), 1, "无隐居角色间距离应正常")
  end)
end)

return j_yinju