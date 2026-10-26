-- 计国渊·正声
-- 每回合限一次，若其他角色使用牌指定你为唯一目标，此牌结算后，你可以将一张非基本牌当作【杀】
-- 对其使用。若此【杀】对其造成伤害，你可以令其本回合下X张牌失效（X为其体力值）。
local j_guoyuan_zhengsheng = fk.CreateSkill {
  name = "j_guoyuan_zhengsheng",
}

local INVALID = "@@j_guoyuan_zhengsheng_invalid-turn"  -- 本回合下X张牌失效（`@@` 前缀：标记区只显示文字）
local USED = "j_guoyuan_zhengsheng_used-turn"           -- 每回合限一次（纯内部标记，不加 @，不广播到 UI）

Fk:loadTranslationTable{
  ["j_guoyuan_zhengsheng"] = "正声",
  [":j_guoyuan_zhengsheng"] = "每回合限一次，若其他角色使用牌指定你为唯一目标，此牌结算后，你可以将一张非基本牌当作【杀】" ..
    "对其使用。若此【杀】对其造成伤害，你可以令其本回合下X张牌失效（X为其体力值）。",

  [INVALID] = "正声",

  ["#j_guoyuan_zhengsheng-invoke"] = "正声：是否将一张非基本牌当作【杀】对 %src 使用？",
  ["#j_guoyuan_zhengsheng-card"] = "正声：选择一张非基本牌当作【杀】使用",
  ["#j_guoyuan_zhengsheng-invalid"] = "正声：是否令 %dest 本回合下 %arg 张牌失效？",

  ["$j_guoyuan_zhengsheng1"] = "正色立朝，奸佞自退！",
  ["$j_guoyuan_zhengsheng2"] = "吾以清声正天下！",
}

-- 该角色还有几张牌能被当作【杀】打出（用于 can_trigger 预判）
local function canSlashTo(player, target)
  local slash = Fk:cloneCard("slash")
  slash.skillName = j_guoyuan_zhengsheng.name
  return player:canUseTo(slash, target)
end

j_guoyuan_zhengsheng:addEffect(fk.CardUseFinished, {
  anim_type = "offensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_guoyuan_zhengsheng.name) or player.dead then return false end
    if player:getMark(USED) > 0 then return false end
    local from = data and data.from
    if not from or from == player or from.dead then return false end
    local tos = data.tos or {}
    if #tos ~= 1 or tos[1] ~= player then return false end
    -- 手里（含装备区）必须至少有一张非基本牌，且这张虚拟【杀】确实能对其使用
    local has_card = table.find(player:getCardIds("he"), function(id)
      return Fk:getCardById(id).type ~= Card.TypeBasic
    end) ~= nil
    if not has_card then return false end
    return canSlashTo(player, from)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_guoyuan_zhengsheng.name,
      prompt = "#j_guoyuan_zhengsheng-invoke::" .. data.from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    room:setPlayerMark(player, USED, 1)

    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      pattern = ".|.|.|.|.|^basic",
      skill_name = j_guoyuan_zhengsheng.name,
      prompt = "#j_guoyuan_zhengsheng-card",
    })
    if #cards == 0 then return end
    if player.dead or from.dead then return end

    local slash = Fk:cloneCard("slash")
    slash.skillName = j_guoyuan_zhengsheng.name
    slash:addSubcard(cards[1])
    if not player:canUseTo(slash, from) then return end
    room:useCard({ from = player, tos = { from }, card = slash })
  end,
})

-- 此【杀】造成伤害后：令其本回合下X张牌失效（X为其体力值）
j_guoyuan_zhengsheng:addEffect(fk.Damaged, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_guoyuan_zhengsheng.name) or player.dead then return false end
    if target == player or target.dead then return false end
    if data.from ~= player then return false end
    if not data.card or data.card.skillName ~= j_guoyuan_zhengsheng.name then return false end
    return target.hp > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_guoyuan_zhengsheng.name,
      prompt = "#j_guoyuan_zhengsheng-invalid::" .. target.id .. "::" .. target.hp,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if target.dead then return end
    room:setPlayerMark(target, INVALID, target.hp)
  end,
})

