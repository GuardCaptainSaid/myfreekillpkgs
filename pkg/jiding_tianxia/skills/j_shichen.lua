-- 计杨修·识谶
-- 出牌阶段限一次，你可以观看一名角色的手牌，选择其中一张牌标记为“谶”。
-- 本轮内，你可以弃置一张与“谶”花色相同的手牌，视为使用该“谶”牌；
-- 若你一回合未以此法发动转化，回合结束时你摸一张牌（每名角色回合限一次）。
-- 当标记为“谶”的牌进入弃牌堆时，你视为使用该“谶”牌；若你无法使用此牌，则改为摸两张牌。
local j_shichen = fk.CreateSkill {
  name = "j_shichen",
}

-- 转化子技能：弃一张与“谶”同花色的手牌，视为使用“谶”牌（授予给“谶”的持有者杨修）
-- ！！转化实现必须单独占一个文件（j_shichen_conv.lua）！！
-- 引擎的技能加载器只注册「文件 return 的那个 skeleton」，同一文件里第二个 fk.CreateSkill
-- 不会进入 Fk.skills，handleAddLoseSkills 会静默失败、技能根本授予不上。
local CONV = "j_shichen_conv"

Fk:loadTranslationTable{
  ["j_shichen"] = "识谶",
  [":j_shichen"] = "出牌阶段限一次，你可以观看一名角色的手牌，选择其中一张牌标记为“谶”。本轮内，你可以弃置一张与“谶”花色相同的手牌，视为使用该“谶”牌；若你一回合未以此法发动转化，回合结束时你摸一张牌（每名角色回合限一次）。当标记为“谶”的牌进入弃牌堆时，你视为使用该“谶”牌；若你无法使用此牌，则改为摸两张牌。",

  ["#j_shichen"] = "识谶：观看一名角色的手牌，标记其中一张为“谶”",
  ["#j_shichen-mark"] = "识谶：请选择其中一张牌标记为“谶”",
  ["#j_shichen-use"] = "识谶：视为使用此“谶”牌（若无法使用则改为摸两张牌）",
  ["#j_shichen-record"] = "识谶：将 %card 标记为“谶”",
  ["j_shichen_mark"] = "标记为“谶”",

  -- 标记区：显示「谶 杀 黑桃」
  ["@j_shichen_chen"] = "谶",
  ["j_shichen_suit_spade"] = "黑桃",
  ["j_shichen_suit_heart"] = "红桃",
  ["j_shichen_suit_club"] = "梅花",
  ["j_shichen_suit_diamond"] = "方块",

  ["@@j_shichen_chen"] = "谶",
}

-- 花色 → 翻译键（标记区显示用）
local SUIT_KEY = {
  [Card.Spade] = "j_shichen_suit_spade",
  [Card.Heart] = "j_shichen_suit_heart",
  [Card.Club] = "j_shichen_suit_club",
  [Card.Diamond] = "j_shichen_suit_diamond",
}

-- 当前“谶”的牌名与花色（玩家 mark，服务端权威；客户端 viewas 也读这两个标记）
local function chenName(player)
  local name = player:getMark("j_shichen_chen_name")
  if type(name) ~= "string" or name == "" or Fk.all_card_types[name] == nil then return end
  return name
end

-- 授予 / 收回转化子技能
local function grantConv(room, player, on)
  local granted = player:getMark("j_shichen_granted") > 0
  if on and not granted then
    room:handleAddLoseSkills(player, CONV, nil, false, true)
    room:setPlayerMark(player, "j_shichen_granted", 1)
  elseif (not on) and granted then
    room:handleAddLoseSkills(player, "-" .. CONV, nil, false, true)
    room:setPlayerMark(player, "j_shichen_granted", 0)
  end
end

-- 清除“谶”（清牌上标记 + 玩家记录 + 收回转化技能）
local function clearChen(room, player)
  local cid = player:getMark("j_shichen_chen_id")
  -- 注意：printCard 生成的牌 id 为负数，不能写 cid > 0
  if type(cid) == "number" and cid ~= 0 then
    local card = Fk:getCardById(cid)
    if card then room:setCardMark(card, "@@j_shichen_chen", 0) end
  end
  room:setPlayerMark(player, "j_shichen_chen_id", 0)
  room:setPlayerMark(player, "j_shichen_chen_name", "")
  room:setPlayerMark(player, "j_shichen_chen_suit", -1)
  -- 标记区里给玩家看的「谶 xx」
  room:setPlayerMark(player, "@j_shichen_chen", 0)
  grantConv(room, player, false)
