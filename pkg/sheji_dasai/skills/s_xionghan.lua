-- 超人强一号 · 雄捍（s_xionghan）
-- 每轮开始时限x次（x暂按当前体力值），你可以选择一名角色，令其将一张牌置于你的武将牌上，称为「盾」。
-- 当你受到伤害时，可移去任意张「盾」，防止等量伤害。
local s_xionghan = fk.CreateSkill {
  name = "s_xionghan",
  derived_piles = "chaorenqiang_shield",
}

Fk:loadTranslationTable {
  ["s_xionghan"] = "雄捍",
  [":s_xionghan"] = "每轮开始时限X次（X为你的体力值），你可以选择一名角色，令其将一张牌置于你的武将牌上，称为「盾」。当你受到伤害时，可移去任意张「盾」，防止等量伤害。",
  ["chaorenqiang_shield"] = "盾",
  ["#s_xionghan-invoke"] = "雄捍：你可以发动雄捍（本轮还可发动 %arg 次）",
  ["#s_xionghan-choose"] = "雄捍：选择一名角色，令其将一张牌置于你的武将牌上",
  ["#s_xionghan-give"] = "雄捍：请将一张牌置于 %dest 的武将牌上",
  ["#s_xionghan-shield"] = "雄捍：你可以移去任意张「盾」防止等量伤害",
  ["$s_xionghan1"] = "盾甲护身，万夫莫开！",
  ["$s_xionghan2"] = "守住此盾，便是守住生机！",
}

s_xionghan:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_xionghan.name) then return false end
    if target ~= player or target.phase ~= Player.Start then return false end
    -- 每回合开始限 X 次（X 为当前体力值），同一时机可连续发动
    return player:usedSkillTimes(s_xionghan.name, Player.HistoryTurn) < player.hp
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    while player:usedSkillTimes(s_xionghan.name, Player.HistoryTurn) < player.hp do
      local left = player.hp - player:usedSkillTimes(s_xionghan.name, Player.HistoryTurn)
      if not room:askToSkillInvoke(player, s_xionghan.name, "#s_xionghan-invoke:::"..left) then
        break
      end
      local tos = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = 1,
        targets = room.alive_players,
        skill_name = s_xionghan.name,
        prompt = "#s_xionghan-choose",
        cancelable = false,
      })
      if #tos == 0 then break end
      local to = tos[1]
      if to.dead then break end
      local ids = room:askToChooseCards(to, {
        target = to,
        min = 1,
        max = 1,
        flag = "he",
        skill_name = s_xionghan.name,
        prompt = "#s_xionghan-give:::"..player.id,
        cancelable = true,
      })
      if #ids == 0 then break end
      -- 将牌置于超人强的武将牌上，称为「盾」（牌从 to 的区域移走）
      player:addToPile("chaorenqiang_shield", ids, true, s_xionghan.name, to)
      player:setSkillUseHistory(s_xionghan.name, 1, Player.HistoryTurn)
      room:notifySkillInvoked(player, s_xionghan.name, "defensive")
      player:broadcastSkillInvoke(s_xionghan.name)
    end
  end,
})

-- 受伤害时移盾防止等量伤害
s_xionghan:addEffect(fk.DetermineDamageInflicted, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_xionghan.name) then return false end
    if data.to ~= player then return false end
    if data.damage < 1 then return false end
    return #player:getPile("chaorenqiang_shield") > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local pile = player:getPile("chaorenqiang_shield")
    local ids = room:askToChooseCards(player, {
      target = player,
      min = 0,
      max = #pile,
      flag = { card_data = { { "chaorenqiang_shield", pile } } },
      skill_name = s_xionghan.name,
      prompt = "#s_xionghan-shield",
      cancelable = true,
    })
    if #ids == 0 then return false end
    return { ids = ids }
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = data.ids
    room:throwCard(ids, fk.ReasonDiscard, s_xionghan.name, player, player)
    if data.damage > #ids then
      data:changeDamage(-#ids)
    else
      data.damage = 0
    end
    -- 竞勇联动：移盾抵消伤害后，伤害来源选择
    local jy = Fk.skills["s_jingyong"]
    if player:hasSkill("s_jingyong") and jy then
      jy:triggerFromShield(player, data.from)
    end
  end,
})

-- 测试1：回合开始发动雄捍，令其他角色将一张牌置于武将牌（盾）
s_xionghan:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_xionghan.name)
    room:handleAddLoseSkills(me, "s_jingyong")
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    room.current = me
    me.phase = Player.Start
    local h = room:printCard("slash", Card.Spade, 3)
    room:obtainCard(comp2, { h }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local h = comp2:getCardIds("h")[1]
    FkTest.setNextReplies(me, { "1", { card = { subcards = {} }, targets = { comp2.id } } })
    FkTest.setNextReplies(comp2, { { h } })
    room.logic:trigger(fk.EventPhaseStart, me, {})
    local pile = me:getPile("chaorenqiang_shield")
    lu.assertEquals(#pile, 1, "雄捍：应获得1张盾")
    lu.assertTrue(table.contains(pile, h), "雄捍：盾应为所选牌")
    lu.assertFalse(table.contains(comp2:getCardIds("h"), h), "雄捍：该牌应离开其手牌")
  end)
end)

-- 测试2：移盾防止伤害 + 竞勇选摸牌
s_xionghan:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_xionghan.name)
    room:handleAddLoseSkills(me, "s_jingyong")
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    local sl = room:printCard("slash", Card.Spade, 3)
    me:addToPile("chaorenqiang_shield", { sl }, true, s_xionghan.name, me)
  end)
  FkTest.runInRoom(function()
    local pile = me:getPile("chaorenqiang_shield")
    lu.assertEquals(#pile, 1, "前置：应有1张盾")
    local hBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { { pile[1] } })
    FkTest.setNextReplies(comp2, { "s_jingyong_draw" })
    room:damage{ from = comp2, to = me, damage = 1, skillName = "test" }
    lu.assertEquals(me.hp, 4, "雄捍：移盾应防止1点伤害")
    lu.assertEquals(#me:getPile("chaorenqiang_shield"), 0, "雄捍：盾应被移去")
    lu.assertEquals(#me:getCardIds("h"), hBefore + 2, "竞勇：选摸牌应摸2张")
  end)
end)

-- 测试3：移盾防止伤害 + 竞勇选视为来源使用决斗
s_xionghan:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_xionghan.name)
    room:handleAddLoseSkills(me, "s_jingyong")
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    local sl = room:printCard("slash", Card.Spade, 3)
    me:addToPile("chaorenqiang_shield", { sl }, true, s_xionghan.name, me)
  end)
  FkTest.runInRoom(function()
    local pile = me:getPile("chaorenqiang_shield")
    lu.assertEquals(#pile, 1, "前置：应有1张盾")
    FkTest.setNextReplies(me, { { pile[1] } })
    -- 竞勇选1：视为 comp2 对 me 使用决斗；me 不出杀 → 受1点决斗伤害
    FkTest.setNextReplies(comp2, { "s_jingyong_duel" })
    FkTest.setNextReplies(me, { "0" })
    room:damage{ from = comp2, to = me, damage = 1, skillName = "test" }
    lu.assertEquals(me.hp, 3, "竞勇：盾防住1点后，决斗再造成1点伤害")
  end)
end)

return s_xionghan