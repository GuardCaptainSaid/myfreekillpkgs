-- 计枣祗·倡制
-- 锁定技，你无法使用装备牌和锦囊牌，你的手牌上限+Y。（Y为全场角色的体力之和）
local j_changzhi = fk.CreateSkill {
  name = "j_changzhi",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_changzhi"] = "倡制",
  [":j_changzhi"] = "锁定技，你不能使用装备牌和锦囊牌；你的手牌上限+Y（Y为全场角色的体力之和）。",
}

-- 全场角色体力之和
local function sumAllHp(room)
  local y = 0
  for _, p in ipairs(room.alive_players) do
    y = y + math.max(p.hp, 0)
  end
  return y
end

-- 无法使用装备牌和锦囊牌（【广济】视为使用的牌不受此限制）
j_changzhi:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    if not player:hasSkill(j_changzhi.name) then return false end
    if not card then return false end
    -- 【广济】转化出的虚拟牌可正常使用
    local sn = card.skillName
    if sn == "j_guangji" or (type(sn) == "string" and string.sub(sn, 1, 10) == "#j_guangji") then
      return false
    end
    return card.type == Card.TypeEquip or card.type == Card.TypeTrick
  end,
})

-- 手牌上限 +Y
j_changzhi:addEffect("maxcards", {
  correct_func = function(self, player)
    if not player:hasSkill(j_changzhi.name) then return 0 end
    return sumAllHp(player.room)
  end,
})

-- 测试：无法使用装备牌与锦囊牌
j_changzhi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_changzhi.name)
  end)
  FkTest.runInRoom(function()
    lu.assertTrue(me:prohibitUse(Fk:cloneCard("slash")) == false, "基本牌【杀】不受限制")
    lu.assertTrue(me:prohibitUse(Fk:cloneCard("dismantlement")), "锦囊牌应被禁止使用")
    lu.assertTrue(me:prohibitUse(Fk:cloneCard("crossbow")), "装备牌应被禁止使用")
  end)
end)

-- 测试：手牌上限+Y（Y为全场体力之和）
j_changzhi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_changzhi.name)
  end)
  FkTest.runInRoom(function()
    local y = 0
    for _, p in ipairs(room.alive_players) do
      y = y + math.max(p.hp, 0)
    end
    lu.assertEquals(me:getMaxCards(), math.max(me.hp, 0) + y, "手牌上限应为体力值+Y")
  end)
end)

return j_changzhi
