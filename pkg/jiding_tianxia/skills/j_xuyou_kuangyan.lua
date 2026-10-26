-- 计许攸·狂言（转换技，出牌阶段限一次）
-- 阴：你保留一种类型的牌，弃置其余牌，然后摸等量的牌；
-- 阳：你摸一张牌，重复此流程直到你的手牌包含三种类型，且本回合你以此法摸的牌无距离和次数限制。
local j_xuyou_kuangyan = fk.CreateSkill {
  name = "j_xuyou_kuangyan",
  tags = { Skill.Switch },
}

-- 本回合（-turn 由引擎在回合结束时自动清除）以此法摸到的牌：无距离、无次数限制
local FREE_MARK = "j_xuyou_kuangyan_free-turn"

-- 【重要】选项文本禁止带冒号！
-- 客户端 ChoicesBox 显示选项走 Ltk.processPrompt()，实现是「先按冒号切分、只翻译第一段」
-- （Lua.tr(str.split(":")[0])）。所以键名一旦带冒号，就会被截成技能名 j_xuyou_kuangyan
-- → 三个选项全都显示成"狂言"，玩家根本看不出在选什么。
-- 冒号只在 "翻译键:参数1:参数2" 这种带 %arg 的格式串里才是分隔符。
-- 约定：选项键一律用「技能名__选项」形式（参考官方 ol_ex__tianxiang_loseHp）。
local TYPE_CHOICES = {
  [Card.TypeBasic] = "j_xuyou_kuangyan__basic",
  [Card.TypeTrick] = "j_xuyou_kuangyan__trick",
  [Card.TypeEquip] = "j_xuyou_kuangyan__equip",
}

-- 固定顺序：基本 → 锦囊 → 装备（选项顺序稳定，玩家不会因为顺序变化选错）
local TYPE_ORDER = { Card.TypeBasic, Card.TypeTrick, Card.TypeEquip }

Fk:loadTranslationTable{
  ["j_xuyou_kuangyan"] = "狂言",
  [":j_xuyou_kuangyan"] = "转换技，出牌阶段限一次。阴：你保留一种类型的牌，弃置其余牌，然后摸等量的牌；" ..
    "阳：你摸一张牌，重复此流程直到你的手牌包含三种类型，且本回合你以此法摸的牌无距离和次数限制。",
  [":j_xuyou_kuangyan_yang"] = "转换技，出牌阶段限一次。" ..
    "<font color='#E0DB2F'>阳：你摸一张牌，重复此流程直到你的手牌包含三种类型，且本回合你以此法摸的牌无距离和次数限制；</font>" ..
    "<font color='grey'>阴：你保留一种类型的牌，弃置其余牌，然后摸等量的牌。</font>",
  [":j_xuyou_kuangyan_yin"] = "转换技，出牌阶段限一次。" ..
    "<font color='grey'>阳：你摸一张牌，重复此流程直到你的手牌包含三种类型，且本回合你以此法摸的牌无距离和次数限制；</font>" ..
    "<font color='#E0DB2F'>阴：你保留一种类型的牌，弃置其余牌，然后摸等量的牌。</font>",

  -- 选项文本（按钮上显示）。键名不能带冒号，见 TYPE_CHOICES 上方注释。
  ["j_xuyou_kuangyan__basic"] = "基本牌",
  ["j_xuyou_kuangyan__trick"] = "锦囊牌",
  ["j_xuyou_kuangyan__equip"] = "装备牌",
  -- 详细模式（detailed = true）右侧的说明文字，客户端取 ":" + 选项文本 作为键
  [":j_xuyou_kuangyan__basic"] = "保留手中所有基本牌（【杀】【闪】【桃】【酒】等），弃置其余类型的牌，然后摸等量的牌",
  [":j_xuyou_kuangyan__trick"] = "保留手中所有锦囊牌（含延时锦囊），弃置其余类型的牌，然后摸等量的牌",
  [":j_xuyou_kuangyan__equip"] = "保留手中所有装备牌，弃置其余类型的牌，然后摸等量的牌",

  ["#j_xuyou_kuangyan-keep"] = "狂言：选择一种类型的牌保留，弃置其余手牌，然后摸等量的牌",
  ["#j_xuyou_kuangyan-yang"] = "狂言：摸牌直到手牌包含三种类型",

  ["$j_xuyou_kuangyan1"] = "狂言一出，天下侧目！",
  ["$j_xuyou_kuangyan2"] = "许子远之谋，岂是尔等能料？",
}

