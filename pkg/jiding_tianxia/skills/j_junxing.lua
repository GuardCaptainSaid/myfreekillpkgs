-- 计满宠·峻刑（锁定技）
-- 你的回合开始时，摸X张牌并展示之。若其中有锦囊牌，你横置一名角色，然后对自己造成一点雷电伤害。
-- （X为场上横置的角色数）
local j_junxing = fk.CreateSkill {
  name = "j_junxing",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_junxing"] = "峻刑",
  [":j_junxing"] = "锁定技，你的回合开始时，摸X张牌并展示之。若其中有锦囊牌，你横置一名角色，然后对自己造成一点雷电伤害。（X为场上横置的角色数）",

  ["#j_junxing-chain"] = "峻刑：选择一名角色横置",
}

-- 场上横置角色数
local function chainedCount(room)
  local n = 0
  for _, p in ipairs(room.alive_players) do
    if p.chained then n = n + 1 end
  end
  return n
end

j_junxing:addEffect(fk.TurnStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_junxing.name) and not player.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = chainedCount(room)
    if x <= 0 then return end
    -- 摸 X 张牌并展示之
    local before = player:getCardIds("h")
    room:drawCards(player, x, j_junxing.name)
    local after = player:getCardIds("h")
    local drawn = table.filter(after, function(id)
      return not table.contains(before, id)
    end)
    if #drawn == 0 then return end
    room:showCards(drawn, player, j_junxing.name)
    -- 其中有锦囊牌
    local tricks = table.filter(drawn, function(id)
      return Fk:getCardById(id).type == Card.TypeTrick
    end)
    if #tricks == 0 then return end
    -- 横置一名角色
    local targets = {}
    for _, p in ipairs(room.alive_players) do
      if not p.chained then
        table.insert(targets, p)
      end
    end
    if #targets > 0 then
      local tos = room:askToChoosePlayers(player, {
        targets = targets,
        min_num = 1,
        max_num = 1,
        skill_name = j_junxing.name,
        prompt = "#j_junxing-chain",
        cancelable = false,
      })
      if #tos > 0 and not tos[1].chained then
        tos[1]:setChainState(true)
      end
    end
    -- 对自己造成一点雷电伤害
    room:damage{
      from = player,
      to = player,
      damage = 1,
      damageType = fk.ThunderDamage,
      skillName = j_junxing.name,
    }
  end,
})

-- 测试：场上 1 名横置角色 → 摸 1 张；若为锦囊则横置一人并受 1 点雷电伤害
j_junxing:addTest(function(room, me)
  local comp2, comp3 = room.players[2], room.players[3]
  local trick
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_junxing.name)
    room.current = me
    comp2:setChainState(true)
    trick = room:printCard("ex_nihilo", Card.Heart, 5)
    table.insert(room.draw_pile, 1, trick.id)
  end)
  FkTest.runInRoom(function()
    local origChoosePlayers = room.askToChoosePlayers
    room.askToChoosePlayers = function(self, who, params) return { comp3 } end
    local beforeHp = me.hp
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToChoosePlayers = origChoosePlayers
    lu.assertTrue(table.contains(me:getCardIds("h"), trick.id), "应摸到牌堆顶的锦囊")
    lu.assertTrue(comp3.chained, "应将选择的角色横置")
    lu.assertEquals(me.hp, beforeHp - 1, "应对自己造成一点雷电伤害")
  end)
end)

-- 测试：摸到的牌无锦囊 → 不横置、不受伤
j_junxing:addTest(function(room, me)
  local comp2 = room.players[2]
  local basic
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_junxing.name)
    room.current = me
    comp2:setChainState(true)
    basic = room:printCard("slash", Card.Spade, 5)
    table.insert(room.draw_pile, 1, basic.id)
  end)
  FkTest.runInRoom(function()
    local beforeHp = me.hp
    room.logic:trigger(fk.TurnStart, me, {})
    lu.assertEquals(me.hp, beforeHp, "无锦囊不应受到伤害")
    lu.assertTrue(comp2.chained, "原有横置角色保持不变")
  end)
end)

return j_junxing
