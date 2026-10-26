-- 计毛玠·六察
-- 出牌阶段限三次，你可以弃置一张牌：
--   基本牌：令一名角色摸一张牌，或弃置一张牌；
--   装备牌：令一名角色本回合不因此失去基本牌后，随机弃置一张牌；
--   锦囊牌：令一名其它角色视为使用一张普通锦囊牌（此牌的牌名与目标由你指定）。
local j_maojie_liucha = fk.CreateSkill {
  name = "j_maojie_liucha",
}

Fk:loadTranslationTable{
  ["j_maojie_liucha"] = "六察",
  [":j_maojie_liucha"] = "出牌阶段限三次，你可以弃置一张牌：若为基本牌，令一名角色摸一张牌，或弃置一张牌；" ..
    "若为装备牌，令一名角色本回合不因此失去基本牌后，随机弃置一张牌；" ..
    "若为锦囊牌，令一名其它角色视为使用一张普通锦囊牌（此牌的牌名与目标由你指定）。",

  ["#j_maojie_liucha-prompt"] = "六察：弃置一张牌，根据其类别发动效果（出牌阶段限三次）",
  ["#j_maojie_liucha-discard"] = "六察：请弃置一张牌",
  ["#j_maojie_liucha-basic"] = "六察：令一名角色摸一张牌，或弃置一张牌？",
  ["#j_maojie_liucha-draw"] = "令其摸一张牌",
  ["#j_maojie_liucha-throw"] = "令其弃置一张牌",
  ["#j_maojie_liucha-choose_basic"] = "六察：选择一名角色",
  ["#j_maojie_liucha-choose_equip"] = "六察：选择一名角色（其本回合不会因六察失去基本牌，然后随机弃置一张牌）",
  ["#j_maojie_liucha-choose_trick"] = "六察：选择一名其他角色（其视为使用一张普通锦囊牌）",
  ["#j_maojie_liucha-name"] = "六察：选择一张普通锦囊牌",
  ["#j_maojie_liucha-target"] = "六察：为此牌指定目标（可多选）",
  ["#j_maojie_liucha-target_discard"] = "六察：请弃置一张牌",

  ["@@j_maojie_liucha_dun-turn"] = "庇护",
}

-- 本回合不会因「六察」失去基本牌
local DUN_MARK = "@@j_maojie_liucha_dun-turn"

-- 只收集中已加入本局游戏的牌名：牌堆、弃牌堆、处理区、以及所有角色的手牌/装备/判定区。
-- 避免"印"出本局并不存在的牌。
local function inGameNames(room, matchFunc)
  local names = {}
  local function add(ids)
    for _, id in ipairs(ids or {}) do
      local card = Fk:getCardById(id)
      if card and card.trueName and card.trueName ~= ""
        and Fk.all_card_types[card.trueName]
        and matchFunc(card) then
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

local function hasDun(p)
  return p:getMark(DUN_MARK) > 0
end

-- 随机弃置一张手牌；若目标处于「庇护」状态，则不会弃到基本牌
local function randomDiscard(room, target, proposer, skillName)
  local hand = target:getCardIds("h")
  if #hand == 0 then return end
  local pool = hand
  if hasDun(target) then
    pool = table.filter(hand, function(id)
      return Fk:getCardById(id).type ~= Card.TypeBasic
    end)
  end
  if #pool == 0 then return end
  local id = room:tableRandomPick(pool)
  if id then
    room:throwCard({ id }, skillName, target, proposer)
  end
end

-- 由目标自己弃置一张牌（有庇护时改为随机弃非基本牌）
local function askDiscard(room, target, proposer, skillName)
  if hasDun(target) then
    randomDiscard(room, target, proposer, skillName)
    return
  end
  if #target:getCardIds("he") == 0 then return end
  room:askToDiscard(target, {
    min_num = 1,
    max_num = 1,
    include_equip = true,
    skill_name = skillName,
    prompt = "#j_maojie_liucha-target_discard",
    cancelable = false,
  })
end