end

-- 标记一张牌为“谶”
local function setChen(room, player, card)
  clearChen(room, player)
  room:setCardMark(card, "@@j_shichen_chen", 1)
  -- “谶”可能在别人手里（看不到牌面），所以另外给玩家自己一个可见标记：
  -- 标记区显示「谶 杀 黑桃」——value 会被 Lua.tr 逐个翻译，故传牌名与花色翻译键
  local name = (card.trueName and card.trueName ~= "") and card.trueName or card.name
  local suitKey = SUIT_KEY[card.suit]
  room:setPlayerMark(player, "@j_shichen_chen",
    suitKey and { name, suitKey } or { name })
  room:sendLog{
    type = "#j_shichen-record",
    from = player.id,
    to = { player.id },
    card = { card.id },
  }
  room:setPlayerMark(player, "j_shichen_chen_id", card.id)
  room:setPlayerMark(player, "j_shichen_chen_name", name)
  room:setPlayerMark(player, "j_shichen_chen_suit", card.suit)
  grantConv(room, player, true)
end

-- 出牌阶段限一次：观看一名角色的手牌，标记其中一张为“谶”
j_shichen:addEffect("active", {
  anim_type = "control",
  prompt = "#j_shichen",
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    return player:getMark("j_shichen_used-phase") == 0
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and not to_select.dead and #to_select:getCardIds("h") > 0
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_targets == 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if not target or target.dead or #target:getCardIds("h") == 0 then return end
    local hand = target:getCardIds("h")
    -- 观看手牌必须用 askToChooseCardsAndChoice（ChooseCardsAndChoiceBox，牌面朝上）。
    -- 不能用 askToChooseCard：它走 AskForCardChosen（拆牌/顺手那种"盲选"界面），
    -- 客户端 Client:askForCardChosen 会把非己方手牌全部标成不可见，玩家只能看到背面。
    local ids = room:askToChooseCardsAndChoice(player, {
      cards = hand,
      choices = { "j_shichen_mark" },
      skill_name = j_shichen.name,
      prompt = "#j_shichen-mark",
      min_num = 1,
      max_num = 1,
    })
    local pick = ids and ids[1]
    -- 注意：printCard 生成的牌 id 为负数，只能把 nil / 0 视为未选
    if pick == nil or pick == 0 then return end
    local card = Fk:getCardById(pick)
    if not card then return end
    room:setPlayerMark(player, "j_shichen_used-phase", 1)
    setChen(room, player, card)
  end,
})

-- 本轮内：弃一张同花色手牌，视为使用“谶”牌
-- 转化效果本体在 j_shichen_conv.lua（必须单独成文件，见文件头说明）

-- 若你一回合未以此法发动转化，回合结束时你摸一张牌
j_shichen:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "drawcard",
  -- 技能文本无“可以”，自动执行
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_shichen.name) or player.dead then return false end
    if player:getMark("j_shichen_conv-turn") > 0 then return false end
    return chenName(player) ~= nil
  end,
  on_use = function(self, event, target, player, data)
    player.room:drawCards(player, 1, j_shichen.name)
  end,
})

-- 当标记为“谶”的牌进入弃牌堆时：视为使用该“谶”牌；无法使用则改为摸两张牌
j_shichen:addEffect(fk.AfterCardsMove, {
  global = true,
  anim_type = "control",
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_shichen.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = Fk:getCardById(info.cardId)
          if card and card:getMark("@@j_shichen_chen") > 0 then return true end
        end
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = Fk:getCardById(info.cardId)
          if card and card:getMark("@@j_shichen_chen") > 0 then
            -- 该牌已进入弃牌堆，“谶”随之中断
            local name = (card.trueName and card.trueName ~= "") and card.trueName or card.name
            clearChen(room, player)
            if player.dead then return end
            -- 先判断能否使用，再决定“视为使用”还是摸两张
            local usable = false
            local proto = Fk:cloneCard(name)
            if proto then
              proto.skillName = j_shichen.name
              usable = #proto:getAvailableTargets(player, { bypass_times = true, extraUse = true }) > 0
            end
            if usable then
              room:askToUseVirtualCard(player, {
                name = name,
                skill_name = j_shichen.name,
                cancelable = true,
                prompt = "#j_shichen-use",
              })
            else
              room:drawCards(player, 2, j_shichen.name)
            end
          end
        end
      end
    end
  end,
})

