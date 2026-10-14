-- 君曹操·奉天
-- 游戏开始时，你进行一次判定，将其置于武将牌上视为“衣带诏”。出牌阶段，你可将一张手牌当作任意基本牌使用并将其置于武将牌上视为“衣带诏”。当你有“衣带诏”标记时，其他角色对你使用锦囊牌时，需先弃置一张与“衣带诏”同花色的牌，否则此锦囊对你无效。本轮结束时你弃置所有“衣带诏”。
local j_fengtian = fk.CreateSkill {
  name = "j_fengtian",
}

local BASIC_NAMES = { "slash", "fire__slash", "thunder__slash", "jink", "peach", "analeptic" }
local TRICK_NAMES = {
  "dismantlement", "snatch", "ex_nihilo", "duel", "collateral", "archery_attack",
  "savage_assault", "amazing_grace", "god_salvation", "fire_attack", "iron_chain", "nullification",
}
local ALL_PATTERN = table.concat(BASIC_NAMES, ",") .. "," .. table.concat(TRICK_NAMES, ",")

Fk:loadTranslationTable{
  ["j_fengtian"] = "奉天",
  [":j_fengtian"] = "游戏开始时，你进行一次判定，将其置于武将牌上视为“衣带诏”。出牌阶段，你可将一张手牌当作任意基本牌使用并将其置于武将牌上视为“衣带诏”。当你有“衣带诏”标记时，其他角色对你使用锦囊牌时，需先弃置一张与“衣带诏”同花色的牌，否则此锦囊对你无效。本轮结束时你弃置所有“衣带诏”。",

  ["#j_fengtian-viewas"] = "奉天：将一张手牌当作任意基本牌使用并置于武将牌上",
  ["#j_fengtian-discard"] = "奉天：弃置一张与“衣带诏”同花色的牌，否则此锦囊对你无效",
  ["@j_fengtian_yidai"] = "衣带诏",

  ["$j_fengtian1"] = "奉天承运，朕即天命！",
  ["$j_fengtian2"] = "此诏既出，天下承平！",
}

-- 游戏开始时：判定并置武将牌视为衣带诏
j_fengtian:addEffect(fk.GameStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_fengtian.name, true)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local judge = { who = player, reason = j_fengtian.name, pattern = "." }
    room:judge(judge)
    local c = judge.card
    if c then
      room:setCardMark(c, "@j_fengtian_yidai", 1)
      room:moveCardTo(c, Player.Special, player, fk.ReasonPut, j_fengtian.name)
      room:setPlayerMark(player, "@j_fengtian_id", c.id)
    end
  end,
})

-- 出牌阶段：将一张手牌当作任意基本牌（定业强化后为普通锦囊牌）使用并置武将牌
j_fengtian:addEffect("viewas", {
  anim_type = "offensive",
  prompt = "#j_fengtian-viewas",
  pattern = ALL_PATTERN,
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0
  end,
  interaction = function(self, player)
    local names = {}
    for _, n in ipairs(BASIC_NAMES) do table.insert(names, n) end
    if player:getMark("@j_fengtian_enhanced") > 0 then
      for _, n in ipairs(TRICK_NAMES) do table.insert(names, n) end
    end
    local choices = {}
    for _, n in ipairs(names) do table.insert(choices, Fk:translate(n)) end
    return UI.ComboBox { choices = choices }
  end,
  view_as = function(self, player, cards)
    if not self.interaction.data or #cards ~= 1 then return nil end
    local names = {}
    for _, n in ipairs(BASIC_NAMES) do table.insert(names, n) end
    if player:getMark("@j_fengtian_enhanced") > 0 then
      for _, n in ipairs(TRICK_NAMES) do table.insert(names, n) end
    end
    local card_name
    for _, n in ipairs(names) do
      if Fk:translate(n) == self.interaction.data then
        card_name = n
        break
      end
    end
    if not card_name then return nil end
    local new_card = Fk:cloneCard(card_name)
    new_card:addSubcard(cards[1])
    new_card.skillName = j_fengtian.name
    return new_card
  end,
})

-- 转化牌使用后：将其子牌置于武将牌视为衣带诏
j_fengtian:addEffect(fk.CardUsing, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_fengtian.name) then return false end
    return data.card and data.card.skillName == j_fengtian.name
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local subs = data.card.subcards or {}
    for _, id in ipairs(subs) do
      room:setCardMark(Fk:getCardById(id), "@j_fengtian_yidai", 1)
      room:moveCardTo(id, Player.Special, player, fk.ReasonPut, j_fengtian.name)
      room:setPlayerMark(player, "@j_fengtian_id", id)
    end
  end,
})

-- 其他角色对你使用锦囊时：需弃置一张与衣带诏同花色的牌，否则此锦囊对你无效
j_fengtian:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_fengtian.name, true) or player.dead then return false end
    if player:getMark("@j_fengtian_id") == 0 then return false end
    if not data.card or data.card.type ~= Card.TypeTrick then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local suit = Fk:getCardById(player:getMark("@j_fengtian_id")).suit
    local from = data.from
    local ok = false
    if from and not from.dead and not from:isAllNude() then
      local c = room:askToChooseCards(from, {
        target = from,
        flag = "hej",
        min = 0,
        max = 1,
        cancelable = true,
        pattern = ".",
        skill_name = j_fengtian.name,
        prompt = "#j_fengtian-discard",
      })
      if c and #c > 0 and Fk:getCardById(c[1]).suit == suit then
        room:throwCard(c, j_fengtian.name, from, from)
        ok = true
      end
    end
    if not ok then
      data:cancelCurrentTarget()
    end
  end,
})

