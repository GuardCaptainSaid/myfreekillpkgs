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
  [":j_xuyou_jince"] = "转换技，每回合限一次。阳：你可以将一张装备牌当作不可响应的【杀】使用；" ..
    "阴：你可以将一张装备牌当作不可响应的【火攻】使用。以此法使用的牌造成伤害后，你可以令一名角色下一张牌失效。",
  [":j_xuyou_jince_yang"] = "转换技，每回合限一次。" ..
    "<font color='#E0DB2F'>阳：你可以将一张装备牌当作不可响应的【杀】使用；</font>" ..
    "<font color='grey'>阴：你可以将一张装备牌当作不可响应的【火攻】使用。</font>" ..
    "以此法使用的牌造成伤害后，你可以令一名角色下一张牌失效。",
  [":j_xuyou_jince_yin"] = "转换技，每回合限一次。" ..
    "<font color='grey'>阳：你可以将一张装备牌当作不可响应的【杀】使用；</font>" ..
    "<font color='#E0DB2F'>阴：你可以将一张装备牌当作不可响应的【火攻】使用。</font>" ..
    "以此法使用的牌造成伤害后，你可以令一名角色下一张牌失效。",

  [INVALID] = "矜策",
  ["#j_xuyou_jince-invoke"] = "矜策：是否令一名角色下一张牌失效？",
  ["#j_xuyou_jince-choose"] = "矜策：选择一名角色，其下一张牌失效",

  ["$j_xuyou_jince1"] = "谋定而后动，策出而敌摧！",
  ["$j_xuyou_jince2"] = "一策既出，万军辟易！",
}

-- 每回合限一次：走引擎的技能使用历史（useSkill 时自动记录，客户端亦同步）
local function withinTurnLimit(player)
  return player:usedSkillTimes(j_xuyou_jince.name, Player.HistoryTurn) == 0
end

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
    if not withinTurnLimit(player) then return end
    local cardName = "slash"
    if player:getSwitchSkillState(j_xuyou_jince.name) ~= fk.SwitchYang then
      cardName = "fire_attack"
    end
    local card = Fk:cloneCard(cardName)
    card.skillName = j_xuyou_jince.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    return withinTurnLimit(player)
  end,
})

-- 以此法使用的牌不可被响应
j_xuyou_jince:addEffect(fk.PreCardUse, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_xuyou_jince.name) then return false end
    return data.card ~= nil and data.card.skillName == j_xuyou_jince.name
  end,
  on_cost = function(self, event, target, player, data)
    -- 触发效果不参与阴阳转换：只有主动使用矜策才翻转
    event:setCostData(self, { no_switch = true })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.disresponsiveList = table.simpleClone(room.alive_players)
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
    for _, p in ipairs(player.room.alive_players) do
      if not p.dead then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local ok = room:askToSkillInvoke(player, {
      skill_name = j_xuyou_jince.name,
      prompt = "#j_xuyou_jince-invoke",
    })
    if ok then
      event:setCostData(self, { no_switch = true })
    end
    return ok
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
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xuyou_jince.name) then return false end
    local from = data and data.from
    if not from or from.dead then return false end
    return from:getMark(INVALID) > 0
  end,
  on_cost = function(self, event, target, player, data)
    event:setCostData(self, { no_switch = true })
    return true
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
    local eff = Fk.skills[j_xuyou_jince.name]:getSkeleton().effects[1]
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
    local eff = Fk.skills[j_xuyou_jince.name]:getSkeleton().effects[1]
    local card = eff:viewAs(me, { equip })
    lu.assertNotNil(card, "阴形态装备牌应可转化")
    lu.assertEquals(card.name, "fire_attack", "阴形态应转化为【火攻】")
  end)
end)

