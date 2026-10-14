local j_bazheng = fk.CreateSkill {
  name = "j_bazheng",
}

Fk:loadTranslationTable{
  ["j_bazheng"] = "霸争",
  [":j_bazheng"] = "每回合每项限一次，当你使用红色牌指定其他角色为唯一目标，或其他角色使用红色牌指定你为唯一目标时，你可以将你与其区域内一种花色的牌全部置于牌堆顶（由你控制这些牌的排放顺序），失去牌多者视为对失去少者使用一张“决斗”并摸一张牌。",

  ["#j_bazheng-invoke"] = "霸争：是否发动？",
  ["#j_bazheng-suit"] = "霸争：选择一种花色",
  ["#j_bazheng-arrange"] = "霸争：将这些牌以任意顺序置于牌堆顶",
}

-- 每名角色回合开始时重置两项限制
-- 这里是纯记账，必须走静默的 refresh。
-- 若写成带 on_use 的触发效果而不给 on_cost，TriggerSkill:cost 会回退到
-- askToSkillInvoke（trigger.lua:101-110），于是每个角色回合开始时都会弹「是否发动」。
j_bazheng:addEffect(fk.EventPhaseStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(j_bazheng.name) and target.phase == Player.Start
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_bazheng1_used", 0)
    room:setPlayerMark(player, "j_bazheng2_used", 0)
  end,
})

j_bazheng:addEffect(fk.TargetSpecified, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_bazheng.name) then return false end
    local card = data.card
    if not card or card.color ~= Card.Red then return false end
    local tos = data.use and data.use.tos
    if not tos or #tos ~= 1 then return false end
    local the_other = tos[1]
    if not the_other then return false end

    -- 项一：你使用红色牌指定其他角色为唯一目标
    if data.from == player then
      if the_other == player then return false end
      return player:getMark("j_bazheng1_used") == 0
    end
    -- 项二：其他角色使用红色牌指定你为唯一目标（被指定目标必须是你本人）
    if the_other ~= player then return false end
    return player:getMark("j_bazheng2_used") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_bazheng.name, prompt = "#j_bazheng-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = event.room
    local tos = data.use and data.use.tos
    if not tos or #tos ~= 1 then return end
    local the_other = tos[1]

    local mark_name
    if data.from == player then
      the_other = the_other
      mark_name = "j_bazheng1_used"
    else
      -- 项二防御：被指定目标必须是你本人
      if the_other ~= player then return end
      the_other = data.from
      mark_name = "j_bazheng2_used"
    end
    if not the_other or the_other == player or not the_other:isAlive() then return end
    room:setPlayerMark(player, mark_name, 1)

    -- 选择一种花色
    local choice = room:askToChoice(player, {
      choices = { "log_spade", "log_heart", "log_club", "log_diamond" },
      skill_name = j_bazheng.name,
      prompt = "#j_bazheng-suit",
    })
    local suit
    if choice == "log_spade" then
      suit = Card.Spade
    elseif choice == "log_heart" then
      suit = Card.Heart
    elseif choice == "log_club" then
      suit = Card.Club
    else
      suit = Card.Diamond
    end

    -- 收集你与其区域内该花色的牌
    local card_ids = {}
    local me_lost, other_lost = 0, 0
    for _, p in ipairs{ player, the_other } do
      for _, cid in ipairs(p:getCardIds("hej")) do
        local c = Fk:getCardById(cid)
        if c and c.suit == suit then
          table.insert(card_ids, cid)
          if p == player then
            me_lost = me_lost + 1
          else
            other_lost = other_lost + 1
          end
        end
      end
    end
    if #card_ids == 0 then return end

    -- 由你控制排放顺序，置于牌堆顶（首张在最上方）
    local arranged = room:askToArrangeCards(player, {
      card_map = { card_ids },
      skill_name = j_bazheng.name,
      prompt = "#j_bazheng-arrange",
      free_arrange = true,
      min_limit = { #card_ids, 0 },
      max_limit = { #card_ids, 0 },
      area_names = { j_bazheng.name, "toObtain" },
    })
    local top_order = card_ids
    if arranged and type(arranged) == "table" then
      if type(arranged[1]) == "table" then
        top_order = arranged[1]
      else
        top_order = arranged
      end
    end
    for i = #top_order, 1, -1 do
      room:moveCardTo(top_order[i], Card.DrawPile, nil, fk.ReasonPut, j_bazheng.name)
    end

    -- 失去牌多者视为对失去少者使用一张“决斗”并摸一张牌
    if me_lost == other_lost then return end
    local winner, loser
    if me_lost > other_lost then
      winner, loser = player, the_other
    else
      winner, loser = the_other, player
    end
    local duel = Fk:cloneCard("duel")
    duel.skillName = j_bazheng.name
    room:useCard{ from = winner, tos = { loser }, card = duel }
    room:drawCards(winner, 1, j_bazheng.name)
  end,
})