-- 令 target 视为使用一张普通锦囊牌，牌名与目标由 player 指定
local function useTrickBy(room, player, target, skillName)
  local names = inGameNames(room, function(card)
    return card.type == Card.TypeTrick
      and card.sub_type ~= Card.SubtypeDelayedTrick
      and not card.is_passive
  end)
  if #names == 0 then return end

  local name = room:askToChoice(player, {
    choices = names,
    skill_name = skillName,
    prompt = "#j_maojie_liucha-name",
    cancelable = true,
  })
  if not name or name == "" or name == "Cancel" then return end
  if not Fk.all_card_types[name] then return end

  local card = Fk:cloneCard(name)
  card.skillName = skillName
  local extra = { bypass_times = true, bypass_distances = true }
  local avail = card:getAvailableTargets(target, extra)
  local tos
  if #avail > 0 then
    tos = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = #avail,
      targets = avail,
      skill_name = skillName,
      prompt = "#j_maojie_liucha-target",
      cancelable = true,
    })
    if not tos or #tos == 0 then return end
  else
    tos = card:getDefaultTarget(target, extra)
  end
  if not tos or #tos == 0 then return end
  if target.dead or player.dead then return end

  room:useCard({
    from = target,
    tos = tos,
    card = card,
    extraUse = true,
  })
end

j_maojie_liucha:addEffect("active", {
  anim_type = "offensive",
  prompt = "#j_maojie_liucha-prompt",
  -- 出牌阶段限三次
  max_phase_use_time = 3,
  can_use = function(self, player)
    -- 客户端（ClientPlayer 无 room 字段）不做阶段判断，交给引擎的按钮显示时机
    if player.room and player.phase ~= Player.Play then return false end
    return #player:getCardIds("he") > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if not player or player.dead then return end
    local skillName = j_maojie_liucha.name

    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skillName,
      prompt = "#j_maojie_liucha-discard",
      cancelable = false,
    })
    if not cards or #cards == 0 then return end
    local card = Fk:getCardById(cards[1])
    if not card then return end

    if card.type == Card.TypeBasic then
      -- 基本牌：令一名角色摸一张牌，或弃置一张牌
      local choices = { "#j_maojie_liucha-draw", "#j_maojie_liucha-throw" }
      local choice = room:askToChoice(player, {
        choices = choices,
        skill_name = skillName,
        prompt = "#j_maojie_liucha-basic",
        cancelable = false,
      })
      local targets = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = 1,
        targets = room.alive_players,
        skill_name = skillName,
        prompt = "#j_maojie_liucha-choose_basic",
        cancelable = false,
      })
      if not targets or #targets == 0 then return end
      local to = targets[1]
      if to.dead then return end
      if choice == choices[1] then
        room:drawCards(to, 1, skillName)
      else
        askDiscard(room, to, player, skillName)
      end

    elseif card.type == Card.TypeEquip then
      -- 装备牌：令一名角色本回合不因此失去基本牌，然后随机弃置一张牌
      local targets = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = 1,
        targets = room.alive_players,
        skill_name = skillName,
        prompt = "#j_maojie_liucha-choose_equip",
        cancelable = false,
      })
      if not targets or #targets == 0 then return end
      local to = targets[1]
      if to.dead then return end
      room:setPlayerMark(to, DUN_MARK, 1)
      randomDiscard(room, to, player, skillName)

    elseif card.type == Card.TypeTrick then
      -- 锦囊牌：令一名其他角色视为使用一张普通锦囊牌
      local others = table.filter(room.alive_players, function(p) return p ~= player end)
      if #others == 0 then return end
      local targets = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = 1,
        targets = others,
        skill_name = skillName,
        prompt = "#j_maojie_liucha-choose_trick",
        cancelable = false,
      })
      if not targets or #targets == 0 then return end
      useTrickBy(room, player, targets[1], skillName)
    end
  end,
})

-- 测试1：装备牌分支 → 目标获得庇护并随机弃置一张手牌
local function equipNameOf()
  for n, cd in pairs(Fk.all_card_types) do
    if cd.type == Card.TypeEquip then return n end
  end
  error("no equip card type found")
end

