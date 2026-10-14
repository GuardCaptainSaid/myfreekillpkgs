-- 阮咸·议律（连招技）
-- 出牌阶段按顺序使用三种类型的牌达成连招：
-- 1.(基本-锦囊-装备) 你摸五张牌，本回合手牌上限+1，若你的手牌数大于你体力值，你本回合至多再使用三张牌；
-- 2.(装备-锦囊-装备) 弃置一张装备牌，对三名角色造成一点伤害；
-- 3.(装备-基本-基本) 弃置一名角色一张牌；
-- 4.(锦囊-锦囊-锦囊) 你摸五张牌。
local j_yilv = fk.CreateSkill {
  name = "j_yilv",
  tags = { Skill.Combo },
}

local SEQ_MARK_1 = "@j_yilv_seq1"
local SEQ_MARK_2 = "@j_yilv_seq2"
local SEQ_MARK_3 = "@j_yilv_seq3"

local function comboIdx(seq1, seq2, seq3)
  if seq1 == Card.TypeBasic and seq2 == Card.TypeTrick and seq3 == Card.TypeEquip then
    return 1
  elseif seq1 == Card.TypeEquip and seq2 == Card.TypeTrick and seq3 == Card.TypeEquip then
    return 2
  elseif seq1 == Card.TypeEquip and seq2 == Card.TypeBasic and seq3 == Card.TypeBasic then
    return 3
  elseif seq1 == Card.TypeTrick and seq2 == Card.TypeTrick and seq3 == Card.TypeTrick then
    return 4
  end
  return 0
end

Fk:loadTranslationTable{
  ["j_yilv"] = "议律",
  [":j_yilv"] = "连招技。出牌阶段按顺序使用指定类型的牌可触发效果：1.（基本牌-锦囊牌-装备牌）你摸五张牌，本回合手牌上限+1，若你的手牌数大于你体力值，你本回合至多再使用三张牌；2.（装备牌-锦囊牌-装备牌）弃置一张装备牌，对三名角色造成一点伤害；3.（装备牌-基本牌-基本牌）弃置一名角色一张牌；4.（锦囊牌-锦囊牌-锦囊牌）你摸五张牌。",

  ["#j_yilv-eq"] = "议律：弃置一张装备牌",
  ["#j_yilv-dmg"] = "议律：选择三名角色造成一点伤害",
  ["#j_yilv-discard"] = "议律：弃置一名角色一张牌",
  ["#j_yilv-get"] = "议律：选择该角色一张牌弃置",

  ["$j_yilv1"] = "竹林雅韵，律动心声。",
  ["$j_yilv2"] = "琵琶在手，一弦一意。",
}

-- 出牌后记录类型序列，命中组合则标记连招
j_yilv:addEffect(fk.AfterCardUseDeclared, {
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_yilv.name, true) and not player.dead
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if not data.card then return end
    local t = data.card.type
    if t ~= Card.TypeBasic and t ~= Card.TypeTrick and t ~= Card.TypeEquip then return end
    local s1 = player:getMark(SEQ_MARK_1)
    local s2 = player:getMark(SEQ_MARK_2)
    local s3 = player:getMark(SEQ_MARK_3)
    room:setPlayerMark(player, SEQ_MARK_1, s2)
    room:setPlayerMark(player, SEQ_MARK_2, s3)
    room:setPlayerMark(player, SEQ_MARK_3, t)
    local idx = comboIdx(s2, s3, t)
    if idx > 0 then
      data.extra_data = data.extra_data or {}
      data.extra_data.combo_skill = data.extra_data.combo_skill or {}
      data.extra_data.combo_skill[j_yilv.name] = true
      data.extra_data.combo_idx = data.extra_data.combo_idx or {}
      data.extra_data.combo_idx[j_yilv.name] = idx
    end
  end,
})