-- 测试：其他角色使用红色牌指定你为唯一目标（项二）
j_bazheng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_bazheng.name)
  end)

  FkTest.runInRoom(function()
    local red = room:printCard("slash", Card.Heart, 1)
    room:obtainCard(me, { red }, true, fk.ReasonDraw, me, "test")

    -- me 回复：选红桃 → 排列（红桃杀置于牌堆顶）
    FkTest.setNextReplies(me, { { "log_heart" }, { { red.id }, {} } })
    -- comp2 回复：决斗响应不出杀
    FkTest.setNextReplies(comp2, { "" })

    local sk = Fk.skills[j_bazheng.name]:getSkeleton()
    local eff = nil
    for _, spec in ipairs(sk.effect_spec_list) do
      if spec[1] == fk.TargetSpecified then eff = spec[3] break end
    end
    local aim = {
      from = comp2,
      card = red,
      to = me,
      use = { from = comp2, tos = { me }, card = red },
    }
    eff:on_use({ room = room }, me, me, aim)

    -- 技能语义：置顶的红桃杀被失去牌多者（me）摸回手里
    lu.assertEquals(#me:getCardIds("h"), 1, "失去牌多者摸一张牌")
    lu.assertTrue(table.contains(me:getCardIds("h"), red.id), "置顶的牌被摸回手中")
    -- 决斗对失去牌少者（comp2）造成 1 点伤害
    lu.assertEquals(comp2.hp, comp2.maxHp - 1, "决斗对失去牌少者造成伤害")
  end)
end)

-- 测试：你使用红色牌指定其他角色为唯一目标（项一）
j_bazheng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_bazheng.name)
  end)

  FkTest.runInRoom(function()
    local red = room:printCard("slash", Card.Diamond, 1)
    room:obtainCard(me, { red }, true, fk.ReasonDraw, me, "test")
    -- 让对方也有一张同花色牌，制造 other_lost > 0
    local red2 = room:printCard("peach", Card.Diamond, 1)
    room:obtainCard(comp2, { red2 }, true, fk.ReasonDraw, comp2, "test")

    FkTest.setNextReplies(me, { { "log_diamond" }, { { red.id, red2.id }, {} } })
    FkTest.setNextReplies(comp2, { "" })

    local sk = Fk.skills[j_bazheng.name]:getSkeleton()
    local eff = nil
    for _, spec in ipairs(sk.effect_spec_list) do
      if spec[1] == fk.TargetSpecified then eff = spec[3] break end
    end
    local aim = {
      from = me,
      card = red,
      to = comp2,
      use = { from = me, tos = { comp2 }, card = red },
    }
    eff:on_use({ room = room }, me, me, aim)

    lu.assertFalse(table.contains(me:getCardIds("h"), red.id), "你的该花色牌应被置于牌堆顶")
    lu.assertFalse(table.contains(comp2:getCardIds("h"), red2.id), "目标的该花色牌应被置于牌堆顶")
    lu.assertEquals(#me:getCardIds("h"), 0, "失去牌数相等时不摸牌")
  end)
end)

-- 回归测试：回合开始的重置必须是静默 refresh。
-- 一旦写回 on_use / on_cost 的触发形式，TriggerSkill:cost 会回退成 askToSkillInvoke，
-- 于是在每个角色回合开始时都会弹「霸争：是否发动？」。
j_bazheng:addTest(function(room, me)
  local skel = Fk.skills[j_bazheng.name]:getSkeleton()
  local eff
  for _, spec in ipairs(skel.effect_spec_list) do
    if spec[1] == fk.EventPhaseStart then eff = spec[3] break end
  end
  lu.assertNotIsNil(eff, "霸争：应存在 EventPhaseStart 效果")
  lu.assertIsNil(eff.on_use, "回合开始的重置不得使用 on_use，否则会弹询问")
  lu.assertIsNil(eff.on_cost, "回合开始的重置不得使用 on_cost")
  lu.assertNotIsNil(eff.can_refresh, "回合开始的重置应走 can_refresh（静默）")
  lu.assertNotIsNil(eff.on_refresh, "回合开始的重置应走 on_refresh（静默）")
end)

-- 回归测试：触发条件判定（can_trigger）
-- ①其他角色用红牌指定其他角色（均非计孙策）→ 不得触发
-- ②其他角色用红牌指定计孙策本人 → 项二触发
-- ③计孙策用红牌指定其他角色 → 项一触发
j_bazheng:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_bazheng.name)
  end)

  FkTest.runInRoom(function()
    local red = room:printCard("slash", Card.Heart, 1)

    local sk = Fk.skills[j_bazheng.name]:getSkeleton()
    local eff = nil
    for _, spec in ipairs(sk.effect_spec_list) do
      if spec[1] == fk.TargetSpecified then eff = spec[3] break end
    end

    -- ① 别人指定别人：不触发
    local ok = eff:can_trigger({ room = room }, comp2, me, {
      from = comp2, card = red, to = comp3,
      use = { from = comp2, tos = { comp3 }, card = red },
    })
    lu.assertFalse(ok, "其他角色用红牌指定其他角色时不应触发霸争")

    -- ② 别人指定我：项二触发
    ok = eff:can_trigger({ room = room }, comp2, me, {
      from = comp2, card = red, to = me,
      use = { from = comp2, tos = { me }, card = red },
    })
    lu.assertIsTrue(ok, "其他角色用红牌指定你时应触发霸争（项二）")

    -- ③ 我指定别人：项一触发
    ok = eff:can_trigger({ room = room }, me, me, {
      from = me, card = red, to = comp2,
      use = { from = me, tos = { comp2 }, card = red },
    })
    lu.assertIsTrue(ok, "你用红牌指定其他角色时应触发霸争（项一）")
  end)
end)

return j_bazheng