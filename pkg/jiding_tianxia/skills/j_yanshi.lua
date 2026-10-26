local j_yanshi = fk.CreateSkill {
  name = "j_yanshi",
}

Fk:loadTranslationTable{
  ["j_yanshi"] = "演势",
  [":j_yanshi"] = "出牌阶段限一次，你可以从牌堆顶或牌堆底摸一张牌并使用，若因此使用以此法获得的牌，此技能视为未发动过。",

  ["#j_yanshi-draw"] = "演势：选择从牌堆顶或牌堆底摸一张牌",
  ["#j_yanshi-use"] = "演势：你可以使用摸到的牌",
  ["#j_yanshi-forced"] = "演势：摸到的牌当前无法使用，你可以弃置此牌并视为使用，此技能视为未发动过",
  ["j_yanshi__top"] = "牌堆顶",
  ["j_yanshi__bottom"] = "牌堆底",
  ["j_yanshi__force"] = "弃置并视为使用",
  ["j_yanshi__abandon"] = "放弃",

  ["$j_yanshi1"] = "卧龙待时，一鸣惊人！",
  ["$j_yanshi2"] = "静观其变，乘势而起！",
}

-- 演势：主动技，摸一张并使用，使用摸到的牌则不消耗限次
j_yanshi:addEffect("active", {
  anim_type = "draw",
  card_num = 0,
  can_use = function(self, player)
    if player:getMark("j_yanshi_used") ~= 0 then return false end
    return player.phase == Player.Play
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    -- 标记已发动（若使用摸到的牌则视为未发动）
    room:setPlayerMark(player, "j_yanshi_used", 1)
    local choice = room:askToChoice(player, {
      choices = { "j_yanshi__top", "j_yanshi__bottom" },
      skill_name = j_yanshi.name,
      prompt = "#j_yanshi-draw",
    })
    local fromPlace = choice == "j_yanshi__bottom" and "bottom" or "top"

    -- 摸一张（drawCards 返回摸到的牌 id）
    local ids = player:drawCards(1, j_yanshi.name, fromPlace)
    local drawnId = ids and ids[1]
    if not drawnId then return end

    -- 记录摸到的牌：若使用它则视为未发动
    local drawn = room:getTag("j_yanshi_drawn") or {}
    drawn[drawnId] = true
    room:setTag("j_yanshi_drawn", drawn)

    local card = Fk:getCardById(drawnId)

    -- 先临时绕过使用次数限制（演势摸出的杀/酒不计入次数），判断能否主动使用；
    -- 同时绕过距离限制（演势摸出的杀无视距离，可指定任意其他角色为目标）
    room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 1)
    local canAsk = card.is_passive or player:canUse(card, { bypass_times = true, bypass_distances = true })
    room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 0)

    if not canAsk then
      -- 摸到的牌当前无法主动使用（满血桃、无合法目标的借刀、判定区已满的闪电等）：
      -- 提供"视为使用"选项，弃置摸到的牌并视为已使用，技能流程不会断掉
      local forced = room:askToChoice(player, {
        choices = { "j_yanshi__force", "j_yanshi__abandon" },
        skill_name = j_yanshi.name,
        prompt = "#j_yanshi-forced",
      })
      if forced == "j_yanshi__force" then
        room:throwCard(drawnId, j_yanshi.name, player, player)
        room:setPlayerMark(player, "j_yanshi_used", 0)
      end
      return
    end

    -- 可主动使用（含绕过次数限制的杀/酒；响应牌闪/无懈视为主动使用）
    -- 注意：不能传 skill_name=j_yanshi（主动技会让客户端 ReqActiveSkill.cardFilter
    -- 用主动技的 max_card_num（nil）判定，所有牌不可选，表现为"摸完牌没法使用"）
    -- 使用期间挂 BypassDistancesLimit：演势摸到的杀可无视距离指定任意目标
    room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 1)
    room:setPlayerMark(player, MarkEnum.BypassDistancesLimit, 1)
    local use = room:askToUseCard(player, {
      pattern = card.name,
      prompt = "#j_yanshi-use",
      cancelable = true,
    })
    if use then
      use.extraUse = true -- 使用摸到的牌不计入次数限制（杀/酒）
      room:useCard(use)
    end
    room:setPlayerMark(player, MarkEnum.BypassDistancesLimit, 0)
    room:setPlayerMark(player, MarkEnum.BypassTimesLimit, 0)
    -- 未使用：限次保持消耗（mark 已置 1）
  end,
})

-- 使用了摸到的牌 → 视为未发动过（限次不消耗）
j_yanshi:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_yanshi.name) then return false end
    if player:getMark("j_yanshi_used") ~= 1 then return false end
    if not data or not data.card then return false end
    local drawn = player.room:getTag("j_yanshi_drawn") or {}
    -- 直接使用真实摸到的牌：比较牌 id
    if drawn[data.card.id] then return true end
    -- 虚拟牌（转化/视为）：检查子牌
    for _, id in ipairs(data.card.subcards or {}) do
      if drawn[id] then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_yanshi_used", 0)
  end,
})

-- 每回合开始重置限次
j_yanshi:addEffect(fk.EventPhaseStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_yanshi.name) and player.phase == Player.Play
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_yanshi_used", 0)
  end,
})

