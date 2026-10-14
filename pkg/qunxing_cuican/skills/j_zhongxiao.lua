local j_zhongxiao = fk.CreateSkill {
  name = "j_zhongxiao",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["j_zhongxiao"] = "忠孝",
  [":j_zhongxiao"] = "限定技，当场上有角色死亡时，你修改“谏策”中的一个数字。（令其+1）",

  ["#j_zhongxiao-invoke"] = "忠孝：场上已有角色死亡，是否修改“谏策”？（弃置数+1）",

  ["$j_zhongxiao1"] = "忠君孝亲，死而后已。",
  ["$j_zhongxiao2"] = "此身许国，此心奉亲。",
}

-- 限定技：有角色死亡时，谏策弃置数 3→4
j_zhongxiao:addEffect(fk.Death, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(j_zhongxiao.name) then return false end
    if player:getMark("j_zhongxiao_used") ~= 0 then return false end
    if not data or not data.who then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_zhongxiao.name, prompt = "#j_zhongxiao-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_zhongxiao_base", 4)
    room:setPlayerMark(player, "j_zhongxiao_used", 1)
  end,
})

j_zhongxiao:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_zhongxiao.name,
  think = function(self, player)
    return true
  end,
})

-- 测试：角色死亡时发动忠孝 → 谏策弃置数 3→4；未发动时谏策弃3
j_zhongxiao:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_zhongxiao.name, "j_jiance" })
    local ice1 = room:printCard("slash", Card.Spade, 5)
    local ice2 = room:printCard("jink", Card.Heart, 1)
    me:addToPile("j_bing", { ice1.id, ice2.id }, true, "j_jiance")
    local h1 = room:printCard("peach", Card.Club, 2)
    local h2 = room:printCard("slash", Card.Diamond, 3)
    local h3 = room:printCard("jink", Card.Club, 4)
    local h4 = room:printCard("peach", Card.Heart, 5)
    local h5 = room:printCard("slash", Card.Spade, 6)
    room:obtainCard(me, { h1, h2, h3, h4, h5 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { room:printCard("jink", Card.Club, 7) }, true, fk.ReasonDraw, comp2, "test")
  end)

  -- 场景A：未发动忠孝 → 谏策弃3张摸2张（y=2）
  FkTest.runInRoom(function()
    local hand = me:getCardIds("h")
    local before = #hand
    local trick = Fk:cloneCard("dismantlement")
    local use = UseCardData:new{ from = comp2, card = trick, tos = { me } }
    FkTest.setNextReplies(me, { "1", { hand[1], hand[2], hand[3] }, { "j_jiance:draw" } })
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertEquals(#me:getCardIds("h"), before - 3 + 2, "未发动忠孝时谏策应弃3张")
  end)

  -- 场景B：comp3 死亡 → 发动忠孝 → base=4
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.Death, comp3, { who = comp3 })
    lu.assertEquals(me:getMark("j_zhongxiao_base"), 4, "忠孝应修改谏策弃置数为4")
    lu.assertEquals(me:getMark("j_zhongxiao_used"), 1, "限定技应已发动")
  end)

  -- 场景C：发动忠孝后 → 谏策弃4张摸2张（y=2）
  FkTest.runInRoom(function()
    local hand = me:getCardIds("h")
    local before = #hand
    local trick = Fk:cloneCard("dismantlement")
    local use = UseCardData:new{ from = comp2, card = trick, tos = { me } }
    FkTest.setNextReplies(me, { "1", { hand[1], hand[2], hand[3], hand[4] }, { "j_jiance:draw" } })
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertEquals(#me:getCardIds("h"), before - 4 + 2, "发动忠孝后谏策应弃4张")
  end)
end)

return j_zhongxiao