-- 测试3：造成伤害后令一名角色下一张牌失效，且触发效果不翻转阴阳
j_xuyou_jince:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jince.name)
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_xuyou_jince.name, 0)  -- 阳
    comp3.hp = comp3.maxHp
    local card = room:printCard("slash", Card.Spade, 5)
    card.skillName = j_xuyou_jince.name
    local dmg = DamageData:new{ from = me, to = comp3, damage = 1, damageType = fk.NormalDamage, card = card }
    FkTest.setNextReplies(me, { "1", { card = {}, targets = { comp2.id } } })
    room.logic:trigger(fk.Damaged, comp3, dmg)
    lu.assertTrue(comp2:getMark(INVALID) > 0, "目标应被标记为下一张牌失效")
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_jince.name), fk.SwitchYang,
      "触发效果不应翻转阴阳（仍应为阳）")
  end)
  FkTest.runInRoom(function()
    local slash = room:printCard("slash", Card.Club, 6)
    local use = { from = comp2, tos = { me }, card = slash, nullifiedTargets = {} }
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertTrue(table.contains(use.nullifiedTargets, me), "被标记的角色使用的牌应对目标无效")
    lu.assertEquals(comp2:getMark(INVALID), 0, "标记应在使用一张牌后清除")
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_jince.name), fk.SwitchYang,
      "无效牌效果不应翻转阴阳（仍应为阳）")
  end)
end)

-- 测试4：以此法使用的牌不可被响应（且不翻转阴阳）
j_xuyou_jince:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jince.name)
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_xuyou_jince.name, 0)
    local card = Fk:cloneCard("slash")
    card.skillName = j_xuyou_jince.name
    local use = UseCardData:new{ from = me, card = card, tos = {} }
    room.logic:trigger(fk.PreCardUse, me, use)
    lu.assertNotNil(use.disresponsiveList, "矜策转化的牌应不可被响应")
    lu.assertEquals(#use.disresponsiveList, #room.alive_players, "所有角色都不应能响应此牌")
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_jince.name), fk.SwitchYang,
      "不可响应效果不应翻转阴阳（仍应为阳）")
  end)
end)

-- 测试5：真实使用路径下阴阳正常交替（阳【杀】→ 阴【火攻】）
j_xuyou_jince:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jince.name)
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_xuyou_jince.name, 0)
    local c1 = room:printCard("qinggang_sword", Card.Spade, 3).id
    local c2 = room:printCard("eight_diagram", Card.Heart, 2).id
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")

    local u1 = room:handleUseCardReply(me, { card = { skill = j_xuyou_jince.name, subcards = { c1 } }, targets = {} }, {})
    lu.assertNotNil(u1, "第一次使用应返回UseCardData")
    lu.assertEquals(u1.card.name, "slash", "第一次（阳）应使用【杀】")
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_jince.name), fk.SwitchYin, "使用后应翻转为阴")
    lu.assertEquals(me:usedSkillTimes(j_xuyou_jince.name, Player.HistoryTurn), 1, "本回合已用一次")

    -- 模拟进入下一回合：清空本回合技能使用历史
    me.skillUsedHistory[j_xuyou_jince.name] = { 0, 0, 0, 0 }
    local u2 = room:handleUseCardReply(me, { card = { skill = j_xuyou_jince.name, subcards = { c2 } }, targets = {} }, {})
    lu.assertNotNil(u2, "第二次使用应返回UseCardData")
    lu.assertEquals(u2.card.name, "fire_attack", "第二次（阴）应使用【火攻】")
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_jince.name), fk.SwitchYang, "使用后应翻回阳")
  end)
end)

-- 测试6：每回合限一次
j_xuyou_jince:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jince.name)
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_xuyou_jince.name, 0)
    local c1 = room:printCard("qinggang_sword", Card.Spade, 3).id
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:useSkill(me, Fk.skills[j_xuyou_jince.name], function() end, { from = me, cards = { c1 }, tos = {} })
    lu.assertEquals(me:usedSkillTimes(j_xuyou_jince.name, Player.HistoryTurn), 1, "使用后应记录本回合已用")
    local eff = Fk.skills[j_xuyou_jince.name]:getSkeleton().effects[1]
    lu.assertNil(eff:viewAs(me, { c1 }), "本回合已用过后不应再转化出牌")
    lu.assertFalse(eff:enabledAtPlay(me), "本回合已用过后技能按钮应不可用")
  end)
end)

return j_xuyou_jince
