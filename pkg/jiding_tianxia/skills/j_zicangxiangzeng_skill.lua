local j_zicangxiangzeng_skill = fk.CreateSkill {
  name = "j_zicangxiangzeng_skill",
}

Fk:loadTranslationTable{
  ["j_zicangxiangzeng_skill"] = "指仓相赠",
  [":j_zicangxiangzeng_skill"] = "出牌阶段，对一名角色使用，将其置于其判定区。判定阶段，若判定结果与此牌花色相同或点数奇偶相同，判定者获得此判定牌并置于其武将牌上（可以当手牌使用），然后继续判定；否则判定者摸两张牌。",

  ["#j_zicangxiangzeng_skill"] = "指仓相赠",
}

-- 判定阶段结算（判定区牌由引擎移入处理区后触发）：发起判定，结果由“囷”技能处理
j_zicangxiangzeng_skill:addEffect("cardskill", {
  prompt = "#j_zicangxiangzeng_skill",
  -- 允许指定任意角色（含自己）；注意 CardTargetFilter 依赖 modTargetFilter 返回值，必须返回 true
  mod_target_filter = function(self, player, to_select, selected, card, distance_limited)
    return true
  end,
  target_filter = Util.CardTargetFilter,
  target_num = 1,
  on_effect = function(self, room, effect)
    local to = effect.to
    local card = effect.card
    -- 统一以实体牌记录（转化使用时取子牌）
    local real_id = card:isVirtual() and card.subcards[1] or card.id
    room:setCardMark(Fk:getCardById(real_id), "j_zicang_target", to.id)
    -- 生效结算时记录使用者（判定阶段结算由囷消费该标记）
    if effect.from then
      room:setCardMark(Fk:getCardById(real_id), "j_zicang_source", effect.from.id)
    end
    room:setPlayerMark(to, "j_zicang_in_judge", real_id)

    -- 场上必须存在拥有【囷】的存活角色来收取判定牌；否则无囷处理判定，
    -- 判定结果按失败结算（判定者摸两张、指仓相赠弃置），避免无终止依据的连续空转
    local has_qun_handler = false
    for _, p in ipairs(room.players) do
      if p:isAlive() and p:hasSkill("j_qun") then
        has_qun_handler = true
        break
      end
    end
    if not has_qun_handler then
      to:drawCards(2, "j_zicangxiangzeng_skill")
      local fail_move = { ids = { real_id }, toArea = Card.DiscardPile, moveReason = fk.ReasonPut, skillName = "j_zicangxiangzeng_skill" }
      if card:isVirtual() then fail_move.virtualEquip = card end
      room:moveCards(fail_move)
      room:setPlayerMark(to, "j_zicang_in_judge", 0)
      return
    end

    -- 洛神式连续判定：判定牌与此牌花色相同或点数奇偶相同 → 由“囷”收取判定牌并继续判定；
    -- 失败 → “囷”清除判定区记录（指仓相赠进弃牌堆）后循环结束
    local guard = 0
    while to:isAlive() and to:getMark("j_zicang_in_judge") ~= 0 do
      guard = guard + 1
      if guard > 100 then break end -- 保险丝，正常流程不会触发
      room:judge{ who = to, reason = "j_zicangxiangzeng", pattern = "." }
    end

    -- 异常兜底（判定被强制中断等）：确保指仓相赠离开并清除标记
    if to:getMark("j_zicang_in_judge") ~= 0 then
      local leftover_id = to:getMark("j_zicang_in_judge")
      local leftover = Fk:getCardById(leftover_id)
      if leftover and room:getCardArea(leftover_id) == Card.Processing then
        local move = { ids = { leftover_id }, toArea = Card.DiscardPile, moveReason = fk.ReasonPut, skillName = "j_zicangxiangzeng_skill" }
        if card:isVirtual() then move.virtualEquip = card end
        room:moveCards(move)
      end
      room:setPlayerMark(to, "j_zicang_in_judge", 0)
    end
  end,
  on_nullified = function(self, room, effect)
    local card = effect.card
    local real_id = card:isVirtual() and card.subcards[1] or card.id
    local move = { ids = { real_id }, toArea = Card.DiscardPile, moveReason = fk.ReasonPut, skillName = "j_zicangxiangzeng_skill" }
    if card:isVirtual() then move.virtualEquip = card end
    room:moveCards(move)
    if effect.to then
      room:setPlayerMark(effect.to, "j_zicang_in_judge", 0)
    end
  end,
})

