local j_jixian = fk.CreateSkill {
  name = "j_jixian",
}

Fk:loadTranslationTable{
  ["j_jixian"] = "激弦",
  [":j_jixian"] = "当你受到伤害后，若没有角色处于濒死状态，你可以令伤害来源失去1点体力，随机使用一张装备牌。",

  ["$j_jixian1"] = "弦音激越，摧敌肝胆。",
  ["$j_jixian2"] = "一弦既动，杀气自生。",
}

local function noOneDying(room)
  for _, p in ipairs(room.alive_players) do
    if p.dying then return false end
  end
  return true
end

local function randomEquipUse(room, target, skillName)
  local equips = {}
  for _, id in ipairs(target:getCardIds("h")) do
    local card = Fk:getCardById(id)
    if card.type == Card.TypeEquip then
      table.insert(equips, id)
    end
  end
  if #equips == 0 then return nil end
  local cid = equips[room:random(1, #equips)]
  local card = Fk:getCardById(cid)
  room:useCard{ from = target, tos = { target }, card = card, skillName = skillName }
  return card
end

-- 受伤后：令伤害来源失去1点体力，随机使用一张装备牌
j_jixian:addEffect(fk.Damaged, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jixian.name) or player.dead then return false end
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
    room:loseHp(t, 1, j_jixian.name, player)
    if not t.dead then
      randomEquipUse(room, t, j_jixian.name)
    end
  end,
})

-- 绝响授予的梅花免疫：直到其下回合开始，不能成为其他角色使用梅花牌的目标
j_jixian:addEffect(fk.TargetConfirming, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jixian.name) then return false end
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
j_jixian:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jixian.name) then return false end
    if player:getMark("j_juexiang_club") == 0 then return false end
    return data.to == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_juexiang_club", 0)
  end,
})

j_jixian:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_jixian.name,
  think = function(self, player)
    return false
  end,
})

-- 测试：受伤后令伤害来源失去1点体力并随机使用一张装备牌
j_jixian:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jixian.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("spear", Card.Spade, 3)
    room:obtainCard(comp2, { equip }, true, fk.ReasonDraw, comp2, "test")
    local hp_before = comp2.hp
    local eq_before = #comp2:getCardIds("e")

    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, comp2, dmg)
    room.logic:trigger(fk.Damage, comp2, dmg)
    room.logic:trigger(fk.Damaged, comp2, dmg)

    lu.assertEquals(comp2.hp, hp_before - 1, "激弦：伤害来源应失去1点体力")
    lu.assertEquals(#comp2:getCardIds("e"), eq_before + 1, "激弦：伤害来源应随机使用一张装备牌")
  end)
end)

return j_jixian