-- 本回合出牌额度（效果1的“至多再使用三张牌”）每次出牌扣减
j_yilv:addEffect(fk.CardUsing, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player:getMark("@j_yilv_quota") <= 0 then return false end
    if data.extra_data and data.extra_data.combo_skill and data.extra_data.combo_skill[j_yilv.name] then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@j_yilv_quota", player:getMark("@j_yilv_quota") - 1)
  end,
})

-- 连招结算
j_yilv:addEffect(fk.CardUsing, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_yilv.name) and
      data.extra_data and data.extra_data.combo_skill and data.extra_data.combo_skill[j_yilv.name]
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local idx = data.extra_data.combo_idx and data.extra_data.combo_idx[j_yilv.name] or 1
    -- 连招结算后清空序列
    room:setPlayerMark(player, SEQ_MARK_1, 0)
    room:setPlayerMark(player, SEQ_MARK_2, 0)
    room:setPlayerMark(player, SEQ_MARK_3, 0)

    if idx == 1 then
      -- 摸五张，本回合手牌上限+1，若手牌数>体力值 → 至多再使用三张牌
      player:drawCards(5, j_yilv.name)
      if player:getMark("@j_yilv_maxcards_on") == 0 then
        room:setPlayerMark(player, "@j_yilv_maxcards_old", player:getMark(MarkEnum.AddMaxCards))
        room:setPlayerMark(player, "@j_yilv_maxcards_on", 1)
      end
      room:setPlayerMark(player, MarkEnum.AddMaxCards, player:getMark(MarkEnum.AddMaxCards) + 1)
      if #player:getCardIds("h") > player.hp then
        room:setPlayerMark(player, "@j_yilv_quota", 3)
        room:setPlayerMark(player, "@j_yilv_limit_on", 1)
      end
    elseif idx == 2 then
      -- 弃置一张装备牌，对三名角色造成一点伤害
      local eq = room:askToChooseCards(player, {
        target = player,
        flag = "e",
        min = 1,
        max = 1,
        cancelable = false,
        pattern = ".",
        skill_name = j_yilv.name,
        prompt = "#j_yilv-eq",
      })
      if not eq or #eq == 0 then return end
      room:throwCard(eq, j_yilv.name, player, player)
      local candidates = table.filter(room:getOtherPlayers(player), function(p) return not p.dead end)
      if #candidates == 0 then return end
      local targets = room:askToChoosePlayers(player, {
        targets = candidates,
        min_num = 3,
        max_num = 3,
        cancelable = false,
        skill_name = j_yilv.name,
        prompt = "#j_yilv-dmg",
      })
      for _, t in ipairs(targets) do
        room:damage{ from = player, to = t, damage = 1, damageType = fk.NormalDamage, skillName = j_yilv.name }
      end
    elseif idx == 3 then
      -- 弃置一名角色一张牌
      local candidates = table.filter(room:getOtherPlayers(player), function(p)
        return not p.dead and not p:isAllNude()
      end)
      if #candidates == 0 then return end
      local t = room:askToChoosePlayers(player, {
        targets = candidates,
        min_num = 1,
        max_num = 1,
        cancelable = false,
        skill_name = j_yilv.name,
        prompt = "#j_yilv-discard",
      })[1]
      if not t then return end
      local c = room:askToChooseCards(player, {
        target = t,
        flag = "hej",
        min = 1,
        max = 1,
        cancelable = false,
        pattern = ".",
        skill_name = j_yilv.name,
        prompt = "#j_yilv-get",
      })
      if c and #c > 0 then
        room:throwCard(c, j_yilv.name, t, player)
      end
    else
      -- 摸五张牌
      player:drawCards(5, j_yilv.name)
    end
  end,
})