-- 测试辅助：将牌正确置入牌堆顶（moveCards 会同步维护 card_place，避免脏 id）
local function putOnTop(room, id)
  room:moveCards{ ids = { id }, toArea = Card.DrawPile, moveReason = fk.ReasonJustMove, drawPilePosition = 1 }
end

-- 端到端：判定阶段结算 → 洛神式循环——匹配的判定牌逐个入囷（可当手牌使用），失败后判定者摸两张、指仓相赠弃置
j_zicangxiangzeng_skill:addTest(function(room, me)
  local comp2 = room.players[2]
  local zicang
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "j_qun")
    zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)
    room:moveCardTo(zicang.id, Card.Processing, nil, fk.ReasonPut, "phase_judge")

    -- 判定牌1：方块9（点数奇偶与5相同 → 匹配）；判定牌2：黑桃4（不匹配）
    local j1 = room:printCard("peach", Card.Diamond, 9)
    local j2 = room:printCard("slash", Card.Spade, 4)
    putOnTop(room, j2.id)
    putOnTop(room, j1.id)
  end)

  FkTest.runInRoom(function()
    local hand_before = #comp2:getCardIds("h")
    local eff = CardEffectData:new{ card = Fk:getCardById(zicang.id), to = comp2, tos = { comp2 } }
    room:doCardEffect(eff)

    lu.assertEquals(#comp2:getPile("j_qun"), 1, "匹配的判定牌应置于武将牌")
    lu.assertEquals(comp2:getMark("@j_qun"), 1, "判定者应有囷标记")
    lu.assertEquals(#comp2:getCardIds("h"), hand_before + 2, "失败后判定者应摸两张牌")
    lu.assertEquals(comp2:getMark("j_zicang_in_judge"), 0, "循环结束后判定区记录应清除")
    lu.assertEquals(room:getCardArea(zicang.id), Card.DiscardPile, "指仓相赠应进入弃牌堆")
  end)
end)

-- 端到端：连续多张判定牌匹配 → 全部入囷（洛神式多次循环），直到失败才停止
j_zicangxiangzeng_skill:addTest(function(room, me)
  local comp2 = room.players[2]
  local zicang
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "j_qun")
    zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)
    room:moveCardTo(zicang.id, Card.Processing, nil, fk.ReasonPut, "phase_judge")

    -- 判定牌1、2：方块9、红桃3（均匹配）；判定牌3：黑桃4（不匹配）
    local j1 = room:printCard("peach", Card.Diamond, 9)
    local j2 = room:printCard("slash", Card.Heart, 3)
    local j3 = room:printCard("jink", Card.Spade, 4)
    putOnTop(room, j3.id)
    putOnTop(room, j2.id)
    putOnTop(room, j1.id)
  end)

  FkTest.runInRoom(function()
    local hand_before = #comp2:getCardIds("h")
    local eff = CardEffectData:new{ card = Fk:getCardById(zicang.id), to = comp2, tos = { comp2 } }
    room:doCardEffect(eff)

    local pile = comp2:getPile("j_qun")
    lu.assertEquals(#pile, 2, "连续匹配的判定牌应全部入囷")
    lu.assertEquals(comp2:getMark("@j_qun"), 2, "囷标记应同步为2")
    lu.assertEquals(#comp2:getCardIds("h"), hand_before + 2, "失败后判定者应摸两张牌")
    lu.assertEquals(comp2:getMark("j_zicang_in_judge"), 0, "循环结束后判定区记录应清除")
  end)
end)

-- 测试：目标选择——自己和他人均可被指定为目标（mod_target_filter 必须放行）
j_zicangxiangzeng_skill:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    local card = Fk:cloneCard("j_zicangxiangzeng", Card.Spade, 5)
    local sk = card:getSkill(me)
    lu.assertTrue(sk ~= nil, "应能取得卡牌技能")
    lu.assertTrue(Util.CardTargetFilter(sk, me, me, {}, {}, card, {}), "可指定自己为目标")
    lu.assertTrue(Util.CardTargetFilter(sk, me, comp2, {}, {}, card, {}), "可指定其他角色为目标")
  end)
