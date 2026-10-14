local j_bingxin = fk.CreateSkill {
  name = "j_bingxin",
}

Fk:loadTranslationTable{
  ["j_bingxin"] = "冰心",
  [":j_bingxin"] = "每轮限一次，每轮游戏开始时，你可将一张与「冰」花色不同的牌置于武将牌上称为「冰」。其他角色对你造成伤害时，需弃置一张与「冰」颜色相同的牌，否则伤害-1。",

  ["#j_bingxin-invoke"] = "冰心：是否将一张与「冰」花色不同的牌置于武将牌上？",
  ["#j_bingxin-place"] = "冰心：选择一张与「冰」花色不同的牌置于武将牌上",
  ["#j_bingxin-discard"] = "冰心：弃置一张与「冰」颜色相同的牌，否则本次伤害-1",

  ["$j_bingxin1"] = "冰心一片，日月可鉴。",
  ["$j_bingxin2"] = "至孝至诚，感动天地。",
}

-- 每轮游戏开始时放置「冰」（每轮限一次）
j_bingxin:addEffect(fk.RoundStart, {
  global = true,
  anim_type = "special",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_bingxin.name) or player.dead then return false end
    local room = player.room
    local round = room:getBanner("RoundCount") or 0
    if player:getMark("j_bingxin_round") == round then return false end
    -- 需要有与现有「冰」花色不同的手牌可放
    local ice = player:getPile("j_bing")
    for _, id in ipairs(player:getCardIds("h")) do
      local suit = Fk:getCardById(id).suit
      local dup = false
      for _, iid in ipairs(ice) do
        if Fk:getCardById(iid).suit == suit then dup = true break end
      end
      if not dup then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_bingxin.name, prompt = "#j_bingxin-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ice = player:getPile("j_bing")
    -- 过滤出与现有「冰」花色不同的手牌
    local candidates = {}
    for _, id in ipairs(player:getCardIds("h")) do
      local suit = Fk:getCardById(id).suit
      local dup = false
      for _, iid in ipairs(ice) do
        if Fk:getCardById(iid).suit == suit then dup = true break end
      end
      if not dup then table.insert(candidates, id) end
    end
    if #candidates == 0 then return end
    local id = room:askToChooseCard(player, {
      target = player, flag = { card_data = { { "$Hand", candidates } } },
      skill_name = j_bingxin.name, prompt = "#j_bingxin-place",
    })
    if id then
      player:addToPile("j_bing", id, true, j_bingxin.name)
      room:setPlayerMark(player, "j_bingxin_round", room:getBanner("RoundCount") or 0)
    end
  end,
})

-- 其他角色对你造成伤害时：弃一张与「冰」同色的牌，否则伤害-1
j_bingxin:addEffect(fk.DamageInflicted, {
  global = true,
  anim_type = "defense",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead then return false end
    if not player:hasSkill(j_bingxin.name) then return false end
    if #player:getPile("j_bing") == 0 then return false end
    if not data or not data.from or data.from == player or data.from.dead then return false end
    return data.damage >= 1
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local src = data.from
    local ice = player:getPile("j_bing")
    -- 与任一张「冰」颜色相同即可
    local handSame, equipSame = {}, {}
    for _, id in ipairs(src:getCardIds("h")) do
      local c = Fk:getCardById(id)
      for _, iid in ipairs(ice) do
        if Fk:getCardById(iid).color == c.color then
          table.insert(handSame, id)
          break
        end
      end
    end
    for _, id in ipairs(src:getCardIds("e")) do
      local c = Fk:getCardById(id)
      for _, iid in ipairs(ice) do
        if Fk:getCardById(iid).color == c.color then
          table.insert(equipSame, id)
          break
        end
      end
    end
    local dataList = {}
    if #handSame > 0 then table.insert(dataList, { "$Hand", handSame }) end
    if #equipSame > 0 then table.insert(dataList, { "$Equip", equipSame }) end
    if #dataList == 0 then
      -- 无同色牌可弃 → 伤害-1
      data:changeDamage(-1)
      return
    end
    local cards = room:askToChooseCards(src, {
      target = src, flag = { card_data = dataList },
      min = 1, max = 1, cancelable = true,
      skill_name = j_bingxin.name, prompt = "#j_bingxin-discard",
    })
    if cards and #cards > 0 then
      room:throwCard(cards, j_bingxin.name, src, player)
    else
      data:changeDamage(-1)
    end
  end,
})

j_bingxin:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_bingxin.name,
  think = function(self, player)
    return #player:getCardIds("h") > 0
  end,
})

-- 测试：轮开始时放冰；受伤害时来源弃同色牌则伤害不变，否则伤害-1
j_bingxin:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_bingxin.name)
    room:setBanner("RoundCount", 2)
    local c1 = room:printCard("slash", Card.Spade, 5)   -- 黑
    local c2 = room:printCard("jink", Card.Heart, 1)    -- 红
    local c3 = room:printCard("peach", Card.Club, 2)    -- 黑
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
  end)

  -- 场景A：轮开始时放置「冰」（选黑桃杀）→ 冰堆1张、每轮标记更新
  FkTest.runInRoom(function()
    local hand = me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", hand[1] })
    room.logic:trigger(fk.RoundStart, room.current, {})
    lu.assertEquals(#me:getPile("j_bing"), 1, "轮开始时应放置一张冰")
    lu.assertEquals(me:getMark("j_bingxin_round"), 2, "应记录本轮已放置")
  end)

  -- 场景B：伤害来源有同色牌（comp2 有一张黑牌）→ 弃同色 → 伤害不变
  FkTest.runInRoom(function()
    local black = room:printCard("slash", Card.Club, 3)
    room:obtainCard(comp2, { black }, true, fk.ReasonDraw, comp2, "test")
    local hpBefore = me.hp
    FkTest.setNextReplies(comp2, { { black.id } })
    room:damage{ from = comp2, to = me, damage = 2, damageType = fk.NormalDamage }
    lu.assertEquals(me.hp, hpBefore - 2, "来源弃同色牌后伤害应不变")
  end)

  -- 场景C：来源无同色牌 → 伤害-1
  FkTest.runInRoom(function()
    -- comp2 只剩红牌（冰是黑桃，红≠黑）
    local red = room:printCard("jink", Card.Heart, 4)
    room:obtainCard(comp2, { red }, true, fk.ReasonDraw, comp2, "test")
    local hpBefore = me.hp
    room:damage{ from = comp2, to = me, damage = 2, damageType = fk.NormalDamage }
    lu.assertEquals(me.hp, hpBefore - 1, "来源无同色牌可弃时伤害应-1")
  end)
end)

return j_bingxin