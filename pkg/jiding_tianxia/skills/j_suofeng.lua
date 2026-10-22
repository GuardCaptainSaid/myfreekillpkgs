-- 计满宠·锁锋（转换技）
-- 阳：每当你受到一次伤害后，你可以横置一名其他角色；
-- 阴：每当你受到一次伤害后，你可以令一名未横置的其他角色翻面，然后你获得其X张牌（X为场上横置的角色数）。
local j_suofeng = fk.CreateSkill {
  name = "j_suofeng",
  tags = { Skill.Switch },
}

Fk:loadTranslationTable{
  ["j_suofeng"] = "锁锋",
  [":j_suofeng"] = "转换技。阳：每当你受到一次伤害后，你可以横置一名其他角色；阴：每当你受到一次伤害后，你可以令一名未横置的其他角色翻面，然后你获得其X张牌（X为场上横置的角色数）。",
  [":j_suofeng_yang"] = "转换技，<font color='#E0DB2F'>阳：每当你受到一次伤害后，你可以横置一名其他角色；</font><font color='grey'>阴：每当你受到一次伤害后，你可以令一名未横置的其他角色翻面，然后你获得其X张牌（X为场上横置的角色数）。</font>",
  [":j_suofeng_yin"] = "转换技，<font color='grey'>阳：每当你受到一次伤害后，你可以横置一名其他角色；</font><font color='#E0DB2F'>阴：每当你受到一次伤害后，你可以令一名未横置的其他角色翻面，然后你获得其X张牌（X为场上横置的角色数）。</font>",

  ["#j_suofeng-yang"] = "锁锋（阳）：是否横置一名其他角色？",
  ["#j_suofeng-yin"] = "锁锋（阴）：是否令一名未横置的其他角色翻面并获得其牌？",
  ["#j_suofeng-chain"] = "锁锋：选择一名其他角色横置",
  ["#j_suofeng-face"] = "锁锋：选择一名未横置的其他角色翻面",
  ["#j_suofeng-gain"] = "锁锋：获得其 %arg 张牌",
}

-- 场上横置角色数
local function chainedCount(room)
  local n = 0
  for _, p in ipairs(room.alive_players) do
    if p.chained then n = n + 1 end
  end
  return n
end

-- 阳：受到伤害后，横置一名其他角色
j_suofeng:addEffect(fk.Damage, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_suofeng.name) or player.dead then return false end
    if not data or data.to ~= player then return false end
    if player:getSwitchSkillState(j_suofeng.name) ~= fk.SwitchYang then return false end
    for _, p in ipairs(player.room.alive_players) do
      if p ~= player and not p.chained then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_suofeng.name, prompt = "#j_suofeng-yang" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local targets = {}
    for _, p in ipairs(room.alive_players) do
      if p ~= player and not p.chained then
        table.insert(targets, p)
      end
    end
    if #targets == 0 then return end
    local tos = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = j_suofeng.name,
      prompt = "#j_suofeng-chain",
    })
    if #tos > 0 and not tos[1].chained then
      tos[1]:setChainState(true)
    end
  end,
})

-- 阴：受到伤害后，令一名未横置的其他角色翻面，然后获得其X张牌
j_suofeng:addEffect(fk.Damage, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_suofeng.name) or player.dead then return false end
    if not data or data.to ~= player then return false end
    if player:getSwitchSkillState(j_suofeng.name) ~= fk.SwitchYin then return false end
    for _, p in ipairs(player.room.alive_players) do
      if p ~= player and not p.chained then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_suofeng.name, prompt = "#j_suofeng-yin" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local targets = {}
    for _, p in ipairs(room.alive_players) do
      if p ~= player and not p.chained then
        table.insert(targets, p)
      end
    end
    if #targets == 0 then return end
    local tos = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = j_suofeng.name,
      prompt = "#j_suofeng-face",
    })
    if #tos == 0 then return end
    local victim = tos[1]
    -- 翻面
    if not victim.dead then
      victim:turnOver()
    end
    -- 获得其 X 张牌（X 为场上横置的角色数）
    local x = chainedCount(room)
    if victim.dead or x <= 0 then return end
    local he = victim:getCardIds("he")
    local n = math.min(x, #he)
    if n <= 0 then return end
    local chosen = room:askToChooseCards(player, {
      target = victim,
      flag = "he",
      min = n,
      max = n,
      cancelable = false,
      pattern = ".",
      skill_name = j_suofeng.name,
      prompt = "#j_suofeng-gain:::" .. x,
    })
    if chosen and #chosen > 0 then
      room:obtainCard(player, chosen, true, fk.ReasonPrey, victim, j_suofeng.name)
    end
  end,
})

-- 测试：阳形态受到伤害 → 横置一名其他角色，并切换到阴
j_suofeng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_suofeng.name)
    room.current = comp2
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChoosePlayers = room.askToChoosePlayers
    room.askToSkillInvoke = function(self, who, params) return true end
    room.askToChoosePlayers = function(self, who, params) return { comp2 } end

    room.logic:trigger(fk.Damage, comp2, { from = comp2, to = me, damage = 1 })

    room.askToSkillInvoke = origInvoke
    room.askToChoosePlayers = origChoosePlayers
    lu.assertTrue(comp2.chained, "阳形态应横置一名其他角色")
    lu.assertEquals(me:getSwitchSkillState(j_suofeng.name), fk.SwitchYin, "发动后应转换为阴")
  end)
end)

-- 测试：阴形态受到伤害 → 令未横置角色翻面并获得其牌
j_suofeng:addTest(function(room, me)
  local comp2, comp3 = room.players[2], room.players[3]
  local card
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_suofeng.name)
    room.current = comp2
    -- 置为阴形态，并让场上有一名横置角色
    room:setPlayerMark(me, "__switcher_j_suofeng", 1)
    comp2:setChainState(true)
    card = room:printCard("jink", Card.Heart, 5)
    room:obtainCard(comp3, { card }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChoosePlayers = room.askToChoosePlayers
    local origChooseCards = room.askToChooseCards
    room.askToSkillInvoke = function(self, who, params) return true end
    room.askToChoosePlayers = function(self, who, params) return { comp3 } end
    room.askToChooseCards = function(self, who, params)
      if who == me then return { card.id } end
      return origChooseCards(self, who, params)
    end

    room.logic:trigger(fk.Damage, comp2, { from = comp2, to = me, damage = 1 })

    room.askToSkillInvoke = origInvoke
    room.askToChoosePlayers = origChoosePlayers
    room.askToChooseCards = origChooseCards
    lu.assertFalse(comp3.faceup, "应令未横置角色翻面")
    lu.assertTrue(table.contains(me:getCardIds("h"), card.id), "应获得其一张牌")
  end)
end)

return j_suofeng