end)

-- 测试：判定者没有任何囷（场上无计鲁肃/无囷技能）时，判定直接按失败结算，
-- 不得出现无终止依据的连续空转（“一直判定”）
j_zicangxiangzeng_skill:addTest(function(room, me)
  local comp2 = room.players[2]
  local zicang
  FkTest.runInRoom(function()
    -- me 默认没有 j_qun（测试房为郭嘉），模拟场上无囷处理者
    zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)
    room:moveCardTo(zicang.id, Card.Processing, nil, fk.ReasonPut, "phase_judge")

    -- 判定牌1：黑桃4（即使有囷也不匹配）
    local j1 = room:printCard("slash", Card.Spade, 4)
    room:moveCards{ ids = { j1.id }, toArea = Card.DrawPile, moveReason = fk.ReasonJustMove, drawPilePosition = 1 }
  end)

  FkTest.runInRoom(function()
    local hand_before = #comp2:getCardIds("h")
    local eff = CardEffectData:new{ card = Fk:getCardById(zicang.id), to = comp2, tos = { comp2 } }
    room:doCardEffect(eff)
    lu.assertEquals(comp2:getMark("j_zicang_in_judge"), 0, "无囷时判定应结束并清标记")
    lu.assertEquals(#comp2:getCardIds("h"), hand_before + 2, "无囷时判定者应摸两张牌（按失败结算）")
    lu.assertEquals(room:getCardArea(zicang.id), Card.DiscardPile, "无囷时指仓相赠应进入弃牌堆")
  end)
end)

-- 诊断：牌堆顶连续多张匹配 → 循环逐张入囷，直到不匹配停止（确认不会失控）
j_zicangxiangzeng_skill:addTest(function(room, me)
  local comp2 = room.players[2]
  local zicang
  FkTest.runInRoom(function()
    -- me 获得囷（测试房里 me 默认无技能，必须显式添加）
    room:handleAddLoseSkills(me, "j_qun")
    zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5 -- 奇数：奇数点判定牌全部匹配
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)
    room:moveCardTo(zicang.id, Card.Processing, nil, fk.ReasonPut, "phase_judge")

    -- 顶10张全奇数点（匹配），第11张偶数（不匹配，终止循环）
    local odd_pts = { 3, 5, 7, 9, 11, 13, 3, 5, 7, 9 }
    local ids = {}
    for _, n in ipairs(odd_pts) do
      local j = room:printCard("peach", Card.Heart, n)
      table.insert(ids, j.id)
    end
    local tail = room:printCard("slash", Card.Spade, 4)
    -- 置顶顺序：先插最后才被翻到的（tail 在最底），ids 倒序插入使 ids[1] 位于牌堆顶
    room:moveCards{ ids = { tail.id }, toArea = Card.DrawPile, moveReason = fk.ReasonJustMove, drawPilePosition = 1 }
    for i = #ids, 1, -1 do
      room:moveCards{ ids = { ids[i] }, toArea = Card.DrawPile, moveReason = fk.ReasonJustMove, drawPilePosition = 1 }
    end
  end)

  FkTest.runInRoom(function()
    local eff = CardEffectData:new{ card = Fk:getCardById(zicang.id), to = comp2, tos = { comp2 } }
    room:doCardEffect(eff)
    lu.assertEquals(#comp2:getPile("j_qun"), 10, "连续匹配的判定牌应全部入囷（10张）")
    lu.assertEquals(comp2:getMark("j_zicang_in_judge"), 0, "遇到不匹配后循环应终止")
  end)
end)

return j_zicangxiangzeng_skill
