-- 舒邵一号·争赴
-- 当有角色脱离濒死状态后，你可以获得本回合进入弃牌堆的牌（至多为3）。若你本回合获得的牌=3张，则你下一次发动【散济】次数+1。
local s_shushao_zhengfu = fk.CreateSkill {
  name = "s_shushao_zhengfu",
}

Fk:loadTranslationTable{
  ["s_shushao_zhengfu"] = "争赴",
  [":s_shushao_zhengfu"] = "当有角色脱离濒死状态后，你可以获得本回合进入弃牌堆的牌（至多为3）。若你本回合获得的牌=3张，则你下一次发动【散济】次数+1。",

  ["#s_zhengfu-invoke"] = "争赴：是否获得本回合进入弃牌堆的牌（至多3张）？",

  ["$s_zhengfu1"] = "灾民争赴，仓廪再开！",
  ["$s_zhengfu2"] = "拾遗补缺，以济苍生！",
}

-- 记录本回合进入弃牌堆的牌（全局）
s_shushao_zhengfu:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_shushao_zhengfu.name) then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = room:getTag("s_zhengfu_discard-turn") or {}
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo) do
          table.insertIfNeed(ids, info.cardId)
        end
      end
    end
    room:setTag("s_zhengfu_discard-turn", ids)
  end,
})

-- 回合开始：清空记录
s_shushao_zhengfu:addEffect(fk.TurnStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(s_shushao_zhengfu.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setTag("s_zhengfu_discard-turn", {})
  end,
})

-- 有角色脱离濒死状态后：获得弃牌堆牌（至多3），满3张则散济次数+1
s_shushao_zhengfu:addEffect(fk.AfterDying, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_shushao_zhengfu.name) then return false end
    -- target 已脱离濒死（存活）
    if not target or target.dead then return false end
    local ids = player.room:getTag("s_zhengfu_discard-turn") or {}
    return #ids > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = s_shushao_zhengfu.name, prompt = "#s_zhengfu-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = room:getTag("s_zhengfu_discard-turn") or {}
    if #ids == 0 then return end
    -- 随机获得至多3张
    local got = table.randomPick(ids, math.min(3, #ids))
    room:obtainCard(player, got, true, fk.ReasonPrey, player, s_shushao_zhengfu.name)
    -- 记录本回合争赴获得的牌数（从弃牌堆获得的）
    local gotMark = player:getMark("@s_zhengfu_got-turn") + #got
    room:setPlayerMark(player, "@s_zhengfu_got-turn", gotMark)
    -- 若本回合获得=3张：散济次数+1
    if gotMark >= 3 then
      room:setPlayerMark(player, "@s_sanji_bonus", player:getMark("@s_sanji_bonus") + 1)
      room:setPlayerMark(player, "@s_zhengfu_got-turn", 0)
    end
  end,
})

-- 测试：有角色脱离濒死 → 获得弃牌堆牌（不足3张不触发加成）
s_shushao_zhengfu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_shushao_zhengfu.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 1
    -- 弃一张牌进弃牌堆
    local h1 = room:printCard("slash", Card.Spade, 3)
    room:throwCard({ h1 }, "test", comp2, comp2)
  end)

  FkTest.runInRoom(function()
    local got = room:getTag("s_zhengfu_discard-turn") or {}
    lu.assertEquals(#got, 1, "争赴：应记录1张进弃牌堆的牌")
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1" })
    -- 模拟 comp2 脱离濒死（AfterDying 事件）
    room.logic:trigger(fk.AfterDying, comp2, { who = comp2 })
    lu.assertEquals(#me:getCardIds("h"), handBefore + 1, "争赴：应获得1张弃牌堆牌")
    lu.assertEquals(me:getMark("@s_zhengfu_got-turn"), 1, "争赴：应记录获得1张")
    lu.assertEquals(me:getMark("@s_sanji_bonus"), 0, "争赴：未满3张不应加成散济")
  end)
end)

-- 测试：获得3张 → 散济次数+1
s_shushao_zhengfu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_shushao_zhengfu.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 1
    local h1 = room:printCard("slash", Card.Spade, 3)
    local h2 = room:printCard("slash", Card.Heart, 4)
    local h3 = room:printCard("dodge", Card.Club, 5)
    room:throwCard({ h1, h2, h3 }, "test", comp2, comp2)
  end)

  FkTest.runInRoom(function()
    local got = room:getTag("s_zhengfu_discard-turn") or {}
    lu.assertEquals(#got, 3, "争赴：应记录3张进弃牌堆的牌")
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.AfterDying, comp2, { who = comp2 })
    lu.assertEquals(#me:getCardIds("h"), handBefore + 3, "争赴：应获得3张弃牌堆牌")
    lu.assertEquals(me:getMark("@s_sanji_bonus"), 1, "争赴：满3张应使散济次数+1")
    lu.assertEquals(me:getMark("@s_zhengfu_got-turn"), 0, "争赴：加成后应重置本回合获得数")
  end)
end)

return s_shushao_zhengfu