local j_xiaoyao = fk.CreateSkill {
  name = "j_xiaoyao",
}

Fk:loadTranslationTable{
  ["j_xiaoyao"] = "逍遥",
  [":j_xiaoyao"] = "一名角色的准备阶段，你可以选择一项：1、失去一点体力将手牌摸至与其相同；2、弃置所有手牌将体力调至与其相同；3、摸一张牌并移除此项；4、加一点体力上限并移除此项；5、对其造成一点伤害并移除此项。",

  ["#j_xiaoyao-choice"] = "逍遥：选择一项执行",
  ["j_xiaoyao:opt1"] = "失去1点体力，手牌摸至与其相同",
  ["j_xiaoyao:opt2"] = "弃置所有手牌，体力调至与其相同",
  ["j_xiaoyao:opt3"] = "摸一张牌（移除此项）",
  ["j_xiaoyao:opt4"] = "体力上限+1（移除此项）",
  ["j_xiaoyao:opt5"] = "对其造成1点伤害（移除此项）",

  ["$j_xiaoyao1"] = "逍遥物外，不问俗尘。",
  ["$j_xiaoyao2"] = "天地与我并生，万物与我为一。",
}

-- 一名角色的准备阶段（每名角色每回合自然进入一次准备阶段，无需额外限次）
j_xiaoyao:addEffect(fk.EventPhaseStart, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Start then return false end
    if not player:hasSkill(j_xiaoyao.name) or player.dead then return false end
    if target == player then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local rm = player:getMark("j_xiaoyao_rm")
    local choices = { "j_xiaoyao:opt1", "j_xiaoyao:opt2" }
    if rm % 2 == 0 then table.insert(choices, "j_xiaoyao:opt3") end
    if math.floor(rm / 2) % 2 == 0 then table.insert(choices, "j_xiaoyao:opt4") end
    if math.floor(rm / 4) % 2 == 0 then table.insert(choices, "j_xiaoyao:opt5") end
    local choice = room:askToChoice(player, {
      choices = choices,
      skill_name = j_xiaoyao.name,
      prompt = "#j_xiaoyao-choice",
    })
    if choice == "" then return false end
    self.choice = choice
    self.target = target
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local t = self.target
    local choice = self.choice
    if choice == "j_xiaoyao:opt1" then
      room:loseHp(player, 1, j_xiaoyao.name, player)
      if not player.dead then
        local diff = #t:getCardIds("h") - #player:getCardIds("h")
        if diff > 0 then player:drawCards(diff, j_xiaoyao.name) end
      end
    elseif choice == "j_xiaoyao:opt2" then
      local all = player:getCardIds("h")
      if #all > 0 then room:throwCard(all, j_xiaoyao.name, player, player) end
      if t.hp > player.hp then
        room:recover{ who = player, num = t.hp - player.hp, recoverBy = player, skillName = j_xiaoyao.name }
      elseif t.hp < player.hp then
        room:loseHp(player, player.hp - t.hp, j_xiaoyao.name, player)
      end
    elseif choice == "j_xiaoyao:opt3" then
      player:drawCards(1, j_xiaoyao.name)
      room:setPlayerMark(player, "j_xiaoyao_rm", player:getMark("j_xiaoyao_rm") + 1)
    elseif choice == "j_xiaoyao:opt4" then
      room:changeMaxHp(player, 1)
      room:setPlayerMark(player, "j_xiaoyao_rm", player:getMark("j_xiaoyao_rm") + 2)
    elseif choice == "j_xiaoyao:opt5" then
      room:damage{ from = player, to = t, damage = 1, damageType = fk.NormalDamage, skillName = j_xiaoyao.name }
      room:setPlayerMark(player, "j_xiaoyao_rm", player:getMark("j_xiaoyao_rm") + 4)
    end
  end,
})

j_xiaoyao:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_xiaoyao.name,
  think = function(self, player)
    return false
  end,
})

-- 测试：其他角色准备阶段，选“失去1体力，手牌摸至与其相同”
j_xiaoyao:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiaoyao.name)
    local h1 = room:printCard("slash", Card.Club, 2)
    local h2 = room:printCard("jink", Card.Spade, 3)
    room:obtainCard(me, { h1, h2 }, true, fk.ReasonDraw, me, "test")
    for i = 1, 5 do
      local c = room:printCard("slash", Card.Heart, i)
      room:obtainCard(comp2, { c }, true, fk.ReasonDraw, comp2, "test")
    end
  end)

  FkTest.runInRoom(function()
    local hpBefore = me.hp
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { { "j_xiaoyao:opt1" } })
    local phaseData = { from = Player.Discard, to = Player.Start }
    room.logic:trigger(fk.EventPhaseStart, comp2, phaseData)

    lu.assertEquals(me.hp, hpBefore - 1, "逍遥：应失去1点体力")
    lu.assertEquals(#me:getCardIds("h"), #comp2:getCardIds("h"), "逍遥：手牌应摸至与目标相同")
  end)
end)

-- 测试：选“摸一张牌”后该项被移除，再次触发时不可选
j_xiaoyao:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiaoyao.name)
    room:setPlayerMark(me, "j_xiaoyao_rm", 0)
  end)

  FkTest.runInRoom(function()
    -- 第一次触发：选摸一张牌（opt3）
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { { "j_xiaoyao:opt3" } })
    local phaseData = { from = Player.Discard, to = Player.Start }
    room.logic:trigger(fk.EventPhaseStart, comp2, phaseData)
    lu.assertEquals(#me:getCardIds("h"), handBefore + 1, "逍遥：应摸一张牌")
    lu.assertEquals(me:getMark("j_xiaoyao_rm") % 2, 1, "逍遥：opt3 应被移除")

    -- 第二次触发（仍以 comp2 为回合角色）：opt3 已移除，opt1/opt2 在列，仍可发动
    local hpBefore = me.hp
    FkTest.setNextReplies(me, { { "j_xiaoyao:opt1" } })
    room.logic:trigger(fk.EventPhaseStart, comp2, phaseData)
    lu.assertEquals(me.hp, hpBefore - 1, "逍遥：第二次仍可发动且可选择 opt1")
  end)
end)

return j_xiaoyao