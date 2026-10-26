-- 计许攸·矜策（转换技）
-- 阳：你可以将一张装备牌当作不可响应的【杀】使用；
-- 阴：你可以将一张装备牌当作不可响应的【火攻】使用。
-- 以此法使用的牌造成伤害后，你可以令一名角色下一张牌失效。
local j_xuyou_jince = fk.CreateSkill {
  name = "j_xuyou_jince",
  tags = { Skill.Switch },
}

local INVALID = "@@j_xuyou_jince_invalid"  -- 该角色下一张牌失效（`@@` 前缀：标记区只显示文字）

Fk:loadTranslationTable{
  ["j_xuyou_jince"] = "矜策",
  [":j_xuyou_jince"] = "转换技。阳：你可以将一张装备牌当作不可响应的【杀】使用；" ..
    "阴：你可以将一张装备牌当作不可响应的【火攻】使用。以此法使用的牌造成伤害后，你可以令一名角色下一张牌失效。",
  [":j_xuyou_jince_yang"] = "转换技。" ..
    "<font color='#E0DB2F'>阳：你可以将一张装备牌当作不可响应的【杀】使用；</font>" ..
    "<font color='grey'>阴：你可以将一张装备牌当作不可响应的【火攻】使用。</font>" ..
    "以此法使用的牌造成伤害后，你可以令一名角色下一张牌失效。",
  [":j_xuyou_jince_yin"] = "转换技。" ..
    "<font color='grey'>阳：你可以将一张装备牌当作不可响应的【杀】使用；</font>" ..
    "<font color='#E0DB2F'>阴：你可以将一张装备牌当作不可响应的【火攻】使用。</font>" ..
    "以此法使用的牌造成伤害后，你可以令一名角色下一张牌失效。",

  [INVALID] = "矜策",
  ["#j_xuyou_jince-invoke"] = "矜策：是否令一名角色下一张牌失效？",
  ["#j_xuyou_jince-choose"] = "矜策：选择一名角色，其下一张牌失效",

  ["$j_xuyou_jince1"] = "谋定而后动，策出而敌摧！",
  ["$j_xuyou_jince2"] = "一策既出，万军辟易！",
}

-- 阳形态【杀】/ 阴形态【火攻】：装备牌转化
j_xuyou_jince:addEffect("viewas", {
  anim_type = "offensive",
  card_num = 1,
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    return Fk:getCardById(to_select).type == Card.TypeEquip
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local cardName = "slash"
    if player:getSwitchSkillState(j_xuyou_jince.name) ~= fk.SwitchYang then
      cardName = "fire_attack"
    end
    local card = Fk:cloneCard(cardName)
    card.skillName = j_xuyou_jince.name
    card:addSubcard(cards[1])
    return card
  end,
})

-- 以此法使用的牌不可被响应
j_xuyou_jince:addEffect(fk.PreCardUse, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_xuyou_jince.name) then return false end
    return data.card ~= nil and data.card.skillName == j_xuyou_jince.name
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.disresponsiveList = table.simpleClone(player.room.alive_players)
  end,
})

-- 造成伤害后：可以令一名角色下一张牌失效
j_xuyou_jince:addEffect(fk.Damaged, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xuyou_jince.name) or player.dead then return false end
    if not data.card or data.card.skillName ~= j_xuyou_jince.name then return false end
    if data.from ~= player then return false end
    local room = player.room
    for _, p in ipairs(room.players) do
      if not p.dead then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_xuyou_jince.name,
      prompt = "#j_xuyou_jince-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local tos = room:askToChoosePlayers(player, {
      targets = table.filter(room.alive_players, function(p) return not p.dead end),
      min_num = 1,
      max_num = 1,
      skill_name = j_xuyou_jince.name,
      prompt = "#j_xuyou_jince-choose",
    })
    if tos and #tos > 0 and not tos[1].dead then
      room:setPlayerMark(tos[1], INVALID, 1)
    end
  end,
})

