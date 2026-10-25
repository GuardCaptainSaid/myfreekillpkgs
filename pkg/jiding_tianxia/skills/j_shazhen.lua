-- 计娄圭·沙镇
-- 当你进入濒死状态时，你可以令至多3名角色获得其体力上限枚“冰封”标记。
-- 拥有“冰封”标记的角色使用牌时，此牌无效并移去一枚“冰封”标记；
-- 其回合结束时，其失去所有“冰封”标记并失去X点体力（X为其失去的“冰封”标记数）。
local j_shazhen = fk.CreateSkill {
  name = "j_shazhen",
}

local BING = "@j_shazhen_bing"

Fk:loadTranslationTable{
  ["j_shazhen"] = "沙镇",
  [":j_shazhen"] = "当你进入濒死状态时，你可以令至多3名角色各获得等于其体力上限枚“冰封”标记。拥有“冰封”标记的角色使用牌时，此牌无效并移去一枚“冰封”标记；其回合结束时，其失去所有“冰封”标记并失去X点体力（X为其失去的“冰封”标记数）。",

  ["#j_shazhen-invoke"] = "沙镇：是否令至多3名角色获得“冰封”标记？",
  ["#j_shazhen-choose"] = "沙镇：选择至多3名角色，其各获得等于其体力上限枚“冰封”标记",
  [BING] = "冰封",
}

-- 进入濒死：令至多3名角色各获得其体力上限枚“冰封”
j_shazhen:addEffect(fk.EnterDying, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_shazhen.name) or player.dead then return false end
    -- 至少要有另一名角色可以成为目标（不能选自己：给自己挂"冰封"只会让自己
    -- 在回合结束时失去等量体力，没有任何意义）
    for _, p in ipairs(player.room.alive_players) do
      if p ~= player then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_shazhen.name,
      prompt = "#j_shazhen-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local candidates = table.filter(room.alive_players, function(p) return p ~= player end)
    if #candidates == 0 then return end
    local tos = room:askToChoosePlayers(player, {
      targets = candidates,
      min_num = 1,
      max_num = 3,
      cancelable = true,
      skill_name = j_shazhen.name,
      prompt = "#j_shazhen-choose",
    })
    if not tos or #tos == 0 then return end
    for _, t in ipairs(tos) do
      if not t.dead and t.maxHp > 0 then
        room:addPlayerMark(t, BING, t.maxHp)
      end
    end
  end,
})

-- 拥有“冰封”的角色使用牌 → 此牌无效并移去一枚
j_shazhen:addEffect(fk.CardUsing, {
  global = true,
  -- 自动触发，不弹“是否发动”
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_shazhen.name) then return false end
    local from = data and data.from
    if not from or from.dead then return false end
    if from:getMark(BING) <= 0 then return false end
    -- 需要有可无效的目标（无目标的使用，如【无懈可击】，不在本技能范围内）
    return #(data.tos or {}) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    local n = from:getMark(BING)
    if n <= 0 then return end
    room:setPlayerMark(from, BING, n - 1)

    -- 令此牌对所有目标无效
    data.nullifiedTargets = data.nullifiedTargets or {}
    for _, to in ipairs(data.tos or {}) do
      table.insertIfNeed(data.nullifiedTargets, to)
    end
  end,
})

-- 其回合结束：失去所有“冰封”并失去等量点体力
j_shazhen:addEffect(fk.TurnEnd, {
  global = true,
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_shazhen.name) then return false end
    return target ~= nil and not target.dead and target:getMark(BING) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = target:getMark(BING)
    room:setPlayerMark(target, BING, 0)
    if x > 0 and not target.dead then
      room:loseHp(target, x, j_shazhen.name)
    end
  end,
})

-- 失去技能（含死亡）时清空所有“冰封”，避免残留
j_shazhen:addLoseEffect(function(self, player, is_death)
  local room = player.room
  for _, p in ipairs(room.players) do
    if p:getMark(BING) > 0 then
      room:setPlayerMark(p, BING, 0)
    end
  end
end)

-- 测试：进入濒死 → 给目标其体力上限枚冰封；其使用牌无效并消耗一枚；回合结束掉血
j_shazhen:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shazhen.name)
    comp2.maxHp = 4
    comp2.hp = 4
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChoose = room.askToChoosePlayers
    room.askToSkillInvoke = function(self, who, params)
      if who == me and params.skill_name == j_shazhen.name then return true end
      return origInvoke(self, who, params)
    end
    room.askToChoosePlayers = function(self, who, params) return { comp2 } end
    room.logic:trigger(fk.EnterDying, me, {})
    room.askToSkillInvoke = origInvoke
    room.askToChoosePlayers = origChoose
    lu.assertEquals(comp2:getMark(BING), 4, "目标应获得其体力上限(4)枚冰封")
  end)

  -- 使用牌 → 无效 + 消耗一枚
  FkTest.runInRoom(function()
    local card = Fk:cloneCard("slash")
    card.skillName = "test"
    local use = { from = comp2, tos = { me }, card = card, nullifiedTargets = {} }
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertEquals(comp2:getMark(BING), 3, "使用牌应移去一枚冰封")
    lu.assertTrue(table.contains(use.nullifiedTargets or {}, me), "此牌应对目标无效")
  end)

  -- 回合结束 → 清空标记并失去等量体力
  FkTest.runInRoom(function()
    local hp = comp2.hp
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(comp2:getMark(BING), 0, "回合结束应清空冰封")
    lu.assertEquals(comp2.hp, hp - 3, "回合结束应失去3点体力")
  end)
end)

-- 测试（真实流程）：EnterDying → 真实弹窗选人 → 目标获得体力上限枚冰封；
-- 该角色真实使用牌 → 牌被无效且消耗一枚；回合结束 → 失去等量体力
j_shazhen:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shazhen.name)
    comp2.maxHp = 4
    comp2.hp = 4
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1", { card = {}, targets = { comp2.id } } })
    room.logic:trigger(fk.EnterDying, me, {})
    lu.assertEquals(comp2:getMark(BING), 4, "目标应通过真实弹窗获得其体力上限(4)枚冰封")
    lu.assertEquals(me:getMark(BING), 0, "不能选自己：自己不应获得冰封")
  end)
  FkTest.runInRoom(function()
    -- comp2 真实使用【杀】指定 me：应被"冰封"无效，且不造成伤害
    local slash = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(comp2, { slash }, true, fk.ReasonDraw, me, "test")
    local hp_before = me.hp
    room:useCard{ from = comp2, tos = { me }, card = slash }
    lu.assertEquals(comp2:getMark(BING), 3, "使用牌应移去一枚冰封")
    lu.assertEquals(me.hp, hp_before, "冰封令此牌无效：不应受到伤害")
  end)
  FkTest.runInRoom(function()
    local hp = comp2.hp
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(comp2:getMark(BING), 0, "回合结束应清空冰封")
    lu.assertEquals(comp2.hp, hp - 3, "回合结束应失去3点体力")
  end)
end)

return j_shazhen
