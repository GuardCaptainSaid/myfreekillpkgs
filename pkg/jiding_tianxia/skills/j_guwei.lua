-- 计满宠·固围
-- 出牌阶段结束时，若你于此阶段仅使用过一种类别的牌，你可以视为使用一张基本牌；
-- 若你于此阶段使用过至少三种类别的牌，你可以视为使用一张普通锦囊牌。
local j_guwei = fk.CreateSkill {
  name = "j_guwei",
}

Fk:loadTranslationTable{
  ["j_guwei"] = "固围",
  [":j_guwei"] = "出牌阶段结束时，若你于此阶段仅使用过一种类别的牌，你可以视为使用一张基本牌；若你于此阶段使用过至少三种类别的牌，你可以视为使用一张普通锦囊牌。",

  ["#j_guwei-invoke1"] = "固围：本阶段仅使用过一种类别的牌，是否视为使用一张基本牌？",
  ["#j_guwei-invoke3"] = "固围：本阶段使用过至少三种类别的牌，是否视为使用一张普通锦囊牌？",
}

-- 记录本回合出牌阶段使用过的牌的类别
j_guwei:addEffect(fk.CardUsing, {
  global = true,
  -- 自动记录，无需询问
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_guwei.name) or player.dead then return false end
    if not data or not data.card or data.from ~= player then return false end
    return player.phase == Player.Play
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local types = player:getTableMark("j_guwei_types-turn")
    table.insertIfNeed(types, data.card.type)
    room:setPlayerMark(player, "j_guwei_types-turn", types)
  end,
})

-- 出牌阶段结束时
j_guwei:addEffect(fk.EventPhaseEnd, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_guwei.name) or player.dead then return false end
    if not data or data.phase ~= Player.Play then return false end
    return target == player
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local types = player:getTableMark("j_guwei_types-turn")
    if #types == 1 then
      return room:askToSkillInvoke(player, { skill_name = j_guwei.name, prompt = "#j_guwei-invoke1" })
    elseif #types >= 3 then
      return room:askToSkillInvoke(player, { skill_name = j_guwei.name, prompt = "#j_guwei-invoke3" })
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local types = player:getTableMark("j_guwei_types-turn")
    local names = {}
    if #types == 1 then
      -- 一种类别 → 视为使用一张基本牌
      for _, card in ipairs(Fk.cards) do
        if card.type == Card.TypeBasic then
          table.insertIfNeed(names, card.trueName)
        end
      end
    else
      -- 至少三种类别 → 视为使用一张普通锦囊牌
      for _, card in ipairs(Fk.cards) do
        if card.type == Card.TypeTrick and card.sub_type ~= Card.SubtypeDelayedTrick then
          table.insertIfNeed(names, card.trueName)
        end
      end
    end
    if #names == 0 then return end
    room:askToUseVirtualCard(player, {
      name = names,
      skill_name = j_guwei.name,
      cancelable = true,
    })
  end,
})

-- 测试：本阶段只使用过基本牌 → 出牌阶段结束时可视为使用一张基本牌
j_guwei:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guwei.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 1)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    -- 记录本阶段使用的基本牌
    room.logic:trigger(fk.CardUsing, me, { card = c1, from = me })
    lu.assertEquals(#me:getTableMark("j_guwei_types-turn"), 1, "应记录一种类别")

    local offeredNames = nil
    local origInvoke = room.askToSkillInvoke
    local origUseVirtual = room.askToUseVirtualCard
    room.askToSkillInvoke = function(self, who, params) return true end
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then
        offeredNames = params.name
        return true
      end
      return origUseVirtual(self, who, params)
    end
    room.logic:trigger(fk.EventPhaseEnd, me, { phase = Player.Play })
    room.askToSkillInvoke = origInvoke
    room.askToUseVirtualCard = origUseVirtual
    lu.assertNotNil(offeredNames, "应询问视为使用一张基本牌")
    lu.assertTrue(table.contains(offeredNames, "slash"), "基本牌候选应包含杀")
  end)
end)

-- 测试：本阶段使用过三种类别 → 可视为使用普通锦囊
j_guwei:addTest(function(room, me)
  local c1, c2, c3
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guwei.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 1)
    c2 = room:printCard("ex_nihilo", Card.Heart, 2)
    c3 = room:printCard("crossbow", Card.Club, 3)
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    room.logic:trigger(fk.CardUsing, me, { card = c1, from = me })
    room.logic:trigger(fk.CardUsing, me, { card = c2, from = me })
    room.logic:trigger(fk.CardUsing, me, { card = c3, from = me })
    lu.assertEquals(#me:getTableMark("j_guwei_types-turn"), 3, "应记录三种类别")

    local offeredNames = nil
    local origInvoke = room.askToSkillInvoke
    local origUseVirtual = room.askToUseVirtualCard
    room.askToSkillInvoke = function(self, who, params) return true end
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then
        offeredNames = params.name
        return true
      end
      return origUseVirtual(self, who, params)
    end
    room.logic:trigger(fk.EventPhaseEnd, me, { phase = Player.Play })
    room.askToSkillInvoke = origInvoke
    room.askToUseVirtualCard = origUseVirtual
    lu.assertNotNil(offeredNames, "应询问视为使用一张普通锦囊")
    lu.assertTrue(table.contains(offeredNames, "ex_nihilo"), "普通锦囊候选应包含无中生有")
    lu.assertFalse(table.contains(offeredNames, "indulgence"), "延时锦囊不应在候选内")
  end)
end)

return j_guwei