-- 回合结束：恢复手牌上限、清除额度限制与序列
j_yilv:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Finish then return false end
    if player.room.current ~= player then return false end
    if not player:hasSkill(j_yilv.name, true) and player:getMark("@j_yilv_limit_on") == 0 and
      player:getMark("@j_yilv_maxcards_on") == 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player:getMark("@j_yilv_limit_on") > 0 then
      room:setPlayerMark(player, "@j_yilv_limit_on", 0)
      room:setPlayerMark(player, "@j_yilv_quota", 0)
    end
    if player:getMark("@j_yilv_maxcards_on") > 0 then
      room:setPlayerMark(player, MarkEnum.AddMaxCards, player:getMark("@j_yilv_maxcards_old"))
      room:setPlayerMark(player, "@j_yilv_maxcards_old", 0)
      room:setPlayerMark(player, "@j_yilv_maxcards_on", 0)
    end
    room:setPlayerMark(player, SEQ_MARK_1, 0)
    room:setPlayerMark(player, SEQ_MARK_2, 0)
    room:setPlayerMark(player, SEQ_MARK_3, 0)
  end,
})

-- 额度耗尽：本回合出牌阶段内禁止使用牌
j_yilv:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    if player:getMark("@j_yilv_limit_on") == 1 and player:getMark("@j_yilv_quota") == 0 and
      player.room.current == player and player.phase == Player.Play then
      return true
    end
    return false
  end,
})

j_yilv:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_yilv.name,
  think = function(self, player)
    return true
  end,
})

-- 测试：基本-锦囊-装备 → 摸5、手牌上限+1、手牌>体力 → 额度3
j_yilv:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yilv.name)
    me.maxHp = 3
    me.hp = 1
    room.current = me
    me.phase = Player.Play
    local c1 = room:printCard("slash", Card.Club, 2)          -- 基本
    local c2 = room:printCard("snatch", Card.Spade, 3)        -- 锦囊
    local c3 = room:printCard("crossbow", Card.Heart, 4) -- 装备
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local hand = me:getCardIds("h")
    local c1, c2, c3 = Fk:getCardById(hand[1]), Fk:getCardById(hand[2]), Fk:getCardById(hand[3])
    local handBefore = #me:getCardIds("h")
    local maxcBefore = me:getMark(MarkEnum.AddMaxCards)

    local d1 = { card = c1, extra_data = {}, from = me }
    room.logic:trigger(fk.AfterCardUseDeclared, me, d1)
    local d2 = { card = c2, extra_data = {}, from = me }
    room.logic:trigger(fk.AfterCardUseDeclared, me, d2)
    local d3 = { card = c3, extra_data = {}, from = me }
    room.logic:trigger(fk.AfterCardUseDeclared, me, d3)

    lu.assertTrue(d3.extra_data.combo_skill[j_yilv.name], "议律：应命中连招")
    lu.assertEquals(d3.extra_data.combo_idx[j_yilv.name], 1, "议律：应为效果1")

    room.logic:trigger(fk.CardUsing, me, d3)
    lu.assertEquals(#me:getCardIds("h"), handBefore + 5, "议律：应摸5张")
    lu.assertEquals(me:getMark(MarkEnum.AddMaxCards), maxcBefore + 1, "议律：手牌上限应+1")
    lu.assertEquals(me:getMark("@j_yilv_quota"), 3, "议律：手牌>体力应获得3张额度")
    lu.assertEquals(me:getMark("@j_yilv_limit_on"), 1, "议律：应开启出牌限制")

    -- 额度扣减：使用3张后额度归零
    local d4 = { card = c2, extra_data = {}, from = me }
    room.logic:trigger(fk.CardUsing, me, d4)
    room.logic:trigger(fk.CardUsing, me, d4)
    room.logic:trigger(fk.CardUsing, me, d4)
    lu.assertEquals(me:getMark("@j_yilv_quota"), 0, "议律：使用3张后额度应为0")

    -- 回合结束恢复
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Play, to = Player.Finish })
    lu.assertEquals(me:getMark(MarkEnum.AddMaxCards), maxcBefore, "议律：回合结束应恢复手牌上限")
    lu.assertEquals(me:getMark("@j_yilv_limit_on"), 0, "议律：回合结束应清除限制")
  end)
