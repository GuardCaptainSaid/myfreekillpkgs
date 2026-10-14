local j_zhiji = fk.CreateSkill {
  name = "j_zhiji",
}

Fk:loadTranslationTable{
  ["j_zhiji"] = "智计",
  [":j_zhiji"] = "每回限一次，你可以将一张红色/黑色牌当做不能被抵消的【火攻】/【无懈可击】使用。",

  ["#j_zhiji-prompt"] = "智计：将一张红色牌当【火攻】或将一张黑色牌当【无懈可击】使用",

  ["$j_zhiji1"] = "计出万全，算无遗策！",
  ["$j_zhiji2"] = "运筹帷幄，决胜千里！",
}

-- 智计：红牌→火攻、黑牌→无懈可击，不能被抵消
j_zhiji:addEffect("viewas", {
  anim_type = "offensive",
  card_num = 1,
  card_filter = function(self, player, to_select, selected, selected_targets)
    if #selected >= 1 then return false end
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    local card = Fk:getCardById(to_select)
    if card.color == Card.NoColor then return false end
    if self.interaction.data == "fire_attack" then
      return card.color == Card.Red
    elseif self.interaction.data == "nullification" then
      return card.color == Card.Black
    end
    return true
  end,
  interaction = function(self, player)
    return UI.CardNameBox { choices = { "fire_attack", "nullification" }, all_choices = { "fire_attack", "nullification" } }
  end,
  view_as = function(self, player, cards)
    if player:getMark("j_zhiji_used") ~= 0 then return end
    if #cards ~= 1 or not self.interaction.data then return end
    local card = Fk:cloneCard(self.interaction.data)
    card.skillName = j_zhiji.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    return player:getMark("j_zhiji_used") == 0
  end,
  after_use = function(self, player, use)
    player.room:setPlayerMark(player, "j_zhiji_used", 1)
  end,
})

-- 智计转化的牌不能被抵消（不可被响应）
j_zhiji:addEffect(fk.PreCardUse, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zhiji.name) then return false end
    if not data.card or data.card.skillName ~= j_zhiji.name then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data.disresponsiveList = table.simpleClone(player.room.players)
  end,
})

-- 每回合开始重置限次
j_zhiji:addEffect(fk.EventPhaseStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_zhiji.name) and player.phase == Player.Play
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_zhiji_used", 0)
  end,
})

-- 辅助：取某玩家的红牌
local function redCardOf(p)
  for _, id in ipairs(p:getCardIds("h")) do
    if Fk:getCardById(id).color == Card.Red then return id end
  end
end

-- 测试：红牌可当火攻、黑牌可当无懈可击；转化牌不可被响应
j_zhiji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhiji.name)
    local c1 = room:printCard("slash", Card.Heart, 7)   -- 红牌
    local c2 = room:printCard("jink", Card.Spade, 6)    -- 黑牌
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)

  -- 场景A：红牌 → 火攻
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_zhiji.name]:getSkeleton()
    local eff = skel.effects[1]
    local hand = me:getCardIds("h")
    local redCard = nil
    for _, id in ipairs(hand) do
      if Fk:getCardById(id).color == Card.Red then redCard = id break end
    end
    lu.assertNotNil(redCard, "应有红牌")
    -- interaction 选择火攻
    eff.interaction.data = "fire_attack"
    lu.assertTrue(eff:cardFilter(me, redCard, {}, {}), "红牌应可当火攻")
    local vcard = eff:viewAs(me, { redCard })
    lu.assertNotNil(vcard, "应能转化出火攻")
    lu.assertEquals(vcard.trueName, "fire_attack", "转化牌应为火攻")
    lu.assertEquals(vcard.skillName, j_zhiji.name, "转化牌应带技能名")
    -- 黑牌不能当火攻
    local blackCard = nil
    for _, id in ipairs(hand) do
      if Fk:getCardById(id).color == Card.Black then blackCard = id break end
    end
    lu.assertFalse(eff:cardFilter(me, blackCard, {}, {}), "黑牌不能当火攻")
  end)

  -- 场景B：黑牌 → 无懈可击
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_zhiji.name]:getSkeleton()
    local eff = skel.effects[1]
    eff.interaction.data = "nullification"
    local blackCard = nil
    for _, id in ipairs(me:getCardIds("h")) do
      if Fk:getCardById(id).color == Card.Black then blackCard = id break end
    end
    lu.assertNotNil(blackCard, "应有黑牌")
    lu.assertTrue(eff:cardFilter(me, blackCard, {}, {}), "黑牌应可当无懈可击")
    local vcard = eff:viewAs(me, { blackCard })
    lu.assertNotNil(vcard, "应能转化出无懈可击")
    lu.assertEquals(vcard.trueName, "nullification", "转化牌应为无懈可击")
    lu.assertFalse(eff:cardFilter(me, redCardOf(me), {}, {}), "红牌不能当无懈可击")
  end)

  -- 场景C：使用智计转化牌时，该牌不可被响应
  FkTest.runInRoom(function()
    room:setPlayerMark(me, "j_zhiji_used", 0)
    local vcard = Fk:cloneCard("fire_attack")
    vcard.skillName = j_zhiji.name
    vcard:addSubcard(me:getCardIds("h")[1])
    local use = UseCardData:new{ from = me, card = vcard, tos = { room.players[2] } }
    room.logic:trigger(fk.PreCardUse, me, use)
    lu.assertTrue(use.disresponsiveList ~= nil and #use.disresponsiveList > 0, "智计转化牌应不可被响应")
  end)

  -- 场景D：限次（使用后标记为1，不能再用；新回合重置）
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_zhiji.name]:getSkeleton()
    local eff = skel.effects[1]
    room:setPlayerMark(me, "j_zhiji_used", 1)
    lu.assertFalse(eff:enabledAtPlay(me), "使用后本回合不能再发动")
    -- 回合开始重置
    me.phase = Player.Play
    room.logic:trigger(fk.EventPhaseStart, me, {})
    lu.assertEquals(me:getMark("j_zhiji_used"), 0, "新回合应重置限次")
  end)
end)

return j_zhiji