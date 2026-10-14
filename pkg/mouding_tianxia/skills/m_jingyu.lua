local m_jingyu = fk.CreateSkill {
  name = "m_jingyu",
}

Fk:loadTranslationTable{
  ["m_jingyu"] = "静御",
  [":m_jingyu"] = "每回合限一次，当你受到伤害时，若你的武将牌正面朝上，你可以与伤害来源拼点，若你赢，防止该伤害，然后你和伤害来源将武将牌翻面，伤害来源获得你的拼点牌。",

  ["#m_jingyu-invoke"] = "静御：与 %dest 拼点，若赢则防止此伤害并双方翻面",
  ["$m_jingyu1"] = "静观其变，御敌于先。",
  ["$m_jingyu2"] = "以静制动，万军莫侵！",
}

m_jingyu:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(m_jingyu.name) then return false end
    if target ~= player or player.dead then return false end
    if not player.faceup then return false end
    if player.room:getTag("m_jingyu_turn_used") then return false end
    if not data.from or data.from.dead or data.from == player then return false end
    if #player:getCardIds("h") == 0 or #data.from:getCardIds("h") == 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, {
      skill_name = m_jingyu.name,
      prompt = "#m_jingyu-invoke::" .. data.from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setTag("m_jingyu_turn_used", true)
    local pd = { from = player, tos = { data.from }, reason = m_jingyu.name, results = {} }
    room:pindian(pd)
    local fromCard = pd.fromCard
    local toResult = pd.results[data.from]
    if fromCard and toResult and toResult.toCard then
      if fromCard.number > toResult.toCard.number then
        data:preventDamage()
        player:turnOver()
        data.from:turnOver()
        local myCardId = fromCard:getEffectiveId()
        if myCardId then
          room:obtainCard(data.from, { myCardId }, false, fk.ReasonPrey, player, m_jingyu.name)
        end
      end
    end
  end,
})

-- 每回合限一次：回合开始时重置
m_jingyu:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(m_jingyu.name) and not player.dead
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setTag("m_jingyu_turn_used", nil)
  end,
})

m_jingyu:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = m_jingyu.name,
  think = Util.TrueFunc,
})

-- 测试：受伤时与伤害来源拼点，赢则防止伤害、双方翻面、来源获得我的拼点牌
m_jingyu:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, m_jingyu.name)
    c1 = room:printCard("slash", Card.Spade, 9)
    c2 = room:printCard("peach", Card.Heart, 2)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { c2 }, true, fk.ReasonDraw, comp2, "test")
    me.faceup = true
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1", FkTest.ReplyChooseCards({ c1.id }) })
    FkTest.setNextReplies(comp2, { FkTest.ReplyChooseCards({ c2.id }) })
    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, me, dmg)
    lu.assertEquals(dmg.damage, 0, "拼点赢应防止伤害")
    lu.assertTrue(dmg.prevented, "应标记为防止")
    lu.assertFalse(me.faceup, "我应翻面")
    lu.assertFalse(comp2.faceup, "伤害来源应翻面")
    lu.assertEquals(#comp2:getCardIds("h"), 1, "伤害来源应获得我的拼点牌")
    lu.assertTrue(room:getTag("m_jingyu_turn_used"), "应记录本回合已使用")
  end)
end)

-- 测试：拼点输则不防止伤害
m_jingyu:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, m_jingyu.name)
    room:setTag("m_jingyu_turn_used", nil)
    c1 = room:printCard("slash", Card.Spade, 2)
    c2 = room:printCard("peach", Card.Heart, 9)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { c2 }, true, fk.ReasonDraw, comp2, "test")
    me.faceup = true
    comp2.faceup = true
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1", FkTest.ReplyChooseCards({ c1.id }) })
    FkTest.setNextReplies(comp2, { FkTest.ReplyChooseCards({ c2.id }) })
    local dmg = DamageData:new{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, me, dmg)
    lu.assertEquals(dmg.damage, 1, "拼点输不应防止伤害")
    lu.assertTrue(me.faceup, "不应翻面")
  end)
end)

return m_jingyu