local j_xieling = fk.CreateSkill {
  name = "j_xieling",
}

Fk:loadTranslationTable{
  ["j_xieling"] = "胁令",
  [":j_xieling"] = "当你受到伤害时，若场上存在武器牌，你可以将一张手牌当作【借刀杀人】使用，若此牌未造成伤害，你令伤害来源选择一项：1.令你回复1点体力；2.令你获得其一张牌。",

  ["#j_xieling-invoke"] = "胁令：是否将一张手牌当作【借刀杀人】使用？",
  ["#j_xieling-card"] = "胁令：选择一张手牌当作【借刀杀人】使用",
  ["#j_xieling-weapon"] = "胁令：选择一名装备着武器牌的角色",
  ["#j_xieling-victim"] = "胁令：选择其攻击范围内的一名角色",
  ["#j_xieling-choice"] = "胁令：选择一项",

  ["j_xieling_recover"] = "令其回复1点体力",
  ["j_xieling_gain"] = "令其获得你一张牌",

  ["$j_xieling1"] = "刀借于人，祸归于汝。",
  ["$j_xieling2"] = "受我一令，敢不从乎！",
}

-- 场上装备着武器牌、且其攻击范围内有其他角色的角色（借刀杀人的合法第一目标）
local function collateral_holders(room, me)
  return table.filter(room.alive_players, function(p)
    if p == me then return false end
    if not p:getEquipment(Card.SubtypeWeapon) then return false end
    return table.find(room.alive_players, function(q)
      return q ~= p and p:inMyAttackRange(q)
    end) ~= nil
  end)
end

-- 场上任意角色装备着武器牌（含自己；借刀杀人的第一目标仍限定其他角色）
local function has_weapon_on_field(room)
  return table.find(room.alive_players, function(p)
    return p:getEquipment(Card.SubtypeWeapon)
  end) ~= nil
end

-- 受到伤害时：将一张手牌当作【借刀杀人】使用
j_xieling:addEffect(fk.DamageInflicted, {
  global = true,
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xieling.name) or player.dead then return false end
    if data.to ~= player then return false end
    -- 借刀杀人结算期间不再重复触发（避免递归）
    if player.room:getTag("j_xieling_pending") then return false end
    if #player:getCardIds("h") == 0 then return false end
    return has_weapon_on_field(player.room)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_xieling.name, prompt = "#j_xieling-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = player:getCardIds("h")
    local cards = room:askToChooseCards(player, {
      target = player,
      flag = { card_data = { { "j_xieling_card", ids } } },
      min = 1,
      max = 1,
      skill_name = j_xieling.name,
      prompt = "#j_xieling-card",
      cancelable = true,
    })
    if #cards == 0 then return end

    local holders = collateral_holders(room, player)
    if #holders == 0 then return end
    local a_list = room:askToChoosePlayers(player, {
      targets = holders,
      min_num = 1,
      max_num = 1,
      skill_name = j_xieling.name,
      prompt = "#j_xieling-weapon",
      cancelable = true,
    })
    if #a_list == 0 then return end
    local a = a_list[1]

    local b_cands = table.filter(room.alive_players, function(q)
      return q ~= a and a:inMyAttackRange(q)
    end)
    if #b_cands == 0 then return end
    local b_list = room:askToChoosePlayers(player, {
      targets = b_cands,
      min_num = 1,
      max_num = 1,
      skill_name = j_xieling.name,
      prompt = "#j_xieling-victim",
      cancelable = true,
    })
    if #b_list == 0 then return end
    local b = b_list[1]

    local card = Fk:cloneCard("collateral")
    card.skillName = j_xieling.name
    card:addSubcard(cards[1])

    room:setTag("j_xieling_hit", false)
    room:setTag("j_xieling_pending", { from_id = a.id, to_id = b.id })
    room:useCard{
      from = player,
      tos = { a, b },
      card = card,
      extraUse = true,
    }
    room:setTag("j_xieling_pending", nil)

    -- 此牌未造成伤害：令伤害来源选择一项
    if room:getTag("j_xieling_hit") == true then return end
    if player.dead then return end
    local src = data.from
    if not src or src.dead or src == player then return end

    local choice = room:askToChoice(src, {
      choices = { "j_xieling_recover", "j_xieling_gain" },
      skill_name = j_xieling.name,
      prompt = "#j_xieling-choice",
    })
    if choice == "j_xieling_recover" then
      room:recover{ who = player, num = 1, recoverBy = src, skillName = j_xieling.name }
    else
      local src_ids = src:getCardIds("he")
      if #src_ids == 0 then return end
      local id = src_ids[math.random(1, #src_ids)]
      room:obtainCard(player, { id }, true, fk.ReasonPrey, src, j_xieling.name)
    end
  end,
})

-- 结算期间检测：借刀杀人指定的杀是否造成了伤害
j_xieling:addEffect(fk.DamageInflicted, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xieling.name) then return false end
    local pending = player.room:getTag("j_xieling_pending")
    if type(pending) ~= "table" then return false end
    if not (data.from and data.to and data.card) then return false end
    -- 借刀触发的出杀可能是杀/火杀/雷杀，任一命中都应记入
    return data.from.id == pending.from_id and data.to.id == pending.to_id and
      (data.card.trueName == "slash" or data.card.trueName == "fire_slash" or data.card.trueName == "thunder_slash")
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setTag("j_xieling_hit", true)
  end,
})