end)

-- 测试：装备-锦囊-装备 → 弃装备并对三名角色造成伤害
j_yilv:addTest(function(room, me)
  local comp2, comp3, comp4 = room.players[2], room.players[3], room.players[4]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yilv.name)
    me.maxHp = 3
    me.hp = 3
    room.current = me
    me.phase = Player.Play
    local e1 = room:printCard("crossbow", Card.Club, 2)
    local t1 = room:printCard("snatch", Card.Spade, 3)
    local e2 = room:printCard("eight_diagram", Card.Heart, 4) -- 八卦阵（防具）
    room:obtainCard(me, { e1, t1, e2 }, true, fk.ReasonDraw, me, "test")
    -- 将两张装备牌装上装备区
    room:moveCardTo(e1, Player.Equip, me, fk.ReasonPut, "test")
    room:moveCardTo(e2, Player.Equip, me, fk.ReasonPut, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local hand = me:getCardIds("h")
    local c1, c2, c3 = Fk:getCardById(hand[1]), Fk:getCardById(hand[2]), Fk:getCardById(hand[3])
    local eq = me:getCardIds("e")
    local hp2, hp3, hp4 = comp2.hp, comp3.hp, comp4.hp

    local d1 = { card = c1, extra_data = {}, from = me }
    room.logic:trigger(fk.AfterCardUseDeclared, me, d1)
    local d2 = { card = c2, extra_data = {}, from = me }
    room.logic:trigger(fk.AfterCardUseDeclared, me, d2)
    local d3 = { card = c3, extra_data = {}, from = me }
    room.logic:trigger(fk.AfterCardUseDeclared, me, d3)

    lu.assertEquals(d3.extra_data.combo_idx[j_yilv.name], 2, "议律：应为效果2")

    FkTest.setNextReplies(me, { { eq[1] }, FkTest.ReplyChoosePlayer({ comp2, comp3, comp4 }) })
    room.logic:trigger(fk.CardUsing, me, d3)
    lu.assertEquals(#me:getCardIds("e"), 1, "议律：应弃置一张装备牌")
    lu.assertEquals(comp2.hp, hp2 - 1, "议律：目标2应受1点伤害")
    lu.assertEquals(comp3.hp, hp3 - 1, "议律：目标3应受1点伤害")
    lu.assertEquals(comp4.hp, hp4 - 1, "议律：目标4应受1点伤害")
  end)
end)

-- 测试：锦囊-锦囊-锦囊 → 摸5张
j_yilv:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yilv.name)
    me.maxHp = 3
    me.hp = 3
    room.current = me
    me.phase = Player.Play
    local t1 = room:printCard("snatch", Card.Spade, 3)
    local t2 = room:printCard("dismantlement", Card.Club, 4)
    local t3 = room:printCard("duel", Card.Heart, 5)
    room:obtainCard(me, { t1, t2, t3 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local hand = me:getCardIds("h")
    local c1, c2, c3 = Fk:getCardById(hand[1]), Fk:getCardById(hand[2]), Fk:getCardById(hand[3])
    local handBefore = #me:getCardIds("h")
    local d1 = { card = c1, extra_data = {}, from = me }
    room.logic:trigger(fk.AfterCardUseDeclared, me, d1)
    local d2 = { card = c2, extra_data = {}, from = me }
    room.logic:trigger(fk.AfterCardUseDeclared, me, d2)
    local d3 = { card = c3, extra_data = {}, from = me }
    room.logic:trigger(fk.AfterCardUseDeclared, me, d3)
    lu.assertEquals(d3.extra_data.combo_idx[j_yilv.name], 4, "议律：应为效果4")
    room.logic:trigger(fk.CardUsing, me, d3)
    lu.assertEquals(#me:getCardIds("h"), handBefore + 5, "议律：锦囊三连应摸5张")
  end)
end)

return j_yilv