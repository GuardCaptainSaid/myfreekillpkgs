-- 计许攸·倨功
-- 每名角色回合限一次，当其他角色每回合首次造成伤害或获得牌时，
-- 你可以发动一次"狂言"，然后其下次使用牌的目标必须包含你，且该牌无距离和次数限制。
local j_xuyou_jugong = fk.CreateSkill {
  name = "j_xuyou_jugong",
}

-- `@@` 前缀：标记区只显示文字（不显示数值）
-- 【注意】带 -round 后缀的 @ / @@ 标记，翻译键必须写"含后缀的完整名"，否则 UI 直接显示原始标记名
local MUST = "@@j_xuyou_jugong_must-round"   -- 该角色下次使用牌必须包含许攸为目标
-- 无距离 / 无次数限制：用引擎内置标记。加 -round 而不是 -turn，
-- 因为"其下次使用牌"可能发生在其下个回合；但也必须有上限，
-- 否则该角色只要一直不出牌就能永久享受无限距离/次数。
local FREE_DIST = MarkEnum.BypassDistancesLimit .. "-round"
local FREE_TIMES = MarkEnum.BypassTimesLimit .. "-round"
-- 【注意】下面三个必须带 -turn 后缀，交给引擎的 clearHistory 自动清理，
-- 不要自己写 TurnEnd 效果去清（自建清理容易漏掉分支，导致标记永久残留=技能再也不发动）
local USED = "j_xuyou_jugong_used-turn"        -- 本回合已发动
local FIRST_DMG = "j_xuyou_jugong_dmg-turn"    -- 该角色本回合已首次造成伤害
local FIRST_GAIN = "j_xuyou_jugong_gain-turn"  -- 该角色本回合已首次获得牌

local KUANGYAN = "j_xuyou_kuangyan"

Fk:loadTranslationTable{
  ["j_xuyou_jugong"] = "倨功",
  [":j_xuyou_jugong"] = "每名角色的回合限一次，当其他角色于其回合内首次造成伤害或获得牌时，" ..
    "你可以发动一次“狂言”，然后其下次使用牌的目标必须包含你，且该牌无距离和次数限制。" ..
    "（其摸牌阶段的摸牌不计入首次获得牌）",

  [MUST] = "倨功",
  ["#j_xuyou_jugong-invoke"] = "倨功：是否发动一次“狂言”，并令 %src 下次使用牌必须包含你？",
  ["#j_xuyou_jugong-gain"] = "倨功：%src 首次获得牌",

  ["$j_xuyou_jugong1"] = "功在社稷，何须尔等置喙？",
  ["$j_xuyou_jugong2"] = "此功，唯我许子远可成！",
}

-- 取【狂言】的骨架（其中挂了 do_yin / do_yang 复用入口）
local function kuangyanSkeleton()
  local s = Fk.skills[KUANGYAN]
  if s == nil then return nil end
  -- Fk.skills 里存的是真正的 Skill，逻辑函数挂在它的 skeleton 上
  if s.getSkeleton then
    local skel = s:getSkeleton()
    if skel then return skel end
  end
  return s
end

-- 发动一次"狂言"（按当前形态执行，并按转换技规则翻转形态）
local function invokeKuangyan(room, player)
  if not player:hasSkill(KUANGYAN) then return false end
  local ky = kuangyanSkeleton()
  if ky == nil then return false end
  local isYang = player:getSwitchSkillState(KUANGYAN) == fk.SwitchYang
  if isYang then
    if type(ky.do_yang) ~= "function" then return false end
    ky.do_yang(room, player)
  else
    if type(ky.do_yin) ~= "function" then return false end
    ky.do_yin(room, player)
  end
  -- 手动翻转形态（等同于"发动一次"转换技）。
  -- 转换技标记值：<1 为阳(0)，>=1 为阴(1)
  room:setPlayerMark(player, MarkEnum.SwithSkillPreName .. KUANGYAN, isYang and fk.SwitchYin or fk.SwitchYang)
  return true
end

-- 共同的效果：发动狂言 + 给目标角色挂"必须包含你 / 无限制"
local function doJugong(room, player, from)
  invokeKuangyan(room, player)
  if from and not from.dead then
    room:setPlayerMark(from, MUST, 1)
    room:setPlayerMark(from, FREE_DIST, 1)
    room:setPlayerMark(from, FREE_TIMES, 1)
  end
