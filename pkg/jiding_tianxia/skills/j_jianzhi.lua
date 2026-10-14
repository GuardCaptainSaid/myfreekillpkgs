local j_jianzhi = fk.CreateSkill {
  name = "j_jianzhi",
}

Fk:loadTranslationTable{
  ["j_jianzhi"] = "间智",
  [":j_jianzhi"] = "每种牌名限一次，当你成为一张牌的目标时，你记录该牌牌名；当你使用牌被抵消时，你记录抵消牌的牌名。你可以将一张“间谋”牌当作已记录的牌名使用并移除一种记录的牌名。",
}

-- 已记录牌名存储（玩家 mark，同步到客户端；interaction/enabled_at_play 客户端会读）
local function get_records(player)
  return player:getTableMark("@@j_jianzhi_records")
end

local function add_record(player, name)
  local records = get_records(player)
  if not table.contains(records, name) then
    table.insert(records, name)
    player.room:setPlayerMark(player, "@@j_jianzhi_records", records)
  end
end

local function remove_record(player, name)
  local records = get_records(player)
  if table.contains(records, name) then
    records = table.filter(records, function(n) return n ~= name end)
    player.room:setPlayerMark(player, "@@j_jianzhi_records", records)
  end
end

-- 成为一张牌的目标时：记录该牌牌名（每种牌名限一次）
j_jianzhi:addEffect(fk.TargetConfirmed, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianzhi.name) then return false end
    if player.dead then return false end
    if data.to ~= player then return false end
    if not data.card then return false end
    local name = data.card.trueName
    if name == nil or name == "" then return false end
    return not table.contains(get_records(player), name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    add_record(player, data.card.trueName)
  end,
})

-- 你使用牌被抵消时：记录抵消牌的牌名（每种牌名限一次）
j_jianzhi:addEffect(fk.CardRespondFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianzhi.name) then return false end
    if player.dead then return false end
    -- data.from 为响应者，data.card 为响应牌（抵消牌），data.responseToEvent 为被响应事件
    if not data.responseToEvent then return false end
    local use = data.responseToEvent.use
    if not use or use.from ~= player then return false end
    local name = data.card and data.card.trueName
    if name == nil or name == "" then return false end
    return not table.contains(get_records(player), name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    add_record(player, data.card.trueName)
  end,
})

-- 将一张“间谋”牌当作已记录的牌名使用并移除一种记录的牌名
j_jianzhi:addEffect("viewas", {
  anim_type = "offensive",
  card_num = 1,
  card_filter = function(self, player, to_select, selected, selected_targets)
    if #selected >= 1 then return false end
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    return Fk:getCardById(to_select):getMark("@@j_jianmou-inhand") > 0
  end,
  interaction = function(self, player)
    local records = get_records(player)
    if #records == 0 then return nil end
    return UI.CardNameBox { choices = records, all_choices = records }
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    if not self.interaction.data then return end
    local name = self.interaction.data
    if not table.contains(get_records(player), name) then return end
    local card = Fk:cloneCard(name)
    card.skillName = j_jianzhi.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    -- 客户端也会执行此判定，须用 mark（同步到客户端）
    return #get_records(player) > 0
  end,
  after_use = function(self, player, use)
    local used = self.interaction.data
    if used then
      remove_record(player, used)
    end
  end,
})

-- 测试：成为目标时记录牌名（每种一次）
j_jianzhi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianzhi.name)
  end)
  FkTest.runInRoom(function()
    local aim = AimData:new{ from = comp2, card = Fk:cloneCard("slash", Card.Spade, 5), tos = { me }, to = me }
    room.logic:trigger(fk.TargetConfirmed, me, aim)
    lu.assertTrue(table.contains(me:getTableMark("@@j_jianzhi_records"), "slash"), "应记录杀牌名")
  end)
end)

-- 测试：使用牌被抵消时记录抵消牌的牌名
j_jianzhi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianzhi.name)
  end)
  FkTest.runInRoom(function()
    local use = UseCardData:new{ from = me, card = Fk:cloneCard("slash"), tos = {} }
    local effect = CardEffectData:new{ use = use }
    local resp = RespondCardData:new{ from = comp2, card = Fk:cloneCard("jink"), responseToEvent = effect }
    room.logic:trigger(fk.CardRespondFinished, comp2, resp)
    lu.assertTrue(table.contains(me:getTableMark("@@j_jianzhi_records"), "jink"), "应记录抵消牌（闪）牌名")
  end)
end)

-- 测试：将一张“间谋”牌当作已记录的牌名使用并移除记录
j_jianzhi:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianzhi.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_jianmou-inhand", 1)
    room:setPlayerMark(me, "@@j_jianzhi_records", { "slash" })
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_jianzhi.name]:getSkeleton()
    local eff
    for _, e in ipairs(skel.effects) do
      if e.viewAs then eff = e break end
    end
    lu.assertNotNil(eff, "应存在 viewas 效果实例")
    -- 引擎中 interaction 为可调用对象且交互后写入 .data；测试直接模拟该数据
    eff.interaction = { data = "slash" }
    local card = eff:viewAs(me, { c1.id })
    lu.assertNotNil(card, "间谋牌应能转化为已记录的牌名")
    lu.assertEquals(card.name, "slash")
    lu.assertEquals(card.skillName, "j_jianzhi")

    local use = UseCardData:new{ from = me, card = card, tos = {} }
    eff:afterUse(me, use)
    lu.assertFalse(table.contains(me:getTableMark("@@j_jianzhi_records"), "slash"), "使用后应移除该记录")
  end)
end)

return j_jianzhi