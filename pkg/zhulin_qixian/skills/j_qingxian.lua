local j_qingxian = fk.CreateSkill {
  name = "j_qingxian",
}

Fk:loadTranslationTable{
  ["j_qingxian"] = "清弦",
  [":j_qingxian"] = "当你受到伤害/回复体力后，你可以令伤害来源/一名其他角色执行一项：失去1点体力，随机使用一张装备牌；回复1点体力，弃置一张装备牌。若其以此法使用或弃置的牌为梅花，你回复1点体力。",

  ["#j_qingxian-target"] = "清弦：选择一名角色执行一项",
  ["#j_qingxian-choice"] = "清弦：选择令其执行的一项",
  ["j_qingxian:lose"] = "失去1点体力，随机使用一张装备牌",
  ["j_qingxian:recover"] = "回复1点体力，弃置一张装备牌",

  ["$j_qingxian1"] = "清音入云，弦动九州。",
  ["$j_qingxian2"] = "琴声所至，余韵不绝。",
}

-- 随机使用目标手牌中的一张装备牌；返回所用牌（无可用装备返回 nil）
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

-- 随机弃置目标装备区中的一张装备牌；返回所弃牌（无装备返回 nil）
local function randomEquipDiscard(room, target, skillName)
  local ids = target:getCardIds("e")
  if #ids == 0 then return nil end
  local cid = ids[room:random(1, #ids)]
  local card = Fk:getCardById(cid)
  room:throwCard({ cid }, skillName, target, target)
  return card
end

-- 令目标执行二选一，若所涉牌为梅花则嵇康回复1点体力
local function doQingxian(room, player, target, skillName)
  local choice = room:askToChoice(target, {
    choices = { "j_qingxian:lose", "j_qingxian:recover" },
    skill_name = skillName,
    prompt = "#j_qingxian-choice",
  })
  local usedCard
  if choice == "j_qingxian:lose" then
    room:loseHp(target, 1, skillName, player)
    if not target.dead then
      usedCard = randomEquipUse(room, target, skillName)
    end
  else
    room:recover{ who = target, num = 1, recoverBy = player, skillName = skillName }
    if not target.dead then
      usedCard = randomEquipDiscard(room, target, skillName)
    end
  end
  if usedCard and usedCard.suit == Card.Club and not player.dead then
    room:recover{ who = player, num = 1, recoverBy = player, skillName = skillName }
  end
end

-- 受伤后：令伤害来源执行一项
j_qingxian:addEffect(fk.Damaged, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_qingxian.name) or player.dead then return false end
    if data.from == nil or data.from.dead or data.from == player then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    self.target = data.from
    return true
  end,
  on_use = function(self, event, target, player, data)
    local t = self.target
    self.target = nil
    if t == nil or t.dead then return end
    doQingxian(player.room, player, t, j_qingxian.name)
  end,
})

-- 回复体力后：令一名其他角色执行一项
j_qingxian:addEffect(fk.HpRecover, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_qingxian.name) or player.dead then return false end
    if data.who ~= player then return false end
    return #player.room:getOtherPlayers(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player),
      min_num = 1,
      max_num = 1,
      skill_name = j_qingxian.name,
      prompt = "#j_qingxian-target",
    })
    if #targets == 0 then return false end
    self.target = targets[1]
    return true
  end,
  on_use = function(self, event, target, player, data)
    local t = self.target
    self.target = nil
    if t == nil or t.dead then return end
    doQingxian(player.room, player, t, j_qingxian.name)
  end,
})

j_qingxian:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_qingxian.name,
  think = function(self, player)
    return false
  end,
})

-- 测试：受伤后令伤害来源选择“失去1点体力，随机使用一张装备牌”
j_qingxian:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qingxian.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("guding_blade", Card.Spade, 2)
    room:obtainCard(comp2, { equip }, true, fk.ReasonDraw, comp2, "test")
    local hp_before = comp2.hp
    local eq_before = #comp2:getCardIds("e")

    FkTest.setNextReplies(comp2, { { "j_qingxian:lose" } })
    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, comp2, dmg)
    room.logic:trigger(fk.Damage, comp2, dmg)
    room.logic:trigger(fk.Damaged, comp2, dmg)

    lu.assertEquals(comp2.hp, hp_before - 1, "清弦：伤害来源应失去1点体力")
    lu.assertEquals(#comp2:getCardIds("e"), eq_before + 1, "清弦：伤害来源应随机使用一张装备牌")
  end)
end)

-- 测试：回复体力后令一名其他角色选择“回复1点体力，弃置一张装备牌”
j_qingxian:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qingxian.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("spear", Card.Heart, 5)
    room:useCard{ from = comp2, tos = { comp2 }, card = equip }

    -- 先扣掉 me 与 comp2 一点体力：保证回复事件有效且目标可回血
    room:changeHp(me, -1, fk.LoseHp, "test")
    room:changeHp(comp2, -1, fk.LoseHp, "test")
    local hp_before = comp2.hp
    local eq_before = #comp2:getCardIds("e")
    FkTest.setNextReplies(me, { FkTest.ReplyChoosePlayer({ comp2 }) })
    FkTest.setNextReplies(comp2, { { "j_qingxian:recover" } })
    room:recover{ who = me, num = 1, recoverBy = comp2, skillName = "test" }

    lu.assertEquals(comp2.hp, hp_before + 1, "清弦：目标应回复1点体力")
    lu.assertEquals(#comp2:getCardIds("e"), eq_before - 1, "清弦：目标应弃置一张装备牌")
  end)
end)

return j_qingxian