-- 测试：受到伤害且场上有武器牌 → 将一张手牌当作【借刀杀人】使用
j_xieling:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  local c1, weapon
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xieling.name)
    c1 = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    weapon = room:printCard("blade", Card.Spade, 1)
    room:moveCardTo(weapon.id, Card.PlayerEquip, comp2, fk.ReasonPut, "test")
  end)

  FkTest.runInRoom(function()
    local origInvoke, origCards, origPlayers, origChoice, origUse =
      room.askToSkillInvoke, room.askToChooseCards, room.askToChoosePlayers, room.askToChoice, room.useCard
    room.askToSkillInvoke = function(self, who, params) return true end
    room.askToChooseCards = function(self, who, params) return { c1.id } end
    room.askToChoosePlayers = function(self, who, params)
      if params.prompt == "#j_xieling-weapon" then return { comp2 } end
      return { comp3 }
    end
    room.askToChoice = function(self, who, params)
      lu.assertEquals(who, comp2, "未造成伤害时应由伤害来源选择一项")
      return "j_xieling_recover"
    end
    local used
    room.useCard = function(self, params) used = params end
    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, me, dmg)
    room.askToSkillInvoke = origInvoke
    room.askToChooseCards = origCards
    room.askToChoosePlayers = origPlayers
    room.askToChoice = origChoice
    room.useCard = origUse

    lu.assertNotNil(used, "应视为使用【借刀杀人】")
    lu.assertEquals(used.card.name, "collateral", "使用的牌应为借刀杀人")
    lu.assertEquals(#used.tos, 2, "借刀杀人应指定两名角色")
    lu.assertEquals(used.tos[1], comp2, "第一目标应为持武器的角色")
  end)
end)

-- 测试：场上无武器牌时不触发
j_xieling:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xieling.name)
    local c1 = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local used
    local origUse = room.useCard
    room.useCard = function(self, params) used = params end
    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, me, dmg)
    room.useCard = origUse
    lu.assertIsNil(used, "场上无武器牌时不应视为使用借刀杀人")
  end)
end)

-- 测试：计司马师自己装备武器牌时也应触发（场上武器含自己）
j_xieling:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, weapon
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xieling.name)
    c1 = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    weapon = room:printCard("blade", Card.Spade, 1)
    room:moveCardTo(weapon.id, Card.PlayerEquip, me, fk.ReasonPut, "test")
  end)

  FkTest.runInRoom(function()
    local origInvoke, origCards, origPlayers, origChoice, origUse =
      room.askToSkillInvoke, room.askToChooseCards, room.askToChoosePlayers, room.askToChoice, room.useCard
    local invoked = false
    room.askToSkillInvoke = function(self, who, params)
      invoked = true
      return true
    end
    room.askToChooseCards = function(self, who, params) return { c1.id } end
    room.askToChoosePlayers = function(self, who, params)
      return { }
    end
    room.askToChoice = function(self, who, params) return "j_xieling_recover" end
    local used
    room.useCard = function(self, params) used = params end
    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, me, dmg)
    room.askToSkillInvoke = origInvoke
    room.askToChooseCards = origCards
    room.askToChoosePlayers = origPlayers
    room.askToChoice = origChoice
    room.useCard = origUse

    lu.assertTrue(invoked, "自己装备武器牌时也应询问是否发动胁令")
    lu.assertIsNil(used, "场上仅自己持武器时无其他持武器角色，借刀不应使用")
  end)
end)

return j_xieling