-- 手牌是否已同时包含基本、锦囊、装备三种类型
local function hasAllTypes(player)
  local seen = {}
  for _, id in ipairs(player:getCardIds("h")) do
    seen[Fk:getCardById(id).type] = true
  end
  return seen[Card.TypeBasic] and seen[Card.TypeTrick] and seen[Card.TypeEquip]
end

-- 把玩家选中的选项还原成牌的类型。
-- 【注意】正常情况下回传的是原始键（如 "j_xuyou_kuangyan__basic"），
-- 但个别客户端可能回传翻译后的文本，这里两种都认，避免"选了却没生效"。
local function resolveType(choice)
  if choice == nil or choice == "" or choice == "Cancel" then return nil end
  for _, t in ipairs(TYPE_ORDER) do
    local key = TYPE_CHOICES[t]
    if choice == key or choice == Fk:translate(key) then return t end
  end
  return nil
end

-- 阴：保留一种类型的牌，弃置其余，摸等量
local function doYin(room, player)
  local handIds = player:getCardIds("h")
  if #handIds == 0 then return end

  -- 手里实际存在的类型
  local has = {}
  for _, id in ipairs(handIds) do
    has[Fk:getCardById(id).type] = true
  end
  local choices = {}
  for _, t in ipairs(TYPE_ORDER) do
    if has[t] then table.insert(choices, TYPE_CHOICES[t]) end
  end
  if #choices == 0 then return end

  -- 【重要】必须传 all_choices：
  -- ① 只有一种类型时引擎不会再"自动替你选"直接返回（那种情况下玩家根本看不到选择框，
  --    表现为"狂言阴没让我选保留的牌型"）；
  -- ② 三种类型会全部列出来（没有的置灰），玩家能一眼看清自己在选什么。
  local choice = room:askToChoice(player, {
    choices = choices,
    all_choices = { TYPE_CHOICES[Card.TypeBasic], TYPE_CHOICES[Card.TypeTrick], TYPE_CHOICES[Card.TypeEquip] },
    detailed = true,
    skill_name = j_xuyou_kuangyan.name,
    prompt = "#j_xuyou_kuangyan-keep",
    cancelable = false,
  })
  local keepType = resolveType(choice)
  if keepType == nil then
    -- 兜底：实在认不出来就保留手里最多的一种类型（保证技能不是"发动了却什么都没发生"）
    local count = {}
    for _, id in ipairs(handIds) do
      local t = Fk:getCardById(id).type
      count[t] = (count[t] or 0) + 1
    end
    local best
    for _, t in ipairs(TYPE_ORDER) do
      if count[t] and (best == nil or count[t] > count[best]) then best = t end
    end
    keepType = best
    if keepType == nil then return end
  end

  local discardIds = {}
  for _, id in ipairs(handIds) do
    if Fk:getCardById(id).type ~= keepType then
      table.insert(discardIds, id)
    end
  end
  if #discardIds == 0 then return end
  room:throwCard(discardIds, j_xuyou_kuangyan.name, player, player)
  if not player.dead then
    player:drawCards(#discardIds, j_xuyou_kuangyan.name)
  end
end

-- 阳：反复摸牌直到手牌包含三种类型，并给摸到的牌打上"无限制"标记
local function doYang(room, player)
  local before = {}
  for _, id in ipairs(player:getCardIds("h")) do
    before[id] = true
  end

  -- 至少摸一张，之后每摸一张都检查一次；用 guard 兜底防止牌堆异常导致死循环
  local guard = 0
  repeat
    if #room.draw_pile == 0 or player.dead then break end
    player:drawCards(1, j_xuyou_kuangyan.name)
    guard = guard + 1
  until hasAllTypes(player) or guard >= 40

  for _, id in ipairs(player:getCardIds("h")) do
    if not before[id] then
      room:setCardMark(Fk:getCardById(id), FREE_MARK, 1)
    end
  end
end

-- 供【倨功】复用的入口
j_xuyou_kuangyan.do_yin = doYin
j_xuyou_kuangyan.do_yang = doYang

-- 出牌阶段限一次的主动技：按当前形态执行阴/阳
-- 【注意】引擎一个技能只能有 1 个 active/viewas 效果（多写会被丢弃并报 qCritical），
-- 所以阴阳两形态必须合并成同一个 active，在 on_use 里分支。
j_xuyou_kuangyan:addEffect("active", {
  anim_type = "drawcard",
  prompt = function(self, player)
    if player:getSwitchSkillState(j_xuyou_kuangyan.name) == fk.SwitchYang then
      return "#j_xuyou_kuangyan-yang"
    end
    return "#j_xuyou_kuangyan-keep"
  end,
  max_phase_use_time = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(j_xuyou_kuangyan.name, Player.HistoryPhase) == 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    -- 【注意】转换技在 on_use 执行前就已经翻转了形态，
    -- 所以必须用引擎记录的"发动前状态"effect.switch_state，不能读 getSwitchSkillState。
    local state = effect.switch_state
    if not state then
      state = player:getSwitchSkillState(j_xuyou_kuangyan.name)
    end
    if state == fk.SwitchYang then
      doYang(room, player)
    else
      doYin(room, player)
    end
  end,
})

-- 本回合以此法摸到的牌：无距离、无次数限制
-- 【注意】targetmod 的回调客户端也会执行，禁止使用 player.room
j_xuyou_kuangyan:addEffect("targetmod", {
  bypass_times = function(self, player, skill, scope, card, to)
    return card ~= nil and card:getMark(FREE_MARK) > 0
  end,
  bypass_distances = function(self, player, skill, card, to)
    return card ~= nil and card:getMark(FREE_MARK) > 0
  end,
})

-- 测试1：阴形态 → 保留基本牌，弃置其余，摸等量
j_xuyou_kuangyan:addTest(function(room, me)
  local slashId, jinkId, trickId, equipId
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_kuangyan.name)
    room.current = me
    me.phase = Player.Play
    slashId = room:printCard("slash", Card.Spade, 3).id          -- 基本
    jinkId = room:printCard("jink", Card.Heart, 4).id            -- 基本
    trickId = room:printCard("dismantlement", Card.Club, 5).id    -- 锦囊
    equipId = room:printCard("qinggang_sword", Card.Diamond, 6).id -- 装备
    room:obtainCard(me, { slashId, jinkId, trickId, equipId }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    -- 先翻成阴形态
    local pre = MarkEnum.SwithSkillPreName .. j_xuyou_kuangyan.name
    room:setPlayerMark(me, pre, 1)
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_kuangyan.name), fk.SwitchYin, "应为阴形态")

    -- 直接接管选择框（避免测试环境的回复匹配不确定性）
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      if params.skill_name == j_xuyou_kuangyan.name then
        return "j_xuyou_kuangyan__basic"
      end
      return origChoice(self, who, params)
    end
    local handBefore = #me:getCardIds("h")
    j_xuyou_kuangyan.do_yin(room, me)
    room.askToChoice = origChoice
    local hand = me:getCardIds("h")
    -- 弃掉锦囊、装备各 1 张（共 2 张），再摸 2 张 → 手牌 4-2+2=4
    lu.assertEquals(#hand, handBefore, "弃 2 摸 2，手牌数不变")
    lu.assertFalse(table.contains(hand, trickId), "锦囊牌应被弃置")
    lu.assertFalse(table.contains(hand, equipId), "装备牌应被弃置")
    lu.assertTrue(table.contains(hand, slashId), "基本牌应被保留")
    lu.assertTrue(table.contains(hand, jinkId), "基本牌应被保留")
  end)
