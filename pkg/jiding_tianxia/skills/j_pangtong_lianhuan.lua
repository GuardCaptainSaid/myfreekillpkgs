-- 计庞统·连环
-- 出牌阶段，你可将一张黑色牌当【铁索连环】使用或重铸。
-- 每回合限一次，当你的武将牌横置后，你可摸X张牌并受到1点无来源的火焰伤害（X为场上已横置的角色数）。
local j_pangtong_lianhuan = fk.CreateSkill {
  name = "j_pangtong_lianhuan",
}

local USED = "j_pangtong_lianhuan_used-turn"  -- 每回合限一次（纯内部标记）

Fk:loadTranslationTable{
  ["j_pangtong_lianhuan"] = "连环",
  [":j_pangtong_lianhuan"] = "出牌阶段，你可以将一张黑色牌当【铁索连环】使用或重铸。每回合限一次，" ..
    "当你的武将牌横置后，你可以摸X张牌并受到1点无来源的火焰伤害（X为场上已横置的角色数）。",

  ["#j_pangtong_lianhuan"] = "连环：将一张黑色牌当【铁索连环】使用，或不选目标直接“确定”重铸",
  ["#j_pangtong_lianhuan-invoke"] = "连环：是否摸X张牌并受到1点无来源的火焰伤害？",

  ["$j_pangtong_lianhuan1"] = "赤壁之策，尽在连环。",
  ["$j_pangtong_lianhuan2"] = "一索相连，进退同命。",
}

-- 将一张黑色牌当【铁索连环】使用 / 重铸
j_pangtong_lianhuan:addEffect("active", {
  mute = true,
  prompt = "#j_pangtong_lianhuan",
  card_num = 1,
  include_equip = true,
  min_target_num = 0,
  can_use = Util.TrueFunc,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).color == Card.Black
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    if #selected_cards == 1 then
      local card = Fk:cloneCard("iron_chain")
      card:addSubcard(selected_cards[1])
      card.skillName = j_pangtong_lianhuan.name
      return player:canUse(card) and card.skill:targetFilter(player, to_select, selected, selected_cards, card, nil)
    end
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    player:broadcastSkillInvoke(j_pangtong_lianhuan.name)
    if #effect.tos == 0 then
      -- 不选目标 → 重铸
      room:notifySkillInvoked(player, j_pangtong_lianhuan.name, "drawcard")
      room:recastCard(effect.cards, player, j_pangtong_lianhuan.name)
    else
      room:notifySkillInvoked(player, j_pangtong_lianhuan.name, "control")
      room:sortByAction(effect.tos)
      room:useVirtualCard("iron_chain", effect.cards, player, effect.tos, j_pangtong_lianhuan.name)
    end
  end,
})

-- 武将牌横置后：摸X张牌（X=场上已横置角色数），然后受到1点无来源火焰伤害
j_pangtong_lianhuan:addEffect(fk.ChainStateChanged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or not player:hasSkill(j_pangtong_lianhuan.name) then return false end
    if not player.chained then return false end
    return player:getMark(USED) == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_pangtong_lianhuan.name,
      prompt = "#j_pangtong_lianhuan-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, USED, 1)

    local x = 0
    for _, p in ipairs(room.alive_players) do
      if p.chained then x = x + 1 end
    end
    if x > 0 then
      room:drawCards(player, x, j_pangtong_lianhuan.name)
    end
    if player.dead then return end
    room:damage{
      to = player,
      damage = 1,
      damageType = fk.FireDamage,
      skillName = j_pangtong_lianhuan.name,
    }
  end,
})

