local j_fubing = fk.CreateSkill {
  name = "j_fubing",
}

Fk:loadTranslationTable{
  ["j_fubing"] = "腹兵",
  [":j_fubing"] = "你受到一点伤害后，可以观看牌堆顶的三张牌，然后获得至多两张颜色不同的牌。",

  ["#j_fubing-invoke"] = "腹兵：是否观看牌堆顶的三张牌？",
  ["#j_fubing-pick1"] = "腹兵：获得至多一张牌（可与下一张颜色不同）",
  ["#j_fubing-pick2"] = "腹兵：再获得一张颜色不同的牌",

  ["$j_fubing1"] = "胸有甲兵，腹藏机谋。",
  ["$j_fubing2"] = "兵者，诡道也。",
}

-- 你受到伤害后触发（弹窗询问时机）
j_fubing:addEffect(fk.Damaged, {
  global = true,
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead then return false end
    if not player:hasSkill(j_fubing.name) then return false end
    if not data or data.damage < 1 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_fubing.name, prompt = "#j_fubing-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = room:getNCards(3)
    if #ids == 0 then return end
    room:showCards(ids, player)

    -- 选第一张（可取消）
    local picked = {}
    local c1 = room:askToChooseCards(player, {
      target = player,
      flag = { card_data = { { "$DrawPile", ids } } },
      min = 0, max = 1, cancelable = true,
      skill_name = j_fubing.name, prompt = "#j_fubing-pick1",
    })
    if c1 and #c1 > 0 then table.insert(picked, c1[1]) end

    -- 选第二张：颜色与第一张不同（可取消）
    if #picked == 1 then
      local color = Fk:getCardById(picked[1]).color
      local rest = {}
      for _, id in ipairs(ids) do
        if not table.contains(picked, id) and Fk:getCardById(id).color ~= color then
          table.insert(rest, id)
        end
      end
      if #rest > 0 then
        local c2 = room:askToChooseCards(player, {
          target = player,
          flag = { card_data = { { "$DrawPile", rest } } },
          min = 0, max = 1, cancelable = true,
          skill_name = j_fubing.name, prompt = "#j_fubing-pick2",
        })
        if c2 and #c2 > 0 then table.insert(picked, c2[1]) end
      end
    end

    if #picked > 0 then
      room:obtainCard(player, picked, true, fk.ReasonGot, nil, j_fubing.name)
    end
  end,
})

j_fubing:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_fubing.name,
  think = function(self, player)
    return true
  end,
})

-- 测试：受伤后观看3张并选2张颜色不同获得
j_fubing:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_fubing.name)
  end)

  FkTest.runInRoom(function()
    -- 构造牌堆顶3张：2黑1红
    local drawPile = room.draw_pile
    local c1 = room:printCard("slash", Card.Spade, 5)   -- 黑
    local c2 = room:printCard("peach", Card.Heart, 6)   -- 红
    local c3 = room:printCard("jink", Card.Club, 7)     -- 黑
    -- 插入牌堆顶（reverse保持顺序：c1,c2,c3在顶）
    for _, id in ipairs({ c1.id, c2.id, c3.id }) do
      table.insert(drawPile, 1, id)
    end

    local before = #me:getCardIds("h")
    -- 第一张选黑（c1），第二张选红（c2）
    FkTest.setNextReplies(me, { "1", { c1.id }, { c2.id } })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(#me:getCardIds("h"), before + 2, "应获得两张牌")
  end)
end)

-- 测试：受伤后一张都不选 → 不获得牌
j_fubing:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_fubing.name)
  end)

  FkTest.runInRoom(function()
    local drawPile = room.draw_pile
    local c1 = room:printCard("slash", Card.Spade, 5)
    local c2 = room:printCard("peach", Card.Heart, 6)
    local c3 = room:printCard("jink", Card.Club, 7)
    for _, id in ipairs({ c1.id, c2.id, c3.id }) do
      table.insert(drawPile, 1, id)
    end

    local before = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", {}, {} })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(#me:getCardIds("h"), before, "不选牌则不应获得牌")
  end)
end)

return j_fubing