-- 本轮结束时清除“谶”
j_shichen:addEffect(fk.RoundEnd, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_shichen.name) and not player.dead
  end,
  on_use = function(self, event, target, player, data)
    clearChen(player.room, player)
  end,
})

-- 测试：出牌阶段标记“谶” → 记录牌名/花色并授予转化技能
j_shichen:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shichen.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 7)
    c2 = room:printCard("jink", Card.Heart, 8)
    room:obtainCard(comp2, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    -- 走真实的主动技使用链路（AskForUseActiveSkill → onUse → 观看手牌请求）
    local origChoose = room.askToChooseCardsAndChoice
    local seen
    room.askToChooseCardsAndChoice = function(self, who, params)
      if who == me then
        seen = params
        return { c1.id }, "j_shichen_mark"
      end
      return origChoose(self, who, params)
    end
    FkTest.setNextReplies(me, { FkTest.ReplyUseSkill(j_shichen.name, { comp2 }) })
    local skel = Fk.skills[j_shichen.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")
    lu.assertTrue(spec:can_use(me), "出牌阶段且未发动过应可发动")
    room:askToUseActiveSkill(me, { skill_name = j_shichen.name })
    room.askToChooseCardsAndChoice = origChoose

    -- 观看：必须一次把目标全部手牌都摊开给玩家选（askToChooseCard 会显示背面）
    lu.assertNotNil(seen, "应弹出观看手牌的界面")
    lu.assertEquals(#seen.cards, 2, "观看界面应包含目标全部手牌")
    lu.assertTrue(table.contains(seen.cards, c1.id), "目标手牌应在观看界面里")
    lu.assertTrue(table.contains(seen.cards, c2.id), "目标手牌应在观看界面里")

    lu.assertTrue(Fk:getCardById(c1.id):getMark("@@j_shichen_chen") > 0, "所选牌应带“谶”标记")
    lu.assertEquals(Fk:getCardById(c2.id):getMark("@@j_shichen_chen"), 0, "未选牌不应带标记")
    lu.assertEquals(me:getMark("j_shichen_chen_name"), "slash", "应记录“谶”的牌名")
    lu.assertEquals(me:getMark("j_shichen_chen_suit"), Card.Spade, "应记录“谶”的花色")
    lu.assertEquals(me:getMark("j_shichen_chen_id"), c1.id, "应记录“谶”的牌 id")
    lu.assertTrue(me:hasSkill("j_shichen_conv"), "应授予转化技能")
    lu.assertFalse(spec:can_use(me), "出牌阶段限一次")
  end)
end)

-- 测试：转化 —— 弃同花色手牌视为使用“谶”；不同花色不可选
j_shichen:addTest(function(room, me)
  local comp2 = room.players[2]
  local chen, same, diff
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shichen.name)
    me.phase = Player.Play
    room.current = me
    chen = room:printCard("slash", Card.Spade, 7)
    same = room:printCard("jink", Card.Spade, 9)
    diff = room:printCard("peach", Card.Heart, 6)
    room:obtainCard(comp2, { chen }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(me, { same, diff }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(chen, "@@j_shichen_chen", 1)
    room:setPlayerMark(me, "j_shichen_chen_id", chen.id)
    room:setPlayerMark(me, "j_shichen_chen_name", "slash")
    room:setPlayerMark(me, "j_shichen_chen_suit", Card.Spade)
  end)
  FkTest.runInRoom(function()
    -- 注意用冒号调用：cardFilter 是技能实例的方法，点调用会把 player 当成 self 传错
    local vs = Fk.skills["j_shichen_conv"]
    lu.assertNotNil(vs, "【谶】应在 Fk.skills 中注册")
    lu.assertTrue(vs:cardFilter(me, same.id, {}, {}), "同花色手牌应可选")
    lu.assertFalse(vs:cardFilter(me, diff.id, {}, {}), "不同花色手牌不可选")

    local card = vs:viewAs(me, { same.id })
    lu.assertNotNil(card, "应能转化为“谶”牌")
    lu.assertEquals(card.name, "slash", "转化牌名应为“谶”的牌名")
    lu.assertEquals(#card.subcards, 1, "应以弃置的手牌为副牌")
  end)
end)

-- 测试：一回合未转化 → 回合结束摸一张牌；已转化则不摸
j_shichen:addTest(function(room, me)
  local comp2 = room.players[2]
  local chen
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shichen.name)
    room.current = comp2
    comp2.phase = Player.Play
    chen = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(comp2, { chen }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(chen, "@@j_shichen_chen", 1)
    room:setPlayerMark(me, "j_shichen_chen_id", chen.id)
    room:setPlayerMark(me, "j_shichen_chen_name", "slash")
    room:setPlayerMark(me, "j_shichen_chen_suit", Card.Spade)
  end)
  FkTest.runInRoom(function()
    local hand = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(#me:getCardIds("h"), hand + 1, "未转化应于回合结束摸一张牌")

    room:setPlayerMark(me, "j_shichen_conv-turn", 1)
    hand = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(#me:getCardIds("h"), hand, "已转化则回合结束不摸牌")
  end)
end)

-- 测试：“谶”进入弃牌堆 → 视为使用；无法使用则摸两张牌
j_shichen:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shichen.name)
    room.current = comp2
    comp2.phase = Player.Play
    c1 = room:printCard("ex_nihilo", Card.Spade, 7)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_shichen_chen", 1)
    room:setPlayerMark(me, "j_shichen_chen_id", c1.id)
    room:setPlayerMark(me, "j_shichen_chen_name", "ex_nihilo")
    room:setPlayerMark(me, "j_shichen_chen_suit", Card.Spade)
  end)
  FkTest.runInRoom(function()
    -- 情形1：可以使用 → 视为使用，不摸牌
    local origUseVirtual = room.askToUseVirtualCard
    local used = false
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then used = true return true end
      return origUseVirtual(self, who, params)
    end
    local hand = #me:getCardIds("h")
    room:throwCard(c1.id, "test", comp2, comp2)
    room.askToUseVirtualCard = origUseVirtual
    lu.assertTrue(used, "“谶”进入弃牌堆应触发视为使用")
    lu.assertEquals(#me:getCardIds("h"), hand, "成功使用不应摸牌")
    lu.assertEquals(Fk:getCardById(c1.id):getMark("@@j_shichen_chen"), 0, "使用后“谶”标记应清除")
    lu.assertFalse(me:hasSkill("j_shichen_conv"), "“谶”消失后应收回转化技能")
  end)
end)

-- 测试：端到端印牌 —— 弃一张同花色手牌，把“谶”当【无中生有】真正使用出去
j_shichen:addTest(function(room, me)
  local comp2 = room.players[2]
  local chen, same
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shichen.name)
    me.phase = Player.Play
    room.current = me
    chen = room:printCard("ex_nihilo", Card.Spade, 7)
    same = room:printCard("jink", Card.Spade, 9)
    room:obtainCard(me, { same }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { chen }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(chen, "@@j_shichen_chen", 1)
    room:setPlayerMark(me, "j_shichen_chen_id", chen.id)
    room:setPlayerMark(me, "j_shichen_chen_name", "ex_nihilo")
    room:setPlayerMark(me, "j_shichen_chen_suit", Card.Spade)
    room:handleAddLoseSkills(me, "j_shichen_conv")
  end)
  FkTest.runInRoom(function()
    lu.assertTrue(me:hasSkill("j_shichen_conv"), "应持有【谶】")
    local hand = #me:getCardIds("h")
    room:handleUseCardReply(me, {
      card = { skill = "j_shichen_conv", subcards = { same.id } },
      targets = {},
    })
    lu.assertFalse(table.contains(me:getCardIds("h"), same.id), "作为副牌的手牌应已使用")
    lu.assertEquals(#me:getCardIds("h"), hand - 1 + 2, "当【无中生有】使用后应摸两张牌")
    lu.assertEquals(me:getMark("j_shichen_conv-turn"), 1, "应记录本回合已以此法转化")
  end)
end)

return j_shichen