end

-- 统一的发动询问：只有玩家真的选了"发动"才记账，取消则回滚，
-- 否则一旦误点取消/超时，本回合这个角色就再也触发不了了。
local function askInvoke(room, player, from, promptKey)
  return room:askToSkillInvoke(player, {
    skill_name = j_xuyou_jugong.name,
    prompt = promptKey .. "::" .. from.id,
  })
end

-- 触发①：其他角色造成伤害
j_xuyou_jugong:addEffect(fk.Damaged, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xuyou_jugong.name) or player.dead then return false end
    if player:getMark(USED) > 0 then return false end
    local from = data and data.from
    if not from or from == player or from.dead then return false end
    -- 每名角色每回合首次造成伤害
    return from:getMark(FIRST_DMG) == 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if room:askToSkillInvoke(player, {
      skill_name = j_xuyou_jugong.name,
      prompt = "#j_xuyou_jugong-invoke::" .. from.id,
    }) then
      room:setPlayerMark(from, FIRST_DMG, 1)
      room:setPlayerMark(player, USED, 1)
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    doJugong(player.room, player, data.from)
  end,
})

-- 触发②：其他角色获得牌
-- 只取"本回合还没被记过"的角色，否则同一批移动里第一个人挡在前面会让技能永远不触发
-- 【注意】摸牌阶段的正常摸牌不算"获得牌"（否则每名角色每个回合都会白送一次发动机会）。
-- 写法参照官方 julian.lua：moveReason == ReasonDraw 且移动时正处于其摸牌阶段 → 跳过。
local function isPhaseDraw(move)
  return move.moveReason == fk.ReasonDraw and move.to ~= nil and move.to.phase == Player.Draw
end

local function findGainFrom(player, data)
  for _, move in ipairs(data) do
    local to = move.to
    if to and to ~= player and not to.dead
      and move.toArea == Card.PlayerHand
      and move.from ~= to
      and to:getMark(FIRST_GAIN) == 0
      and not isPhaseDraw(move) then
      return to
    end
  end
  return nil
end

j_xuyou_jugong:addEffect(fk.AfterCardsMove, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xuyou_jugong.name) or player.dead then return false end
    if player:getMark(USED) > 0 then return false end
    local from = findGainFrom(player, data)
    if not from then return false end
    -- 缓存下来，避免 on_cost/on_use 里再次遍历时状态已变化
    event:setSkillData(self, "jugong_gain_from", from)
    return true
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local from = event:getSkillData(self, "jugong_gain_from")
    if not from or from.dead then return false end
    if room:askToSkillInvoke(player, {
      skill_name = j_xuyou_jugong.name,
      prompt = "#j_xuyou_jugong-invoke::" .. from.id,
    }) then
      room:setPlayerMark(from, FIRST_GAIN, 1)
      room:setPlayerMark(player, USED, 1)
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    doJugong(player.room, player, event:getSkillData(self, "jugong_gain_from"))
  end,
})

-- 其下次使用牌：目标必须包含许攸
j_xuyou_jugong:addEffect(fk.CardUsing, {
  global = true,
  on_cost = Util.TrueFunc,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xuyou_jugong.name) or player.dead then return false end
    local from = data and data.from
    if not from or from == player or from.dead then return false end
    if from:getMark(MUST) == 0 then return false end
    -- 响应牌（【闪】【无懈可击】等）没有可选目标，不消耗"下次使用牌"的机会
    if data.toCard then return false end
    if #(data.tos or {}) == 0 then return false end
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    room:setPlayerMark(from, MUST, 0)
    room:setPlayerMark(from, FREE_DIST, 0)
    room:setPlayerMark(from, FREE_TIMES, 0)
    if player.dead or not data.card then return end
    if table.contains(data.tos or {}, player) then return end

    -- 只有该牌本就可以指许攸时才强制加入目标（【桃】【无中生有】这类不能强加）
    local ok = pcall(function()
      local cs = data.card:getSkill(from)
      if not cs then return end
      if from:isProhibited(player, data.card) then return end
      if not Util.CardTargetFilter(cs, from, player, {}, data.card.subcards or {}, data.card, Util.DummyTable) then
        return
      end
      data.tos = data.tos or {}
      table.insert(data.tos, player)
    end)
    if not ok then return end
  end,
})

