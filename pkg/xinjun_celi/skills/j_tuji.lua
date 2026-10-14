-- 君公孙瓒·突骑（锁定技）
-- 出牌阶段开始时，你选择一项：1、你本回合攻击距离-1并摸体力上限张牌（不计入手牌上限），然后你使用【杀】时可额外选择一个目标；2、你弃置一张牌并令你本回合攻击距离加体力上限，然后你的【杀】不能被【闪】响应。你的【杀】造成伤害时，你摸一张牌并获得一枚"骑"（上限5）。
local j_tuji = fk.CreateSkill {
  name = "j_tuji",
}

Fk:loadTranslationTable{
  ["j_tuji"] = "突骑",
  [":j_tuji"] = "锁定技，出牌阶段开始时，你选择一项：1、你本回合攻击距离-1并摸体力上限张牌（不计入手牌上限），然后你使用【杀】时可额外选择一个目标；2、你弃置一张牌并令你本回合攻击距离加体力上限，然后你的【杀】不能被【闪】响应。你的【杀】造成伤害时，你摸一张牌并获得一枚“骑”（上限5）。",

  ["#j_tuji-choice"] = "突骑：选择一项（1.攻击距离-1，摸体力上限张牌，杀可额外选一个目标 2.弃一张牌，攻击距离加体力上限，杀不能被闪响应）",
  ["#j_tuji-discard"] = "突骑：弃置一张牌",
  ["@j_tuji_qi"] = "骑",
  ["@j_tuji_opt1"] = "突骑·袭",
  ["@j_tuji_opt2"] = "突骑·冲",

  ["$j_tuji1"] = "白马义从，所向无前！",
  ["$j_tuji2"] = "铁骑纵横，踏破敌阵！",
}

-- 出牌阶段开始时：强制二选一
j_tuji:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_tuji.name, true) or player.dead then return false end
    if data.to ~= Player.Play then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = room:askToChoice(player, { choices = { "1", "2" }, skill_name = j_tuji.name, prompt = "#j_tuji-choice" })
    if choice == "1" then
      room:setPlayerMark(player, "@j_tuji_opt1-turn", 1)
      player:drawCards(player.maxHp, j_tuji.name)
    else
      room:setPlayerMark(player, "@j_tuji_opt2-turn", 1)
      if not player:isAllNude() then
        local c = room:askToChooseCards(player, {
          target = player,
          flag = "hej",
          min = 1,
          max = 1,
          cancelable = false,
          pattern = ".",
          skill_name = j_tuji.name,
          prompt = "#j_tuji-discard",
        })
        if c and #c > 0 then
          room:throwCard(c, j_tuji.name, player, player)
        end
      end
    end
  end,
})

-- 攻击距离修正：选项1 -1，选项2 +体力上限
j_tuji:addEffect("atkrange", {
  correct_func = function(self, player)
    if player:getMark("@j_tuji_opt1-turn") > 0 then return -1 end
    if player:getMark("@j_tuji_opt2-turn") > 0 then return player.maxHp end
    return 0
  end,
})

-- 手牌上限修正：选项1 +体力上限（不计入手牌上限）
j_tuji:addEffect("maxcards", {
  correct_func = function(self, player)
    if player:getMark("@j_tuji_opt1-turn") > 0 then return player.maxHp end
    return 0
  end,
})

-- 选项1：杀可额外选择一个目标
j_tuji:addEffect("targetmod", {
  extra_target_func = function(self, player, card_skill, card)
    if player:getMark("@j_tuji_opt1-turn") > 0 and card and card.trueName == "slash" then
      return 1
    end
    return 0
  end,
})

-- 选项2：杀不能被响应（不能被闪）
j_tuji:addEffect(fk.PreCardUse, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_tuji.name) then return false end
    if player:getMark("@j_tuji_opt2-turn") == 0 then return false end
    return data.card and data.card.trueName == "slash"
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data.disresponsiveList = table.simpleClone(player.room.players)
  end,
})

-- 杀造成伤害：摸1 + 骑+1（上限5）
j_tuji:addEffect(fk.DamageFinished, {
  can_trigger = function(self, event, target, player, data)
    if data.from ~= player then return false end
    if not player:hasSkill(j_tuji.name) or player.dead then return false end
    if not data.card or data.card.trueName ~= "slash" then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if not player.dead then
      player:drawCards(1, j_tuji.name)
    end
    local qi = player:getMark("@j_tuji_qi")
    if qi < 5 then
      room:setPlayerMark(player, "@j_tuji_qi", qi + 1)
    end
  end,
})

-- 测试：选项1（攻击距离-1、摸体力上限、手牌上限+、杀目标+1）
j_tuji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_tuji.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { { "1" } })
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Draw, to = Player.Play })
    lu.assertEquals(me:getMark("@j_tuji_opt1-turn"), 1, "突骑：选项1应激活")
    lu.assertEquals(#me:getCardIds("h"), handBefore + me.maxHp, "突骑：应摸体力上限张牌")
    lu.assertEquals(me:getMaxCards(), me.hp + me.maxHp, "突骑：手牌上限应+体力上限")
    -- 攻击距离：8人房相邻距离1 → 攻击距离1-1=0 → 应为0（引擎下限0）
    lu.assertEquals(me:getAttackRange(), 0, "突骑：攻击距离应-1")
  end)
end)

-- 测试：选项2（弃牌、攻击距离+、杀不可响应）+ 杀伤害摸牌获骑
j_tuji:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_tuji.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    local h1 = room:printCard("slash", Card.Spade, 3)
    room:obtainCard(me, { h1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local hand = me:getCardIds("h")
    local d = hand[1]
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { { "2" }, { d } })
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Draw, to = Player.Play })
    lu.assertEquals(me:getMark("@j_tuji_opt2-turn"), 1, "突骑：选项2应激活")
    lu.assertEquals(#me:getCardIds("h"), handBefore - 1, "突骑：应弃置一张牌")
    lu.assertEquals(me:getAttackRange(), me.maxHp + 1, "突骑：攻击距离应加体力上限")
    -- 杀伤害 → 摸1 + 骑1
    local slash = room:printCard("slash", Card.Spade, 5)
    local hb2 = #me:getCardIds("h")
    room:damage{ from = me, to = comp2, damage = 1, damageType = fk.NormalDamage, card = slash }
    lu.assertEquals(#me:getCardIds("h"), hb2 + 1, "突骑：杀造成伤害应摸1张牌")
    lu.assertEquals(me:getMark("@j_tuji_qi"), 1, "突骑：应获得1枚骑")
  end)
end)

return j_tuji