-- 君袁术·骄侈
-- 出牌阶段开始时，你可弃置x张手牌，获得x枚"粮"。若你弃置的是装备牌，额外获得一枚"粮"。当你失去一张"粮"时，你摸一张牌。
local j_jiaochi = fk.CreateSkill {
  name = "j_jiaochi",
}

Fk:loadTranslationTable{
  ["j_jiaochi"] = "骄侈",
  [":j_jiaochi"] = "出牌阶段开始时，你可弃置x张手牌，获得x枚“粮”。若你弃置的是装备牌，额外获得一枚“粮”。当你失去一张“粮”时，你摸一张牌。",

  ["#j_jiaochi-invoke"] = "骄侈：是否弃置任意张手牌并获得等量“粮”？",
  ["#j_jiaochi-discard"] = "骄侈：选择要弃置的手牌",
  ["@j_jiaochi_liang"] = "粮",

  ["$j_jiaochi1"] = "仓廪丰实，何虑军需！",
  ["$j_jiaochi2"] = "钱粮在手，天下我有！",
}

-- 失去粮：减少标记 + 摸等量牌 + 累加本回合弃粮数（供僭业判定）
function j_jiaochi.loseLiang(room, player, n)
  if n <= 0 then return end
  room:setPlayerMark(player, "@j_jiaochi_liang", player:getMark("@j_jiaochi_liang") - n)
  player:drawCards(n, j_jiaochi.name)
  room:addPlayerMark(player, "j_jianye2_discard-round", n)
end

-- 出牌阶段开始时：弃 x 张手牌获得 x 枚粮（含装备则额外 +1）
j_jiaochi:addEffect(fk.EventPhaseStart, {
  anim_type = "draw",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_jiaochi.name) or player.dead then return false end
    if data.to ~= Player.Play then return false end
    return #player:getCardIds("h") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_jiaochi.name, prompt = "#j_jiaochi-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local hand = #player:getCardIds("h")
    local c = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      min = 1,
      max = hand,
      cancelable = false,
      pattern = ".",
      skill_name = j_jiaochi.name,
      prompt = "#j_jiaochi-discard",
    })
    if not c or #c == 0 then return end
    local x = #c
    room:throwCard(c, j_jiaochi.name, player, player)
    room:setPlayerMark(player, "@j_jiaochi_liang", player:getMark("@j_jiaochi_liang") + x)
    -- 弃置的牌中有装备牌则额外获得一枚
    local hasEquip = false
    for _, id in ipairs(c) do
      if Fk:getCardById(id).type == Card.TypeEquip then hasEquip = true break end
    end
    if hasEquip then
      room:setPlayerMark(player, "@j_jiaochi_liang", player:getMark("@j_jiaochi_liang") + 1)
    end
  end,
})

-- 测试：出牌阶段开始弃手牌获粮，含装备额外+1
j_jiaochi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiaochi.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    -- 手牌：1张装备 + 2张基本
    local e1 = room:printCard("crossbow", Card.Spade, 2)
    local s1 = room:printCard("slash", Card.Heart, 3)
    local s2 = room:printCard("jink", Card.Club, 4)
    room:obtainCard(me, { e1, s1, s2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local hand = me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", hand })
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Draw, to = Player.Play })
    -- 弃3张（含1装备）→ 粮 3+1=4
    lu.assertEquals(me:getMark("@j_jiaochi_liang"), 4, "骄侈：弃3张含装备应获得4枚粮")
    lu.assertEquals(#me:getCardIds("h"), 0, "骄侈：弃置后手牌应清空")
  end)
end)

-- 测试：失去粮时摸等量牌并累加本回合弃粮数
j_jiaochi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiaochi.name)
    me.maxHp = 4
    me.hp = 4
    room:setPlayerMark(me, "@j_jiaochi_liang", 5)
  end)

  FkTest.runInRoom(function()
    local handBefore = #me:getCardIds("h")
    j_jiaochi.loseLiang(room, me, 2)
    lu.assertEquals(me:getMark("@j_jiaochi_liang"), 3, "骄侈：失去粮应减少标记")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 2, "骄侈：失去2枚粮应摸2张牌")
    lu.assertEquals(me:getMark("j_jianye2_discard-round"), 2, "骄侈：应累加本回合弃粮数")
  end)
end)

return j_jiaochi