-- 测试1：其他角色首次造成伤害 → 可选发动一次狂言 + 挂"必须包含你"标记
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    me.hp = me.maxHp
    comp3.hp = comp3.maxHp
  end)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, KUANGYAN)
    table.shuffle(room.draw_pile)
    FkTest.setNextReplies(me, { "1" })
    local hp = me.hp
    room:damage{ from = comp2, to = comp3, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me:getMark("j_xuyou_jugong_used-turn"), 1, "倨功应记录本回合已发动")
    lu.assertTrue(comp2:getMark(MUST) > 0, "造成伤害的角色应被标记")
    lu.assertTrue(comp2:getMark(FREE_DIST) > 0, "应获得无距离限制")
    lu.assertTrue(comp2:getMark(FREE_TIMES) > 0, "应获得无次数限制")
  end)
end)

-- 测试2：其下次使用牌时，目标被强制加入许攸
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    me.hp = me.maxHp
    comp3.hp = comp3.maxHp
    room:setPlayerMark(comp2, MUST, 1)
    room:setPlayerMark(comp2, FREE_DIST, 1)
    room:setPlayerMark(comp2, FREE_TIMES, 1)
  end)
  FkTest.runInRoom(function()
    local card = room:printCard("slash", Card.Spade, 7)
    local use = { from = comp2, tos = { comp3 }, card = card }
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertTrue(table.contains(use.tos, me), "许攸应被强制加入目标")
    lu.assertEquals(comp2:getMark(MUST), 0, "标记应在下次使用牌后清除")
    lu.assertEquals(comp2:getMark(FREE_DIST), 0, "无距离限制应清除")
  end)
end)

-- 测试3：取消发动后本回合仍可再次触发（不会因为误点取消而整回合报废）
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    me.hp = me.maxHp
    comp3.hp = comp3.maxHp
    room:setPlayerMark(me, USED, 0)
    room:setPlayerMark(comp2, FIRST_DMG, 0)
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "" })   -- AskForSkillInvoke 的取消回复是空串
    room:damage{ from = comp2, to = comp3, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me:getMark(USED), 0, "取消后不应记录为已发动")
    lu.assertEquals(comp2:getMark(FIRST_DMG), 0, "取消后不应占用本回合的首次名额")
    lu.assertEquals(comp2:getMark(MUST), 0, "取消后不应挂标记")

    -- 同一回合内再次造成伤害，仍应可以发动
    FkTest.setNextReplies(me, { "1" })
    room:damage{ from = comp2, to = comp3, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me:getMark(USED), 1, "再次触发时应能发动")
    lu.assertTrue(comp2:getMark(MUST) > 0, "应挂上必须包含标记")
  end)
end)

-- 测试4：-turn 标记由引擎自动清理（不依赖自建 TurnEnd 效果）
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jugong.name)
    room:setPlayerMark(me, USED, 1)
    room:setPlayerMark(comp2, FIRST_DMG, 1)
    lu.assertEquals(me:getMark(USED), 1, "前置")
    -- 引擎的阶段性清理（回合开始/结束都会调）
    room:clearHistory(Player.HistoryTurn)
    lu.assertEquals(me:getMark(USED), 0, "回合结束后本回合发动记录应被清理")
    lu.assertEquals(comp2:getMark(FIRST_DMG), 0, "回合结束后首次记录应被清理")
  end)
end)

-- 测试5：真实对局路径（room.current = 其他角色）+ 狂言确实执行
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    room.current = comp2            -- 关键：模拟"其他角色的回合"
    me.phase = Player.Idle
    me.hp = me.maxHp
    comp3.hp = comp3.maxHp
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. KUANGYAN, 0)  -- 阳
    table.shuffle(room.draw_pile)
    -- 清空许攸手牌，只留 1 张【杀】 → 阳形态必然要继续摸牌
    for _, id in ipairs(me:getCardIds("h")) do
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, "test")
    end
    local c = room:printCard("slash", Card.Spade, 3)
    room:obtainCard(me, { c.id }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    local before = #me:getCardIds("h")
    room:damage { from = comp2, to = comp3, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me:getMark(USED), 1, "应已发动倨功")
    lu.assertTrue(comp2:getMark(MUST) > 0, "应挂必须包含标记")
    lu.assertTrue(#me:getCardIds("h") > before,
      "狂言阳形态应摸牌（before=" .. before .. ", after=" .. #me:getCardIds("h") .. "）")
    lu.assertEquals(me:getSwitchSkillState(KUANGYAN), fk.SwitchYin,
      "发动一次狂言后形态应翻转为阴")
  end)
end)