-- 被标记的角色使用牌 → 此牌无效，计数减一
j_guoyuan_zhengsheng:addEffect(fk.CardUsing, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_guoyuan_zhengsheng.name) then return false end
    local from = data and data.from
    if not from or from.dead then return false end
    return from:getMark(INVALID) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    local left = from:getMark(INVALID)
    if left <= 0 then return end  -- 另一名正声拥有者已处理过，避免重复结算
    room:setPlayerMark(from, INVALID, left - 1)
    data.nullifiedTargets = data.nullifiedTargets or {}
    for _, to in ipairs(data.tos or {}) do
      table.insertIfNeed(data.nullifiedTargets, to)
    end
  end,
})

-- 测试1：其他角色对国渊使用唯一目标的牌并结算完 → 可把非基本牌当【杀】反杀
j_guoyuan_zhengsheng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guoyuan_zhengsheng.name)
    local comp = room.players[2]
    comp.hp = comp.maxHp
    local equip = room:printCard("qinggang_sword", Card.Spade, 3)
    room:obtainCard(me, { equip.id }, true, fk.ReasonDraw, me, "test")

    local use = {
      from = comp,
      tos = { me },
      card = room:printCard("slash", Card.Club, 6),
      nullifiedTargets = {},
    }

    local realInvoke = room.askToSkillInvoke
    local realCards = room.askToCards
    room.askToSkillInvoke = function(self, who, params)
      if params.skill_name == j_guoyuan_zhengsheng.name then return true end
      return realInvoke(self, who, params)
    end
    room.askToCards = function(self, who, params)
      if params.skill_name == j_guoyuan_zhengsheng.name then return { equip.id } end
      return realCards(self, who, params)
    end
    room.logic:trigger(fk.CardUseFinished, comp, use)
    room.askToSkillInvoke = realInvoke
    room.askToCards = realCards

    lu.assertTrue(me:getMark(USED) > 0, "发动后应记录每回合限一次")
    lu.assertFalse(table.contains(me:getCardIds("he"), equip.id), "当作【杀】的非基本牌应已离开手牌/装备区")
  end)
end)

-- 测试2：多个目标时不触发
j_guoyuan_zhengsheng:addTest(function(room, me)
  local comp2, comp3 = room.players[2], room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guoyuan_zhengsheng.name)
    room:setPlayerMark(me, USED, 0)
    local equip = room:printCard("qinggang_sword", Card.Heart, 4)
    room:obtainCard(me, { equip.id }, true, fk.ReasonDraw, me, "test")
    local use = {
      from = comp2,
      tos = { me, comp3 },
      card = room:printCard("ex_nihilo", Card.Heart, 5),
      nullifiedTargets = {},
    }
    local eff = j_guoyuan_zhengsheng.effects[1]
    lu.assertFalse(eff:triggerable(nil, me, me, use), "非唯一目标时不应触发")
  end)
end)

-- 测试3：伤害后令目标本回合下X张牌失效，且使用牌时生效并递减
j_guoyuan_zhengsheng:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guoyuan_zhengsheng.name)
    comp.hp = 3
    local card = room:printCard("slash", Card.Spade, 7)
    card.skillName = j_guoyuan_zhengsheng.name
    local dmg = DamageData:new{ from = me, to = comp, damage = 1, damageType = fk.NormalDamage, card = card }
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.Damaged, comp, dmg)
    lu.assertEquals(comp:getMark(INVALID), 3, "应按目标体力值标记失效张数")
  end)
  FkTest.runInRoom(function()
    local slash = room:printCard("slash", Card.Club, 8)
    local use = { from = comp, tos = { me }, card = slash, nullifiedTargets = {} }
    room.logic:trigger(fk.CardUsing, comp, use)
    lu.assertEquals(comp:getMark(INVALID), 2, "使用一张牌后失效张数应减一")
    lu.assertTrue(table.contains(use.nullifiedTargets, me), "该牌应对国渊无效")
  end)
end)

return j_guoyuan_zhengsheng