end)

-- 测试2：阳形态 → 反复摸牌直到手牌含三种类型，且摸到的牌带无限制标记
j_xuyou_kuangyan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_kuangyan.name)
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_xuyou_kuangyan.name, 0)
    -- 清空手牌，只给两张【杀】（单一类型，必然要摸到锦囊和装备）
    for _, id in ipairs(me:getCardIds("h")) do
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, "test")
    end
    local c1 = room:printCard("slash", Card.Spade, 3).id
    local c2 = room:printCard("slash", Card.Heart, 4).id
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_kuangyan.name), fk.SwitchYang, "应为阳形态")
    -- 测试环境牌堆默认按包顺序排列，前 40 张可能全是【杀】；先洗牌再验证
    table.shuffle(room.draw_pile)
    j_xuyou_kuangyan.do_yang(room, me)

    -- 手牌必须已包含三种类型
    local seen = {}
    for _, id in ipairs(me:getCardIds("h")) do
      seen[Fk:getCardById(id).type] = true
    end
    lu.assertTrue(seen[Card.TypeBasic] and seen[Card.TypeTrick] and seen[Card.TypeEquip],
      "阳形态摸牌后手牌应包含三种类型")

    -- 新摸到的牌（除最初两张杀）都带无限制标记
    local marked = 0
    for _, id in ipairs(me:getCardIds("h")) do
      if Fk:getCardById(id):getMark(FREE_MARK) > 0 then
        marked = marked + 1
      end
    end
    lu.assertTrue(marked > 0, "以此法摸到的牌应带无距离次数限制标记")
  end)