j_maojie_liucha:addTest(function(room, me)
  local gift
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_maojie_liucha.name)
    room.current = me
    me.phase = Player.Play
    gift = room:printCard(equipNameOf(room), Card.Spade, 1)
    room:obtainCard(me, { gift.id }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local other = room.players[2]
    other.hp = other.maxHp
    local g1 = room:printCard("slash", Card.Heart, 7)
    local g2 = room:printCard("dismantlement", Card.Club, 8)
    room:obtainCard(other, { g1.id, g2.id }, true, fk.ReasonDraw, other, "test")
    local before = #other:getCardIds("h")
    lu.assertTrue(before >= 2, "对手应有手牌")
    local eff = j_maojie_liucha.effects[1]
    local realDiscard = room.askToDiscard
    local realChoose = room.askToChoosePlayers
    room.askToDiscard = function(self, who, params)
      if who == me then
        return { gift.id }
      end
      return realDiscard(self, who, params)
    end
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_maojie_liucha.name then
        return { other }
      end
      return realChoose(self, who, params)
    end
    eff:onUse(room, { from = me, tos = {}, cards = {} })
    room.askToDiscard = realDiscard
    room.askToChoosePlayers = realChoose
    lu.assertEquals(#other:getCardIds("h"), before - 1, "目标应随机弃置一张手牌")
    lu.assertTrue(other:getMark("@@j_maojie_liucha_dun-turn") > 0, "目标应获得庇护标记")
  end)
end)

-- 测试2：基本牌分支 → 令一名角色摸一张牌
j_maojie_liucha:addTest(function(room, me)
  local gift
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_maojie_liucha.name)
    room.current = me
    me.phase = Player.Play
    gift = room:printCard("slash", Card.Spade, 1)
    room:obtainCard(me, { gift.id }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local other = room.players[2]
    other.hp = other.maxHp
    local before = #other:getCardIds("h")
    local realDiscard = room.askToDiscard
    local realChoose = room.askToChoosePlayers
    local realChoice = room.askToChoice
    room.askToDiscard = function(self, who, params)
      if who == me then
        return { gift.id }
      end
      return realDiscard(self, who, params)
    end
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_maojie_liucha.name then
        return { other }
      end
      return realChoose(self, who, params)
    end
    room.askToChoice = function(self, who, params)
      if params.skill_name == j_maojie_liucha.name then
        return "#j_maojie_liucha-draw"
      end
      return realChoice(self, who, params)
    end
    local eff = j_maojie_liucha.effects[1]
    eff:onUse(room, { from = me, tos = {}, cards = {} })
    room.askToDiscard = realDiscard
    room.askToChoosePlayers = realChoose
    room.askToChoice = realChoice
    lu.assertEquals(#other:getCardIds("h"), before + 1, "目标应摸一张牌")
  end)
end)

-- 测试3：锦囊牌分支 → 候选牌名只取自本局已有的普通锦囊，且不含延时锦囊
j_maojie_liucha:addTest(function(room, me)
  local gift
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_maojie_liucha.name)
    room.current = me
    me.phase = Player.Play
    gift = room:printCard("ex_nihilo", Card.Heart, 2)
    room:obtainCard(me, { gift.id }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local other = room.players[2]
    other.hp = other.maxHp
    local offered
    local before = #other:getCardIds("h")
    local realDiscard = room.askToDiscard
    local realChoose = room.askToChoosePlayers
    local realChoice = room.askToChoice
    room.askToDiscard = function(self, who, params)
      if who == me then
        return { gift.id }
      end
      return realDiscard(self, who, params)
    end
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_maojie_liucha.name then
        return { other }
      end
      return realChoose(self, who, params)
    end
    room.askToChoice = function(self, who, params)
      if params.skill_name == j_maojie_liucha.name then
        offered = params.choices
        return "ex_nihilo"
      end
      return realChoice(self, who, params)
    end
    local eff = j_maojie_liucha.effects[1]
    eff:onUse(room, { from = me, tos = {}, cards = {} })
    room.askToDiscard = realDiscard
    room.askToChoosePlayers = realChoose
    room.askToChoice = realChoice

    lu.assertNotNil(offered, "应弹出普通锦囊牌名选择")
    for _, n in ipairs(offered) do
      local c = Fk.all_card_types[n]
      lu.assertNotNil(c, "候选牌名必须已注册: " .. tostring(n))
      lu.assertEquals(c.type, Card.TypeTrick, "候选必须为锦囊: " .. n)
      lu.assertTrue(c.sub_type ~= Card.SubtypeDelayedTrick, "候选不可含延时锦囊: " .. n)
    end
    -- 无中生有由 other 使用，结算后其摸两张牌（证明使用者确实是 other）
    lu.assertEquals(#other:getCardIds("h"), before + 2, "应由指定的其他角色视为使用无中生有")
  end)
end)


return j_maojie_liucha
