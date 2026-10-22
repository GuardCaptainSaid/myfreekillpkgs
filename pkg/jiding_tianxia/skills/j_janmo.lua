local j_janmo = fk.CreateSkill {
  name = "j_janmo",
}

Fk:loadTranslationTable{
  ["j_janmo"] = "缄默",
  [":j_janmo"] = "每回合限一次，当你获得其他角色的手牌后，你可以令其选择一项：1.令你摸一张牌；2.弃置一张牌；3.失去一个技能直到回合结束。若其手牌数不等于体力值，你令其执行随机另一项。",

  ["#j_janmo-invoke"] = "缄默：是否令其选择一项？",
  ["#j_janmo-choice"] = "缄默：请执行一项",
  ["#j_janmo-discard"] = "缄默：弃置一张牌",
  ["#j_janmo-skill"] = "缄默：选择失去一个技能（直到回合结束）",

  ["j_janmo_draw"] = "令其摸一张牌",
  ["j_janmo_discard"] = "弃置一张牌",
  ["j_janmo_lose"] = "失去一个技能直到回合结束",

  ["$j_janmo1"] = "三缄其口，静观其变。",
  ["$j_janmo2"] = "沉默，是最锋利的刀。",
}

local J_OPTIONS = { "j_janmo_draw", "j_janmo_discard", "j_janmo_lose" }

-- 可被“失去”的技能（排除派生技能标记等）
local function lose_candidates(player)
  local ret = {}
  for _, sname in ipairs(player:getSkillNameList()) do
    if not sname:startsWith("#") and not sname:startsWith("@@") then
      table.insert(ret, sname)
    end
  end
  return ret
end

-- 每回合限一次：获得其他角色手牌后触发
j_janmo:addEffect(fk.AfterCardsMove, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_janmo.name) or player.dead then return false end
    if player:getMark("j_janmo-turn") ~= 0 then return false end
    for _, move in ipairs(data or {}) do
      if move.to == player and move.toArea == Card.PlayerHand and
        move.from and move.from ~= player and move.fromArea == Card.PlayerHand then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_janmo.name, prompt = "#j_janmo-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 找到被获得手牌的角色
    local victim
    for _, move in ipairs(data or {}) do
      if move.to == player and move.toArea == Card.PlayerHand and
        move.from and move.from ~= player and move.fromArea == Card.PlayerHand then
        victim = move.from
        break
      end
    end
    if not victim or victim.dead then return end

    -- 先按可行性裁剪选项：无可失技能时去掉第三项，无牌可弃时去掉第二项
    local choices = table.simpleClone(J_OPTIONS)
    if #lose_candidates(victim) == 0 then
      table.removeOne(choices, "j_janmo_lose")
    end
    if #victim:getCardIds("he") == 0 then
      table.removeOne(choices, "j_janmo_discard")
    end
    if #choices == 0 then return end

    room:setPlayerMark(player, "j_janmo-turn", 1)

    local choice = room:askToChoice(victim, {
      choices = choices,
      skill_name = j_janmo.name,
      prompt = "#j_janmo-choice",
    })

    -- 手牌数不等于体力值：改为执行随机另一项
    if victim:getHandcardNum() ~= victim.hp then
      local others = table.filter(choices, function(c) return c ~= choice end)
      if #others > 0 then
        choice = others[math.random(1, #others)]
      end
    end

    if choice == "j_janmo_draw" then
      player:drawCards(1, j_janmo.name)
    elseif choice == "j_janmo_discard" then
      if #victim:getCardIds("he") == 0 then return end
      local cards = room:askToDiscard(victim, {
        min_num = 1,
        max_num = 1,
        include_equip = true,
        pattern = ".",
        skill_name = j_janmo.name,
        prompt = "#j_janmo-discard",
        cancelable = false,
        skip = true,
      })
      if #cards > 0 then
        room:throwCard(cards, j_janmo.name, victim, victim)
      end
    else
      local candidates = lose_candidates(victim)
      if #candidates == 0 then return end
      local sname
      if #candidates == 1 then
        sname = candidates[1]
      else
        sname = room:askToChoice(victim, {
          choices = candidates,
          skill_name = j_janmo.name,
          prompt = "#j_janmo-skill",
        })
      end
      room:handleAddLoseSkills(victim, "-" .. sname, nil, false, true)
      room:setPlayerMark(victim, "j_janmo_lost", sname)
    end
  end,
})

-- 回合结束时：归还因缄默失去的技能
j_janmo:addEffect(fk.TurnEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:getMark("j_janmo_lost") ~= 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local lost = player:getMark("j_janmo_lost")
    if type(lost) == "string" and lost ~= "" and not player:hasSkill(lost, true, true) then
      room:handleAddLoseSkills(player, lost, nil, false, true)
    end
    room:setPlayerMark(player, "j_janmo_lost", 0)
  end,
})

-- 测试：获得其他角色手牌后，令其选择“令你摸一张牌” → 你摸一张
j_janmo:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_janmo.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return true end
    local orig = room.askToChoice
    room.askToChoice = function(self, who, params)
      lu.assertEquals(who, comp2, "应由被获得手牌的角色进行选择")
      return "j_janmo_draw"
    end
    local before = #me:getCardIds("h")
    room:obtainCard(me, { c1 }, false, fk.ReasonPrey, comp2, "test")
    room.askToChoice = orig
    room.askToSkillInvoke = origInvoke
    lu.assertEquals(#me:getCardIds("h"), before + 1 + 1, "获得手牌后应额外摸一张牌")
    lu.assertEquals(me:getMark("j_janmo-turn"), 1, "每回合限一次")
  end)
end)

-- 测试：手牌数不等于体力值 → 改为执行随机另一项
j_janmo:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_janmo.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, comp2, "test")
    comp2.hp = 4 -- 手牌数(1) ≠ 体力值(4)
  end)

  FkTest.runInRoom(function()
    local asked = false
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return true end
    local orig = room.askToChoice
    room.askToChoice = function(self, who, params)
      asked = true
      return "j_janmo_discard"
    end
    room:obtainCard(me, { c1 }, false, fk.ReasonPrey, comp2, "test")
    room.askToChoice = orig
    room.askToSkillInvoke = origInvoke
    lu.assertTrue(asked, "应询问被获得手牌的角色")
  end)
end)

-- 测试：回合结束归还因缄默失去的技能
j_janmo:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_janmo.name)
    room:handleAddLoseSkills(comp2, "j_sulv")
  end)

  FkTest.runInRoom(function()
    lu.assertTrue(comp2:hasSkill("j_sulv"), "前置：应拥有肃律")
    room:handleAddLoseSkills(comp2, "-" .. "j_sulv", nil, false, true)
    room:setPlayerMark(comp2, "j_janmo_lost", "j_sulv")
    lu.assertFalse(comp2:hasSkill("j_sulv"), "失去技能后不应拥有")

    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertTrue(comp2:hasSkill("j_sulv"), "回合结束应归还失去的技能")
    lu.assertEquals(comp2:getMark("j_janmo_lost"), 0, "归还后标记应清空")
  end)
end)

return j_janmo