-- 测试6：真实 room:useCard 路径下，目标被强制加入许攸
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    room.current = comp2
    me.hp = me.maxHp
    comp3.hp = comp3.maxHp
    comp2.hp = comp2.maxHp
    room:setPlayerMark(comp2, MUST, 1)
  end)
  FkTest.runInRoom(function()
    local card = room:printCard("slash", Card.Spade, 7)
    local use = { from = comp2, tos = { comp3 }, card = card }
    -- comp3 不出【闪】；受 1 点伤害不影响后续断言
    FkTest.setNextReplies(comp3, { "" })
    room:useCard(use)
    lu.assertTrue(table.contains(use.tos or {}, me),
      "真实出牌时许攸应被强制加入目标，实际目标数=" .. #(use.tos or {}))
    lu.assertEquals(comp2:getMark(MUST), 0, "使用后应清除标记")
  end)
end)

-- 测试7：其他角色"获得牌"（真实摸牌）也能触发
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    room.current = comp2
    me.phase = Player.Idle
    me.hp = me.maxHp
    room:setPlayerMark(me, USED, 0)
    room:setPlayerMark(comp2, FIRST_GAIN, 0)
    table.shuffle(room.draw_pile)
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    comp2:drawCards(1, "test")
    lu.assertEquals(me:getMark(USED), 1, "其他角色摸牌应能触发倨功")
    lu.assertTrue(comp2:getMark(MUST) > 0, "摸牌的角色应被挂上标记")
  end)
end)

-- 测试8：摸牌阶段的正常摸牌不算"首次获得牌"（否则每人每回合都会白送一次）
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    room.current = comp2
    me.phase = Player.Idle
    me.hp = me.maxHp
    room:setPlayerMark(me, USED, 0)
    room:setPlayerMark(comp2, FIRST_GAIN, 0)
    table.shuffle(room.draw_pile)
  end)
  FkTest.runInRoom(function()
    comp2.phase = Player.Draw
    FkTest.setNextReplies(me, { "1" })
    room:drawCards(comp2, 2, "phase_draw")
    lu.assertEquals(me:getMark(USED), 0, "摸牌阶段的摸牌不应触发倨功, USED=" .. tostring(me:getMark(USED)))
    lu.assertEquals(comp2:getMark(MUST), 0, "摸牌阶段不应挂标记")

    -- 摸牌阶段结束后（非摸牌阶段）获得的牌仍然照常触发
    comp2.phase = Player.Play
    FkTest.setNextReplies(me, { "1" })
    comp2:drawCards(1, "test")
    lu.assertEquals(me:getMark(USED), 1, "非摸牌阶段的摸牌应能触发倨功")
    lu.assertTrue(comp2:getMark(MUST) > 0, "应挂上必须包含标记")
  end)
end)

-- 测试9：倨功发动时若狂言为阴形态，必须弹出保留牌型的选择（而不是悄悄跳过）
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  local asked = 0
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    room.current = comp2
    me.hp = me.maxHp
    comp3.hp = comp3.maxHp
    room:setPlayerMark(me, USED, 0)
    room:setPlayerMark(comp2, FIRST_DMG, 0)
    -- 阴形态
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. KUANGYAN, 1)
    for _, id in ipairs(me:getCardIds("h")) do
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, "test")
    end
    room:obtainCard(me, {
      room:printCard("slash", Card.Spade, 3).id,
      room:printCard("dismantlement", Card.Club, 5).id,
      room:printCard("qinggang_sword", Card.Diamond, 6).id,
    }, true, fk.ReasonDraw, me, "test")
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      if params.skill_name == KUANGYAN then
        asked = asked + 1
        return "j_xuyou_kuangyan:basic"
      end
      return origChoice(self, who, params)
    end
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room:damage{ from = comp2, to = comp3, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(asked, 1, "倨功触发阴形态狂言应弹出保留牌型选择")
    local seen = {}
    for _, id in ipairs(me:getCardIds("h")) do
      seen[Fk:getCardById(id).type] = true
    end
    lu.assertTrue(seen[Card.TypeTrick] == nil, "选基本牌后锦囊牌应被弃置")
  end)
end)

return j_xuyou_jugong