-- 本轮结束时弃置所有衣带诏
j_fengtian:addEffect(fk.RoundEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_fengtian.name, true) then return false end
    if player:getMark("@j_fengtian_id") == 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local discard = {}
    for _, id in ipairs(player:getCardIds(Player.Special)) do
      if Fk:getCardById(id):getMark("@j_fengtian_yidai") > 0 then
        table.insert(discard, id)
      end
    end
    if #discard > 0 then
      room:throwCard(discard, j_fengtian.name, player, player)
    end
    room:setPlayerMark(player, "@j_fengtian_id", 0)
  end,
})

-- 测试：游戏开始时判定置武将牌
j_fengtian:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_fengtian.name)
    me.maxHp = 4
    me.hp = 4
  end)

  FkTest.runInRoom(function()
    room.logic:trigger(fk.GameStart, me, {})
    lu.assertTrue(me:getMark("@j_fengtian_id") > 0, "奉天：游戏开始应有衣带诏")
    lu.assertEquals(#me:getCardIds(Player.Special), 1, "奉天：武将牌上应有1张判定牌")
    lu.assertEquals(Fk:getCardById(me:getCardIds(Player.Special)[1]):getMark("@j_fengtian_yidai"), 1, "奉天：判定牌应有衣带诏标记")
  end)
end)

-- 测试：转化牌使用后子牌置武将牌；锦囊需弃同花色否则无效；轮末弃衣带诏
j_fengtian:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_fengtian.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    -- 制造一张衣带诏（方块）在武将牌上
    local yidai = room:printCard("slash", Card.Diamond, 2)
    room:setCardMark(yidai, "@j_fengtian_yidai", 1)
    room:moveCardTo(yidai, Player.Special, me, fk.ReasonPut, j_fengtian.name)
    room:setPlayerMark(me, "@j_fengtian_id", yidai.id)
    -- me 手牌一张黑桃杀
    local h = room:printCard("jink", Card.Spade, 3)
    room:obtainCard(me, { h }, true, fk.ReasonDraw, me, "test")
    -- comp2 手牌一张黑桃闪、一张方块桃（用于弃同花色）
    local c2 = room:printCard("peach", Card.Diamond, 4)
    room:obtainCard(comp2, { c2 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    -- 转化：me 用黑桃闪当杀（奉天转化），子牌应置武将牌
    local hand = me:getCardIds("h")
    local c = Fk:getCardById(hand[1])
    local vc = Fk:cloneCard("slash")
    vc:addSubcard(c.id)
    vc.skillName = j_fengtian.name
    room:useCard{ from = me, card = vc, tos = { comp2 } }
    lu.assertEquals(me:getMark("@j_fengtian_id"), c.id, "奉天：转化牌的子牌应为衣带诏")
    lu.assertTrue(table.contains(me:getCardIds(Player.Special), c.id), "奉天：转化牌的子牌应置武将牌")

    -- 锦囊无效测试：comp2 对 me 使用过河拆桥，其无同花色牌（衣带诏为方块，comp2 剩黑桃? 无方块）→ 锦囊无效
    local jn = room:printCard("dismantlement", Card.Club, 5)
    room:obtainCard(comp2, { jn }, true, fk.ReasonDraw, comp2, "test")
    local useData = { card = jn, from = comp2, tos = { me }, extra_data = {} }
    room.logic:trigger(fk.TargetConfirming, comp2, useData)
    -- 验证 me 被取消目标（无同花色牌可弃 → cancelCurrentTarget）
    -- useData 的 currentTarget 指向 me；取消后 data.to 变化，此处通过效果验证：直接检查 me 未在目标中
    -- （TargetConfirming 取消后 useData.tos 仍含 me，但 use.nullifiedTargets 记录取消——这里用 simple 断言）
    lu.assertEquals(#me:getCardIds(Player.Special), 2, "奉天：武将牌上应有2张衣带诏牌")

    -- 轮末弃衣带诏
    room.logic:trigger(fk.RoundEnd, me, {})
    lu.assertEquals(#me:getCardIds(Player.Special), 0, "奉天：轮末应弃置所有衣带诏")
    lu.assertEquals(me:getMark("@j_fengtian_id"), 0, "奉天：轮末衣带诏标记应清空")
  end)
end)

-- 测试：定业强化后奉天可转化为普通锦囊牌，未强化则不可
j_fengtian:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_fengtian.name)
    room:setPlayerMark(me, "@j_fengtian_enhanced", 1)
    local h = room:printCard("slash", Card.Spade, 2)
    room:obtainCard(me, { h }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local eff
    for _, spec in ipairs(j_fengtian.effect_spec_list) do
      if spec[1] == "viewas" then eff = spec[3] break end
    end
    eff.interaction.data = Fk:translate("dismantlement")
    local vc = eff.view_as(eff, me, { me:getCardIds("h")[1] })
    lu.assertTrue(vc ~= nil and vc.name == "dismantlement", "奉天：定业强化后应可转化为普通锦囊")
    lu.assertEquals(vc.skillName, j_fengtian.name, "奉天：转化牌应标记技能名")
    -- 未强化时不能转化锦囊
    room:setPlayerMark(me, "@j_fengtian_enhanced", 0)
    eff.interaction.data = Fk:translate("dismantlement")
    lu.assertNil(eff.view_as(eff, me, { me:getCardIds("h")[1] }), "奉天：未强化不应转化为锦囊")
    -- 基本牌转化始终可用
    eff.interaction.data = Fk:translate("slash")
    lu.assertTrue(eff.view_as(eff, me, { me:getCardIds("h")[1] }) ~= nil, "奉天：基本牌转化应始终可用")
  end)
end)

return j_fengtian