-- 测试1：黑色牌可转化，红色/基本牌以外的非黑色不可选
j_pangtong_lianhuan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_lianhuan.name)
    me.phase = Player.Play
    local black = room:printCard("slash", Card.Spade, 3)
    local black2 = room:printCard("dismantlement", Card.Club, 4)
    local red = room:printCard("slash", Card.Heart, 5)
    room:obtainCard(me, { black.id, black2.id, red.id }, true, fk.ReasonDraw, me, "test")

    local eff = j_pangtong_lianhuan.effects[1]
    lu.assertTrue(eff:cardFilter(me, black.id, {}), "黑桃牌应可转化")
    lu.assertTrue(eff:cardFilter(me, black2.id, {}), "梅花牌应可转化")
    lu.assertFalse(eff:cardFilter(me, red.id, {}), "红桃牌不可转化")
    lu.assertFalse(eff:cardFilter(me, black.id, { red.id }), "只允许选一张")
  end)
end)

-- 测试2：不选目标 → 重铸
j_pangtong_lianhuan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_lianhuan.name)
    me.phase = Player.Play
    local black = room:printCard("slash", Card.Spade, 3)
    room:obtainCard(me, { black.id }, true, fk.ReasonDraw, me, "test")

    local recast_ids, use_args
    local origRecast = room.recastCard
    local origUse = room.useVirtualCard
    room.recastCard = function(self, ids, who, skill) recast_ids = ids; end
    room.useVirtualCard = function(self, name, subcards, from, tos, skill) use_args = { name, subcards, from, tos }; end

    local eff = j_pangtong_lianhuan.effects[1]
    eff:onUse(room, { from = me, tos = {}, cards = { black.id } })
    room.recastCard = origRecast
    room.useVirtualCard = origUse

    lu.assertNotNil(recast_ids, "不选目标应走重铸")
    lu.assertEquals(recast_ids[1], black.id, "重铸的应是选中的黑色牌")
    lu.assertNil(use_args, "重铸时不应使用虚拟牌")
  end)
end)

-- 测试3：选了目标 → 真实视为使用【铁索连环】，目标被横置
j_pangtong_lianhuan:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_lianhuan.name)
    me.phase = Player.Play
    comp.hp = comp.maxHp
    comp.chained = false
    local black = room:printCard("slash", Card.Spade, 3)
    room:obtainCard(me, { black.id }, true, fk.ReasonDraw, me, "test")

    local eff = j_pangtong_lianhuan.effects[1]
    eff:onUse(room, { from = me, tos = { comp }, cards = { black.id } })

    lu.assertTrue(comp.chained, "目标应被【铁索连环】横置")
  end)
end)

-- 测试4：横置后摸X张并受到1点无来源火焰伤害，且每回合限一次
j_pangtong_lianhuan:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_lianhuan.name)
    me.hp = me.maxHp
    me.chained = true
    comp.chained = true
    room:setPlayerMark(me, USED, 0)

    local before = #me:getCardIds("h")
    local hp_before = me.hp
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.ChainStateChanged, me, {})
    lu.assertEquals(#me:getCardIds("h"), before + 2, "横置角色数为2，应摸两张")
    lu.assertEquals(me.hp, hp_before - 1, "应受到1点火焰伤害")
    lu.assertTrue(me:getMark(USED) > 0, "应记录每回合限一次")

    -- 第二次横置不再触发
    local before2 = #me:getCardIds("h")
    room.logic:trigger(fk.ChainStateChanged, me, {})
    lu.assertEquals(#me:getCardIds("h"), before2, "每回合限一次，不应再次摸牌")
  end)
end)

-- 测试5：与涅槃联动——横置摸牌后火伤致濒死，涅槃阳形态回复至上限并复原武将牌
j_pangtong_lianhuan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_pangtong_lianhuan.name, "j_pangtong_niepan" })
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. "j_pangtong_niepan", 0)  -- 涅槃阳形态
    room:setPlayerMark(me, USED, 0)
    me.hp = 1
    me.chained = true

    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.ChainStateChanged, me, {})

    lu.assertEquals(me.hp, me.maxHp, "火伤致濒死后应被涅槃回复至上限")
    lu.assertFalse(me.chained, "涅槃应将武将牌复原")
    lu.assertEquals(me:getSwitchSkillState("j_pangtong_niepan"), fk.SwitchYin,
      "涅槃发动后应翻转为阴形态")
  end)
end)

return j_pangtong_lianhuan
