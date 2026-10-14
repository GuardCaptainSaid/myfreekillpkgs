local j_rouxian = fk.CreateSkill {
  name = "j_rouxian",
}

Fk:loadTranslationTable{
  ["j_rouxian"] = "柔弦",
  [":j_rouxian"] = "当你受到伤害后，若没有角色处于濒死状态，你可以令伤害来源回复1点体力，弃置一张装备牌。",

  ["$j_rouxian1"] = "柔弦如水，润物无声。",
  ["$j_rouxian2"] = "弦声婉转，恩怨两消。",
}

local function noOneDying(room)
  for _, p in ipairs(room.alive_players) do
    if p.dying then return false end
  end
  return true
end

local function randomEquipDiscard(room, target, skillName)
  local ids = target:getCardIds("e")
  if #ids == 0 then return nil end
  local cid = ids[room:random(1, #ids)]
  local card = Fk:getCardById(cid)
  room:throwCard({ cid }, skillName, target, target)
  return card
end

-- 受伤后：令伤害来源回复1点体力，弃置一张装备牌
j_rouxian:addEffect(fk.Damaged, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_rouxian.name) or player.dead then return false end
    if data.from == nil or data.from.dead or data.from == player then return false end
    return noOneDying(player.room)
  end,
  on_cost = function(self, event, target, player, data)
    self.target = data.from
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local t = self.target
    self.target = nil
    if t == nil or t.dead then return end
    room:recover{ who = t, num = 1, recoverBy = player, skillName = j_rouxian.name }
    if not t.dead then
      randomEquipDiscard(room, t, j_rouxian.name)
    end
  end,
})

-- 绝响授予的梅花免疫：直到其下回合开始，不能成为其他角色使用梅花牌的目标
j_rouxian:addEffect(fk.TargetConfirming, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_rouxian.name) then return false end
    if player:getMark("j_juexiang_club") == 0 then return false end
    if not data.card or data.card.suit ~= Card.Club then return false end
    if data.from == player then return false end
    return data:hasTarget(player)
  end,
  on_use = function(self, event, target, player, data)
    data:removeTarget(player)
  end,
})

-- 其回合开始时清除梅花免疫标记
j_rouxian:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_rouxian.name) then return false end
    if player:getMark("j_juexiang_club") == 0 then return false end
    return data.to == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_juexiang_club", 0)
  end,
})

j_rouxian:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_rouxian.name,
  think = function(self, player)
    return false
  end,
})

-- 测试：受伤后令伤害来源回复1点体力并弃置一张装备牌
j_rouxian:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_rouxian.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("spear", Card.Club, 7)
    room:useCard{ from = comp2, tos = { comp2 }, card = equip }

    -- 先扣掉 comp2 一点体力，保证回复有效
    room:changeHp(comp2, -1, fk.LoseHp, "test")
    local hp_before = comp2.hp
    local eq_before = #comp2:getCardIds("e")

    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, comp2, dmg)
    room.logic:trigger(fk.Damage, comp2, dmg)
    room.logic:trigger(fk.Damaged, comp2, dmg)

    lu.assertEquals(comp2.hp, hp_before + 1, "柔弦：伤害来源应回复1点体力")
    lu.assertEquals(#comp2:getCardIds("e"), eq_before - 1, "柔弦：伤害来源应弃置一张装备牌")
  end)
end)

return j_rouxian