-- 轲比能二号·越边（锁定技）
-- 若你的体力值大于等于4，你拥有技能"强袭"；若你的体力值大于等于3，你摸牌阶段多摸一张牌；
-- 若你的体力值小于等于2，每轮开始时你摸一号位体力值张牌；若你的体力值小于等于1，你视为拥有"绝境"和"龙魂"。
local s_yuebian = fk.CreateSkill {
  name = "s_yuebian",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["s_yuebian"] = "越边",
  [":s_yuebian"] = "锁定技，若你的体力值大于等于4，你拥有技能“强袭”；若你的体力值大于等于3，你摸牌阶段多摸一张牌；若你的体力值小于等于2，每轮开始时你摸一号位体力值张牌；若你的体力值小于等于1，你视为拥有“绝境”和“龙魂”。",
}

-- 刷新动态获得的技能（按体力值档位）
local function refreshSkills(room, player)
  local hp = player.hp
  if Fk.skills["qiangxi"] then
    if hp >= 4 and not player:hasSkill("qiangxi") then
      room:handleAddLoseSkills(player, "qiangxi", nil, false, true)
    elseif hp < 4 and player:hasSkill("qiangxi") then
      room:handleAddLoseSkills(player, "-qiangxi", nil, false, true)
    end
  end
  for _, name in ipairs({ "juejing", "longhun" }) do
    if Fk.skills[name] then
      if hp <= 1 and not player:hasSkill(name) then
        room:handleAddLoseSkills(player, name, nil, false, true)
      elseif hp > 1 and player:hasSkill(name) then
        room:handleAddLoseSkills(player, "-" .. name, nil, false, true)
      end
    end
  end
end

s_yuebian:addEffect(fk.GameStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(s_yuebian.name)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    refreshSkills(player.room, player)
  end,
})

s_yuebian:addEffect(fk.HpChanged, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(s_yuebian.name) and not player.dead
      and data and data.num ~= 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    refreshSkills(player.room, player)
  end,
})

-- 体力≥3：摸牌阶段多摸一张牌
s_yuebian:addEffect(fk.DrawNCards, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(s_yuebian.name) and player.hp >= 3
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
})

-- 体力≤2：每轮开始时摸一号位体力值张牌
s_yuebian:addEffect(fk.RoundStart, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(s_yuebian.name) and not player.dead and player.hp <= 2
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local p1 = room:getPlayerById(1)
    if p1 and not p1.dead and p1.hp > 0 then
      player:drawCards(p1.hp, s_yuebian.name)
    end
  end,
})

-- 测试1：体力≥4 → 获得强袭；摸牌阶段多摸一张
s_yuebian:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_yuebian.name)
    me.maxHp = 4
    me.hp = 4
  end)
  FkTest.runInRoom(function()
    room.logic:trigger(fk.GameStart, me, {})
    lu.assertTrue(me:hasSkill("qiangxi"), "越边：体力≥4应拥有强袭")
    local d = { n = 2 }
    room.logic:trigger(fk.DrawNCards, me, d)
    lu.assertEquals(d.n, 3, "越边：体力≥3摸牌阶段应多摸一张")
  end)
end)

-- 测试2：体力≤1 → 获得绝境与龙魂；每轮开始摸一号位体力值张
s_yuebian:addTest(function(room, me)
  local p1 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_yuebian.name)
    me.maxHp = 4
    me.hp = 1
    p1.maxHp = 4
    p1.hp = 3
  end)
  FkTest.runInRoom(function()
    room.logic:trigger(fk.HpChanged, me, { num = -1 })
    lu.assertTrue(me:hasSkill("juejing"), "越边：体力≤1应拥有绝境")
    lu.assertTrue(me:hasSkill("longhun"), "越边：体力≤1应拥有龙魂")
    local before = #me:getCardIds("h")
    room.logic:trigger(fk.RoundStart, p1, {})
    -- 一号位即 me（体力1）→ 摸1张
    lu.assertEquals(#me:getCardIds("h"), before + 1, "越边：体力≤2每轮开始应摸一号位体力值张牌")
  end)
end)

-- 测试3：体力回至3 → 失去绝境与龙魂；体力降至3仍保留强袭档（4档失去）
s_yuebian:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_yuebian.name)
    me.maxHp = 4
    me.hp = 4
    room.logic:trigger(fk.GameStart, me, {})
  end)
  FkTest.runInRoom(function()
    me.hp = 2
    room.logic:trigger(fk.HpChanged, me, { num = -2 })
    lu.assertFalse(me:hasSkill("qiangxi"), "越边：体力<4应失去强袭")
    lu.assertTrue(me:hasSkill(s_yuebian.name), "越边：本体技能不受影响")
  end)
end)

return s_yuebian