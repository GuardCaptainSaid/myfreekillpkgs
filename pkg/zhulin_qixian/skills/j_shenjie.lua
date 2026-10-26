-- 阮咸·神解
-- 摸牌阶段开始时，你可以改为亮出牌堆顶5张牌并获得其中类型不同的牌各一张，若你因此仅获得了一张牌，你可令一名角色回复或流失一点体力。
local j_shenjie = fk.CreateSkill {
  name = "j_shenjie",
}

Fk:loadTranslationTable{
  ["j_shenjie"] = "神解",
  [":j_shenjie"] = "摸牌阶段开始时，你可以改为亮出牌堆顶5张牌并获得其中类型不同的牌各一张，若你因此仅获得了一张牌，你可令一名角色回复或流失一点体力。",

  ["#j_shenjie-invoke"] = "神解：是否改为亮出牌堆顶5张牌并获得类型不同的牌各一张？",
  ["#j_shenjie-choice"] = "神解：令一名角色回复或流失一点体力",
  ["j_shenjie__recover"] = "回复一点体力",
  ["j_shenjie__lose"] = "流失一点体力",
  ["#j_shenjie-target"] = "神解：选择一名角色",

  ["$j_shenjie1"] = "神解音律，妙悟天机。",
  ["$j_shenjie2"] = "丝竹之妙，通乎神明。",
}

-- 摸牌阶段开始时：亮出5张，获得类型不同各一张
j_shenjie:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Draw then return false end
    if target ~= player then return false end
    if not player:hasSkill(j_shenjie.name) or player.dead then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_shenjie.name, prompt = "#j_shenjie-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "@j_shenjie_drew", 1)
    local ids = room:getNCards(5, "top")
    if #ids == 0 then return end
    room:showCards(ids, player)
    -- 获得其中类型不同的牌各一张（每种类型至多一张）
    local gained = {}
    local seen = {}
    for _, id in ipairs(ids) do
      local c = Fk:getCardById(id)
      if c.type ~= nil and not seen[c.type] then
        seen[c.type] = true
        table.insert(gained, id)
      end
    end
    room:obtainCard(player, gained, true, fk.ReasonDraw, nil, j_shenjie.name)
    if #gained == 1 then
      -- 仅获得一张牌：令一名角色回复或流失一点体力
      local choice = room:askToChoice(player, {
        choices = { "j_shenjie__recover", "j_shenjie__lose" },
        skill_name = j_shenjie.name,
        prompt = "#j_shenjie-choice",
      })
      local candidates = table.filter(room.alive_players, function(p) return p ~= player end)
      if #candidates == 0 then return end
      local t = room:askToChoosePlayers(player, {
        targets = candidates,
        min_num = 1,
        max_num = 1,
        cancelable = false,
        skill_name = j_shenjie.name,
        prompt = "#j_shenjie-target",
      })[1]
      if not t then return end
      if choice == "j_shenjie__lose" then
        room:loseHp(t, 1, j_shenjie.name, player)
      else
        room:recover{ who = t, num = 1, recoverBy = player, skillName = j_shenjie.name }
      end
    end
  end,
})

-- 本回合摸牌阶段不再正常摸牌
j_shenjie:addEffect(fk.DrawNCards, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:getMark("@j_shenjie_drew") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data.num = 0
  end,
})

-- 回合结束：清除标记
j_shenjie:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Finish then return false end
    if player.room.current ~= player then return false end
    if not player:hasSkill(j_shenjie.name, true) and player:getMark("@j_shenjie_drew") == 0 then return false end
    return player:getMark("@j_shenjie_drew") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@j_shenjie_drew", 0)
  end,
})

j_shenjie:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_shenjie.name,
  think = function(self, player)
    return true
  end,
})

-- 测试：5张含3种类型 → 获得3张；本回合摸牌阶段不再摸牌
j_shenjie:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shenjie.name)
    me.maxHp = 3
    me.hp = 3
    -- 把牌堆顶换成 3 种类型各一张 + 2 张重复基本
    local top = { { "crossbow", Card.Club, 2 }, { "snatch", Card.Spade, 3 },
      { "slash", Card.Heart, 4 }, { "jink", Card.Diamond, 5 }, { "peach", Card.Spade, 6 } }
    local ids = {}
    for _, spec in ipairs(top) do
      local c = room:printCard(spec[1], spec[2], spec[3])
      table.insert(ids, c.id)
    end
    -- 构造新牌堆：先把旧牌堆清空再插入
    local oldPile = room.draw_pile
    local newPile = {}
    for _, id in ipairs(ids) do table.insert(newPile, id) end
    for _, id in ipairs(oldPile) do table.insert(newPile, id) end
    room.draw_pile = newPile
  end)

  FkTest.runInRoom(function()
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Discard, to = Player.Draw })
    lu.assertEquals(#me:getCardIds("h"), handBefore + 3, "神解：应获得3张类型不同的牌")
    lu.assertEquals(me:getMark("@j_shenjie_drew"), 1, "神解：应标记本回合不摸牌")
    -- DrawNCards 应被阻止
    local drawData = { who = me, num = 2, skillName = "" }
    room.logic:trigger(fk.DrawNCards, me, drawData)
    lu.assertEquals(drawData.num, 0, "神解：本回合不应正常摸牌")
  end)
end)

-- 测试：5张全同一类型 → 仅获得1张 → 令目标流失一点体力
j_shenjie:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shenjie.name)
    me.maxHp = 3
    me.hp = 3
    local ids = {}
    for _, spec in ipairs({ { "slash", Card.Club, 2 }, { "jink", Card.Spade, 3 },
      { "slash", Card.Heart, 4 }, { "jink", Card.Diamond, 5 }, { "slash", Card.Spade, 6 } }) do
      local c = room:printCard(spec[1], spec[2], spec[3])
      table.insert(ids, c.id)
    end
    local oldPile = room.draw_pile
    local newPile = {}
    for _, id in ipairs(ids) do table.insert(newPile, id) end
    for _, id in ipairs(oldPile) do table.insert(newPile, id) end
    room.draw_pile = newPile
  end)

  FkTest.runInRoom(function()
    local compHpBefore = comp2.hp
    FkTest.setNextReplies(me, { "1", { "j_shenjie__lose" }, FkTest.ReplyChoosePlayer({ comp2 }) })
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Discard, to = Player.Draw })
    lu.assertEquals(comp2.hp, compHpBefore - 1, "神解：仅获一张时目标应流失1点体力")
  end)
end)

return j_shenjie
