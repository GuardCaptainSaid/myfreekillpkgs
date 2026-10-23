-- 计枣祗·广济
-- 每轮每种牌名限两次，你可以将任意张牌当作一张牌名字数与所用牌数相等的普通锦囊牌使用。
local j_guangji = fk.CreateSkill {
  name = "j_guangji",
}

local function utf8len(s)
  local len, i = 0, 1
  while i <= #s do
    local b = string.byte(s, i)
    if b < 128 then i = i + 1
    elseif b < 224 then i = i + 2
    elseif b < 240 then i = i + 3
    else i = i + 4 end
    len = len + 1
  end
  return len
end

local LIMIT = 2
local TRICKS_MARK = "j_guangji_tricks"

local function nameMark(name)
  return "j_guangji_" .. name .. "-round"
end

Fk:loadTranslationTable{
  ["j_guangji"] = "广济",
  [":j_guangji"] = "每轮每种牌名限两次，你可以将任意张牌当作一张牌名字数与所用牌数相等的普通锦囊牌使用。",

  ["#j_guangji"] = "广济：选择要当作使用的普通锦囊牌，再选择与其牌名字数等量的手牌",
}

-- 只收集“本局已加入游戏”的普通锦囊牌名（项目约定：不可印牌）
local function inGameCommonTricks(room)
  local names = {}
  local function add(ids)
    for _, id in ipairs(ids or {}) do
      local card = Fk:getCardById(id)
      if card and card.trueName and card.trueName ~= ""
        and Fk.all_card_types[card.trueName]
        and card.type == Card.TypeTrick and card.sub_type ~= Card.SubtypeDelayedTrick then
        table.insertIfNeed(names, card.trueName)
      end
    end
  end
  add(room.draw_pile)
  add(room.discard_pile)
  add(room.processing_area)
  for _, p in ipairs(room.players) do
    add(p:getCardIds("hej"))
  end
  return names
end

-- 刷新候选牌名（客户端读不到牌堆，必须写进玩家标记同步）
local function refreshTricks(room)
  for _, p in ipairs(room.players) do
    if p:hasSkill(j_guangji.name) then
      room:setPlayerMark(p, TRICKS_MARK, inGameCommonTricks(room))
    end
  end
end

-- 由下拉框显示的翻译名反查真实牌名
local function resolveName(player, data)
  if type(data) ~= "string" or data == "" then return nil end
  for _, n in ipairs(player:getTableMark(TRICKS_MARK)) do
    if Fk:translate(n) == data then return n end
  end
  return nil
end

-- 本轮该牌名已使用次数
local function usedTimes(player, name)
  return player:getMark(nameMark(name))
end

j_guangji:addEffect("viewas", {
  anim_type = "control",
  prompt = "#j_guangji",
  card_filter = function(self, player, to_select, selected)
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    local name = resolveName(player, self.interaction and self.interaction.data)
    if not name then return false end
    return #selected < utf8len(Fk:translate(name))
  end,
  interaction = function(self, player)
    local choices = {}
    for _, n in ipairs(player:getTableMark(TRICKS_MARK)) do
      if usedTimes(player, n) < LIMIT then
        table.insert(choices, Fk:translate(n))
      end
    end
    if #choices == 0 then return end
    -- 给定默认项，保证立即有牌可选（选牌数由牌名字数决定）
    return UI.ComboBox { choices = choices, default = choices[1] }
  end,
  view_as = function(self, player, cards)
    if #cards == 0 then return nil end
    local name = resolveName(player, self.interaction and self.interaction.data)
    if not name or Fk.all_card_types[name] == nil then return nil end
    -- 所用牌数必须等于牌名字数
    if #cards ~= utf8len(Fk:translate(name)) then return nil end
    local card = Fk:cloneCard(name)
    if not card then return nil end
    card.skillName = j_guangji.name
    card:addSubcards(cards)
    return card
  end,
  can_use = function(self, player)
    return #player:getTableMark(TRICKS_MARK) > 0
  end,
  enabled_at_play = function(self, player)
    return #player:getTableMark(TRICKS_MARK) > 0
  end,
})

-- 轮次开始 / 回合开始：刷新候选牌名
j_guangji:addEffect(fk.RoundStart, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_guangji.name)
  end,
  on_use = function(self, event, target, player, data)
    refreshTricks(player.room)
  end,
})

j_guangji:addEffect(fk.TurnStart, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_guangji.name)
  end,
  on_use = function(self, event, target, player, data)
    refreshTricks(player.room)
  end,
})

-- 使用后记录该牌名本轮使用次数（每轮每种牌名限两次）
j_guangji:addEffect(fk.CardUsing, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_guangji.name) then return false end
    local card = data and data.card
    if not card or card.type ~= Card.TypeTrick then return false end
    local sn = card.skillName
    if sn == j_guangji.name then return true end
    if type(sn) == "string" and string.sub(sn, 1, 10) == "#j_guangji" then return true end
    -- 兜底：【倡制】禁止其使用实体锦囊牌，故其使用的锦囊必然来自【广济】
    return not not card:isVirtual()
  end,
  on_use = function(self, event, target, player, data)
    local name = data.card and data.card.trueName
    if not name or name == "" then return end
    player.room:addPlayerMark(player, nameMark(name), 1)
  end,
})

-- 测试：牌名字数与所用牌数相等才能转化；次数用尽后不再出现在候选中
j_guangji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guangji.name)
    refreshTricks(room)
    room:obtainCard(me, {
      room:printCard("slash", Card.Spade, 5),
      room:printCard("jink", Card.Heart, 6),
    }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local sk = Fk.skills[j_guangji.name]
    local skel = sk.getSkeleton and sk:getSkeleton() or sk
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "viewas" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 viewas 效果")

    -- 找一张候选中名为2字的牌（如【决斗】），2张手牌可转化，1张不可
    local two = nil
    for _, n in ipairs(me:getTableMark(TRICKS_MARK)) do
      if utf8len(Fk:translate(n)) == 2 then two = n break end
    end
    if two then
      local ids = me:getCardIds("h")
      spec.interaction.data = Fk:translate(two)
      lu.assertNil(spec:view_as(me, { ids[1] }), "1张牌不能当作2字牌使用")
      local card = spec:view_as(me, { ids[1], ids[2] })
      lu.assertNotNil(card, "2张牌应可当作2字普通锦囊使用")
      if card then lu.assertEquals(card.trueName, two, "转化出的牌名应一致") end
    end
  end)
end)

-- 测试：每种牌名每轮限两次
j_guangji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guangji.name)
    refreshTricks(room)
  end)
  FkTest.runInRoom(function()
    local name = (me:getTableMark(TRICKS_MARK))[1]
    lu.assertNotNil(name, "应有候选牌名")
    room:addPlayerMark(me, nameMark(name), 2)
    local sk = Fk.skills[j_guangji.name]
    local skel = sk.getSkeleton and sk:getSkeleton() or sk
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "viewas" then spec = sp[3] break end
    end
    local inter = spec:interaction(me)
    lu.assertNotNil(inter, "应返回下拉框")
    lu.assertFalse(table.contains(inter.choices, Fk:translate(name)), "已达两次的牌名不应再出现在候选中")
  end)
end)

return j_guangji