-- 被标记的角色使用牌 → 此牌无效
j_xuyou_jince:addEffect(fk.CardUsing, {
  global = true,
  on_cost = Util.TrueFunc,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xuyou_jince.name) then return false end
    local from = data and data.from
    if not from or from.dead then return false end
    return from:getMark(INVALID) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    room:setPlayerMark(from, INVALID, 0)
    data.nullifiedTargets = data.nullifiedTargets or {}
    for _, to in ipairs(data.tos or {}) do
      table.insertIfNeed(data.nullifiedTargets, to)
    end
  end,
})

-- 测试1：阳形态把装备牌转化为【杀】
j_xuyou_jince:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jince.name)
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_xuyou_jince.name, 0)  -- 阳
  end)
  FkTest.runInRoom(function()
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_jince.name), fk.SwitchYang, "应为阳形态")
    local equip = room:printCard("qinggang_sword", Card.Spade, 3).id
    room:obtainCard(me, { equip }, true, fk.ReasonDraw, me, "test")
    local skel = Fk.skills[j_xuyou_jince.name]:getSkeleton()
    local eff = skel.effects[1]
    local card = eff:viewAs(me, { equip })
    lu.assertNotNil(card, "阳形态装备牌应可转化")
    lu.assertEquals(card.name, "slash", "阳形态应转化为【杀】")
    lu.assertEquals(card.type, Card.TypeBasic)
  end)
end)

-- 测试2：阴形态把装备牌转化为【火攻】
j_xuyou_jince:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jince.name)
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_xuyou_jince.name, 1)  -- 阴
  end)
  FkTest.runInRoom(function()
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_jince.name), fk.SwitchYin, "应为阴形态")
    local equip = room:printCard("qinggang_sword", Card.Heart, 4).id
    room:obtainCard(me, { equip }, true, fk.ReasonDraw, me, "test")
    local skel = Fk.skills[j_xuyou_jince.name]:getSkeleton()
    local eff = skel.effects[1]
    local card = eff:viewAs(me, { equip })
    lu.assertNotNil(card, "阴形态装备牌应可转化")
    lu.assertEquals(card.name, "fire_attack", "阴形态应转化为【火攻】")
  end)
end)

-- 测试3：以此法使用牌造成伤害后 → 令一名角色下一张牌失效
j_xuyou_jince:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jince.name)
    comp3.hp = comp3.maxHp
    local card = room:printCard("slash", Card.Spade, 5)
    card.skillName = j_xuyou_jince.name
    local dmg = DamageData:new{ from = me, to = comp3, damage = 1, damageType = fk.NormalDamage, card = card }
    FkTest.setNextReplies(me, { "1", { card = {}, targets = { comp2.id } } })
    room.logic:trigger(fk.Damaged, comp3, dmg)
    lu.assertTrue(comp2:getMark(INVALID) > 0, "目标应被标记为下一张牌失效")
  end)
  FkTest.runInRoom(function()
    -- comp2 使用一张【杀】：应被无效
    local slash = room:printCard("slash", Card.Club, 6)
    local use = { from = comp2, tos = { me }, card = slash, nullifiedTargets = {} }
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertTrue(table.contains(use.nullifiedTargets, me), "被标记的角色使用的牌应对目标无效")
    lu.assertEquals(comp2:getMark(INVALID), 0, "标记应在使用一张牌后清除")
  end)
end)

-- 测试4：以此法使用的牌不可被响应
j_xuyou_jince:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jince.name)
  end)
  FkTest.runInRoom(function()
    local card = Fk:cloneCard("slash")
    card.skillName = j_xuyou_jince.name
    local use = UseCardData:new{ from = me, card = card, tos = {} }
    room.logic:trigger(fk.PreCardUse, me, use)
    lu.assertNotNil(use.disresponsiveList, "矜策转化的牌应不可被响应")
    lu.assertEquals(#use.disresponsiveList, #room.players, "所有角色都不应能响应此牌")
  end)
end)

return j_xuyou_jince