end)

-- 测试3（真实发动）：阳形态发动后形态翻转为阴，且摸牌直到三种类型齐备
j_xuyou_kuangyan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_kuangyan.name)
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_xuyou_kuangyan.name, 0)
    for _, id in ipairs(me:getCardIds("h")) do
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, "test")
    end
    local c1 = room:printCard("slash", Card.Spade, 3).id
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    table.shuffle(room.draw_pile)
  end)
  FkTest.runInRoom(function()
    local sk = Fk.skills[j_xuyou_kuangyan.name]
    -- 走真实的主动技使用路径（引擎会写入发动前的形态 effect.switch_state）
    local effect = { from = me, tos = {}, cards = {}, cost_data = {}, switch_state = fk.SwitchYang }
    room:useSkill(me, sk, function()
      sk:onUse(room, effect)
    end, {})
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_kuangyan.name), fk.SwitchYin,
      "阳形态发动后应翻转为阴形态")
    local seen = {}
    for _, id in ipairs(me:getCardIds("h")) do
      seen[Fk:getCardById(id).type] = true
    end
    lu.assertTrue(seen[Card.TypeBasic] and seen[Card.TypeTrick] and seen[Card.TypeEquip],
      "真实发动后手牌应包含三种类型")
  end)
end)

-- 测试4（真实发动）：阴形态下点狂言，必须弹出"保留牌型"的选择，弃掉其余类型
j_xuyou_kuangyan:addTest(function(room, me)
  local slashId, trickId, equipId
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_kuangyan.name)
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_xuyou_kuangyan.name, 1)  -- 阴
    for _, id in ipairs(me:getCardIds("h")) do
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, "test")
    end
    slashId = room:printCard("slash", Card.Spade, 3).id
    trickId = room:printCard("dismantlement", Card.Club, 5).id
    equipId = room:printCard("qinggang_sword", Card.Diamond, 6).id
    room:obtainCard(me, { slashId, trickId, equipId }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local sk = Fk.skills[j_xuyou_kuangyan.name]
    lu.assertTrue(sk:isInstanceOf(ActiveSkill), "狂言主技能应是主动技")
    lu.assertTrue(sk:canUse(me), "阴形态下狂言应可发动")
    local asked, nAll, nAvail = 0, 0, 0
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      if params.skill_name == j_xuyou_kuangyan.name then
        asked = asked + 1
        nAll = #(params.all_choices or params.choices)
        nAvail = #params.choices
        return "j_xuyou_kuangyan__basic"
      end
      return origChoice(self, who, params)
    end
    -- 走真实的主动技使用路径（引擎会写入"发动前形态"）
    local use = { from = me, tos = {}, cards = {} }
    room:useSkill(me, sk, function() sk:onUse(room, use) end, use)
    room.askToChoice = origChoice
    lu.assertEquals(asked, 1, "阴形态必须弹出保留牌型的选择")
    lu.assertEquals(nAll, 3, "三种类型应全部列出（手里没有的置灰）")
    lu.assertEquals(nAvail, 3, "三种类型都有时应都可选")
    local hand = me:getCardIds("h")
    lu.assertTrue(table.contains(hand, slashId), "选中的基本牌应保留")
    lu.assertFalse(table.contains(hand, trickId), "锦囊牌应被弃置")
    lu.assertFalse(table.contains(hand, equipId), "装备牌应被弃置")
    lu.assertEquals(me:getSwitchSkillState(j_xuyou_kuangyan.name), fk.SwitchYang,
      "阴形态发动后应翻转为阳")
    lu.assertFalse(sk:canUse(me), "出牌阶段已用过后不应再用")
  end)