-- 测试：演势摸一张（牌堆顶）并使用 → 视为未发动；不使用 → 消耗限次
j_yanshi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yanshi.name)
  end)

  -- 场景A：摸牌后使用该牌（模拟：使用的牌含演势摸到的牌）→ 标记回 0
  FkTest.runInRoom(function()
    room:setPlayerMark(me, "j_yanshi_used", 1)
    local top = room:getNCards(1, "top")
    local drawn = room:getTag("j_yanshi_drawn") or {}
    drawn[top[1]] = true
    room:setTag("j_yanshi_drawn", drawn)
    local vcard = Fk:cloneCard(Fk:getCardById(top[1]).name)
    vcard:addSubcard(top[1])
    local use = UseCardData:new{ from = me, card = vcard, tos = { comp2 } }
    room.logic:trigger(fk.CardUseFinished, me, use)
    lu.assertEquals(me:getMark("j_yanshi_used"), 0, "使用摸到的牌应视为未发动")
  end)

  -- 场景B：摸牌后不使用 → 限次消耗
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "j_yanshi__bottom" })
    -- 直接执行 active 效果：手动触发 onUse
    local skel = Fk.skills[j_yanshi.name]:getSkeleton()
    local eff = skel.effects[1]
    eff:onUse(room, { from = me })
    lu.assertEquals(me:getMark("j_yanshi_used"), 1, "未使用摸到的牌应消耗限次")
    lu.assertEquals(#me:getCardIds("h"), 1, "应从牌堆底摸一张")
  end)
end)

-- 测试：摸排并实际使用摸到的牌 → 视为未发动（限次不消耗）
j_yanshi:addTest(function(room, me)
  local comp2 = room.players[2]
  local c
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yanshi.name)
    me.phase = Player.Play
    -- 牌堆顶放一张无中生有
    c = room:printCard("ex_nihilo", Card.Heart, 7)
    room:moveCards{ ids = { c.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut, drawPilePosition = 1 }
  end)

  FkTest.runInRoom(function()
    local handBefore = #me:getCardIds("h")
    -- 回复：选"牌堆顶"；askToUseCard 选择摸到的无中生有使用
    FkTest.setNextReplies(me, { "j_yanshi__top", FkTest.ReplyCard(c, {}) })
    local skel = Fk.skills[j_yanshi.name]:getSkeleton()
    local eff = skel.effects[1]
    eff:onUse(room, { from = me })
    -- 使用摸到的牌 → 视为未发动（mark 回 0）
    lu.assertEquals(me:getMark("j_yanshi_used"), 0, "使用摸到的牌应视为未发动")
    -- 摸到的无中生有已被使用（不在手牌），且其效果摸 2 张
    lu.assertFalse(table.contains(me:getCardIds("h"), c.id), "摸到的牌应已被使用")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 2, "无中生有效果应摸两张")
  end)
end)

-- 测试：摸到无法主动使用的牌（满血桃）→ "视为使用"（弃置）→ 视为未发动，技能不断
j_yanshi:addTest(function(room, me)
  local peachId
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yanshi.name)
    me.phase = Player.Play
    local peach = room:printCard("peach", Card.Heart, 1)
    peachId = peach.id
    room:moveCards{ ids = { peach.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut, drawPilePosition = 1 }
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "j_yanshi__top", "j_yanshi__force" })
    local skel = Fk.skills[j_yanshi.name]:getSkeleton()
    local eff = skel.effects[1]
    eff:onUse(room, { from = me })
    lu.assertEquals(me:getMark("j_yanshi_used"), 0, "弃置并视为使用后应视为未发动")
    lu.assertFalse(table.contains(me:getCardIds("h"), peachId), "摸到的桃应已被弃置")
  end)
end)

-- 测试：摸到响应牌（闪）→ 可视为主动使用 → 使用后视为未发动
j_yanshi:addTest(function(room, me)
  local jinkId
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yanshi.name)
    me.phase = Player.Play
    local jink = room:printCard("jink", Card.Heart, 2)
    jinkId = jink.id
    room:moveCards{ ids = { jink.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut, drawPilePosition = 1 }
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "j_yanshi__top", FkTest.ReplyCard(Fk:getCardById(jinkId), {}) })
    local skel = Fk.skills[j_yanshi.name]:getSkeleton()
    local eff = skel.effects[1]
    eff:onUse(room, { from = me })
    lu.assertEquals(me:getMark("j_yanshi_used"), 0, "使用摸到的闪应视为未发动")
    lu.assertFalse(table.contains(me:getCardIds("h"), jinkId), "摸到的闪应已被使用")
  end)
end)

-- 测试：演势摸出的杀不计入次数限制（本回合已用 1 杀后仍可视为使用，且不计次数）
j_yanshi:addTest(function(room, me)
  local slashId
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yanshi.name)
    me.phase = Player.Play
    local slash = room:printCard("slash", Card.Spade, 7)
    slashId = slash.id
    room:moveCards{ ids = { slash.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut, drawPilePosition = 1 }
  end)
  FkTest.runInRoom(function()
    -- 模拟本回合已用过一次杀（次数限制已满）
    me:addCardUseHistory("slash", 1)
    lu.assertEquals(me:usedCardTimes("slash", Player.HistoryPhase), 1, "前置：本回合已用1杀")
    -- 摸排到杀并使用（指定 comp2）
    FkTest.setNextReplies(me, { "j_yanshi__top", FkTest.ReplyCard(Fk:getCardById(slashId), { comp2 }) })
    local skel = Fk.skills[j_yanshi.name]:getSkeleton()
    local eff = skel.effects[1]
    eff:onUse(room, { from = me })
    lu.assertEquals(me:getMark("j_yanshi_used"), 0, "使用摸到的杀应视为未发动")
    -- 演势摸出的杀不计入次数限制：次数仍为 1
    lu.assertEquals(me:usedCardTimes("slash", Player.HistoryPhase), 1, "演势摸出的杀不计入次数限制")
  end)
end)

return j_yanshi
