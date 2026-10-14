local j_gongmou = fk.CreateSkill {
  name = "j_gongmou",
}

Fk:loadTranslationTable{
  ["j_gongmou"] = "共谋",
  [":j_gongmou"] = "一名角色的结束阶段，你可以观看牌堆顶和牌堆底各X张牌，然后将一张牌置于武将牌上为“谋”，其余牌以任意顺序置于牌堆顶或牌堆底。（X为你已损失体力值）",

  ["#j_gongmou-invoke"] = "共谋：是否观看牌堆顶和牌堆底各 %arg 张牌？",
  ["#j_gongmou-pick"] = "共谋：选择一张牌置于武将牌上为“谋”",
  ["#j_gongmou-arrange"] = "共谋：将其余牌以任意顺序置于牌堆顶或牌堆底",

  ["$j_gongmou1"] = "共商大计，谋定后动。",
  ["$j_gongmou2"] = "集思广益，共襄盛举。",
}

-- 一名角色的结束阶段触发
j_gongmou:addEffect(fk.EventPhaseStart, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_gongmou.name) or player.dead then return false end
    if not data or data.to ~= Player.Finish then return false end
    return player.maxHp - player.hp >= 1
  end,
  on_cost = function(self, event, target, player, data)
    local x = player.maxHp - player.hp
    return player.room:askToSkillInvoke(player, { skill_name = j_gongmou.name, prompt = "#j_gongmou-invoke::" .. x })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = player.maxHp - player.hp

    -- 观看牌堆顶和牌堆底各X张
    local top = room:getNCards(x)
    local bottom = room:getNCards(x, "bottom")
    local all = {}
    table.insertTable(all, top)
    table.insertTable(all, bottom)
    if #all == 0 then return end
    room:showCards(all, player)

    -- 选一张置于武将牌上为“谋”
    local mouId = room:askToChooseCard(player, {
      target = player,
      flag = { card_data = { { "$DrawPile", all } } },
      skill_name = j_gongmou.name,
      prompt = "#j_gongmou-pick",
    })
    if not mouId then return end
    player:addToPile("j_mou", mouId, true, j_gongmou.name)

    -- 其余牌以任意顺序置于牌堆顶或牌堆底
    local rest = {}
    for _, id in ipairs(all) do
      if id ~= mouId then table.insert(rest, id) end
    end
    if #rest > 0 then
      room:askToGuanxing(player, {
        cards = rest,
        top_limit = { 0, #rest },
        bottom_limit = { 0, #rest },
        skill_name = j_gongmou.name,
        prompt = "#j_gongmou-arrange",
      })
    end
  end,
})

j_gongmou:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_gongmou.name,
  think = function(self, player)
    return player.maxHp - player.hp >= 1
  end,
})

-- 测试：损失1体力时结束阶段 → 观看顶1底1 → 1张为谋、1张放回
j_gongmou:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_gongmou.name)
  end)

  FkTest.runInRoom(function()
    local drawPile = room.draw_pile
    -- 牌堆顶1张 + 牌堆底1张
    local c1 = room:printCard("slash", Card.Spade, 5)
    local c2 = room:printCard("peach", Card.Heart, 6)
    table.insert(drawPile, 1, c1.id)      -- 顶
    table.insert(drawPile, c2.id)         -- 底

    room:changeHp(me, -1, fk.LoseHp, "test")  -- 3/3 → 3/2，损失1
    lu.assertEquals(me.maxHp - me.hp, 1, "损失体力应为1")

    -- 选 c1 为“谋”；剩余 c2 置于牌堆顶（排序回复：置顶1张）
    FkTest.setNextReplies(me, { "1", c1.id, { { c2.id }, {} } })
    local phaseData = { from = Player.Discard, to = Player.Finish }
    room.logic:trigger(fk.EventPhaseStart, me, phaseData)

    lu.assertEquals(#me:getPile("j_mou"), 1, "应有一张谋")
    lu.assertEquals(me:getPile("j_mou")[1], c1.id, "谋应为选中的牌")
    lu.assertEquals(drawPile[1], c2.id, "剩余牌应置于牌堆顶")
  end)
end)

return j_gongmou