end)

-- 测试5：手里只有一种类型时也必须弹出选择框（否则引擎会静默替你选，玩家根本看不到框）
j_xuyou_kuangyan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_kuangyan.name)
    room.current = me
    me.phase = Player.Play
    for _, id in ipairs(me:getCardIds("h")) do
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, "test")
    end
    room:obtainCard(me, {
      room:printCard("slash", Card.Spade, 3).id,
      room:printCard("jink", Card.Heart, 4).id,
    }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    -- 监听真正发请求的 askToChoices：
    -- askToChoice 在"只有 1 个可选项"时会直接返回、不发请求（玩家根本看不到框），
    -- 只有传了 all_choices 才会走到这里。
    local asked, nAvail, nAll = 0, 0, 0
    local origChoices = room.askToChoices
    room.askToChoices = function(self, who, params)
      if params.skill_name == j_xuyou_kuangyan.name then
        asked = asked + 1
        nAvail = #params.choices
        nAll = #(params.all_choices or params.choices)
        return { params.choices[1] }
      end
      return origChoices(self, who, params)
    end
    j_xuyou_kuangyan.do_yin(room, me)
    room.askToChoices = origChoices
    lu.assertEquals(asked, 1, "只有一种类型时也必须真的弹出选择框")
    lu.assertEquals(nAll, 3, "三种类型应全部列出（没有的置灰）")
    lu.assertEquals(nAvail, 1, "只有基本牌可选")
    lu.assertEquals(#me:getCardIds("h"), 2, "只有一种类型时不应弃牌")
  end)
end)

-- 测试6：客户端若回传翻译后的文本（而非原始键），也要能正确识别
j_xuyou_kuangyan:addTest(function(room, me)
  local slashId, trickId
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_kuangyan.name)
    room.current = me
    for _, id in ipairs(me:getCardIds("h")) do
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, "test")
    end
    slashId = room:printCard("slash", Card.Spade, 3).id
    trickId = room:printCard("dismantlement", Card.Club, 5).id
    room:obtainCard(me, { slashId, trickId }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      if params.skill_name == j_xuyou_kuangyan.name then
        return Fk:translate("j_xuyou_kuangyan__basic")   -- 回传翻译文本
      end
      return origChoice(self, who, params)
    end
    j_xuyou_kuangyan.do_yin(room, me)
    room.askToChoice = origChoice
    local hand = me:getCardIds("h")
    lu.assertTrue(table.contains(hand, slashId), "回传翻译文本时也应识别为基本牌并保留")
    lu.assertFalse(table.contains(hand, trickId), "锦囊牌应被弃置")
  end)
end)

return j_xuyou_kuangyan
