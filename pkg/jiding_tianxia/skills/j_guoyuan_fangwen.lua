-- 计国渊·访文
-- 出牌阶段限一次，你可以展示一张手牌，令一名角色交给你一张与其不同类型的牌，
-- 若此牌为基本牌，你可以视为对其使用一张【决斗】。
local j_guoyuan_fangwen = fk.CreateSkill {
  name = "j_guoyuan_fangwen",
}

Fk:loadTranslationTable{
  ["j_guoyuan_fangwen"] = "访文",
  [":j_guoyuan_fangwen"] = "出牌阶段限一次，你可以展示一张手牌，令一名角色交给你一张与其不同类型的牌，" ..
    "若此牌为基本牌，你可以视为对其使用一张【决斗】。",

  ["#j_guoyuan_fangwen-prompt"] = "访文：展示一张手牌，令一名角色交给你一张不同类型的牌",
  ["#j_guoyuan_fangwen-show"] = "访文：展示一张手牌",
  ["#j_guoyuan_fangwen-choose"] = "访文：选择一名角色，其交给你一张与展示牌不同类型的牌",
  ["#j_guoyuan_fangwen-give"] = "访文：交给 %dest 一张与你展示的牌不同类型的牌",
  ["#j_guoyuan_fangwen-duel"] = "访文：是否视为对 %dest 使用一张【决斗】？",

  ["$j_guoyuan_fangwen1"] = "博访通人，考之于文。",
  ["$j_guoyuan_fangwen2"] = "文以载道，访而得知。",
}

j_guoyuan_fangwen:addEffect("active", {
  anim_type = "control",
  prompt = "#j_guoyuan_fangwen-prompt",
  max_phase_use_time = 1,
  can_use = function(self, player)
    if player.room and player.phase ~= Player.Play then return false end
    return #player:getCardIds("h") > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = j_guoyuan_fangwen.name,
      prompt = "#j_guoyuan_fangwen-show",
    })
    if #cards == 0 then return end
    local shown = Fk:getCardById(cards[1])
    local shown_type = shown.type
    room:showCards(cards, player, player)

    -- 只能选择"手里有与展示牌不同类型之牌"的其他角色
    local targets = table.filter(room.alive_players, function(p)
      if p == player or p.dead then return false end
      return table.find(p:getCardIds("h"), function(id)
        return Fk:getCardById(id).type ~= shown_type
      end) ~= nil
    end)
    if #targets == 0 then return end

    local tos = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = j_guoyuan_fangwen.name,
      prompt = "#j_guoyuan_fangwen-choose",
    })
    if #tos == 0 then return end
    local to = tos[1]

    local gives = room:askToCards(to, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      pattern = ".|.|.|hand|.|^" .. shown:getTypeString(),
      skill_name = j_guoyuan_fangwen.name,
      prompt = "#j_guoyuan_fangwen-give::" .. player.id,
      cancelable = false,
    })
    if #gives == 0 then return end
    local got_basic = Fk:getCardById(gives[1]).type == Card.TypeBasic
    room:obtainCard(player, gives, true, fk.ReasonGive, to, j_guoyuan_fangwen.name)

    -- 交来的牌是基本牌 → 可以视为对其使用一张【决斗】
    if got_basic and not player.dead and not to.dead then
      local ok = room:askToSkillInvoke(player, {
        skill_name = j_guoyuan_fangwen.name,
        prompt = "#j_guoyuan_fangwen-duel::" .. to.id,
      })
      if ok and not to.dead then
        local duel = Fk:cloneCard("duel")
        duel.skillName = j_guoyuan_fangwen.name
        if player:canUseTo(duel, to) then
          room:useCard({ from = player, tos = { to }, card = duel })
        end
      end
    end
  end,
})

-- 测试1：展示装备牌 → 目标只能交非装备牌；交来基本牌可获得并可视为使用【决斗】
j_guoyuan_fangwen:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guoyuan_fangwen.name)
    me.phase = Player.Play
    comp.hp = comp.maxHp
    room:moveCards{
      ids = comp:getCardIds("h"),
      toArea = Card.DiscardPile,
      reason = fk.ReasonDiscard,
      from = comp,
    }
    local equip = room:printCard("qinggang_sword", Card.Spade, 3)
    local given = room:printCard("slash", Card.Club, 4)
    room:obtainCard(me, { equip.id }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp, { given.id }, true, fk.ReasonDraw, comp, "test")

    local realCards = room.askToCards
    local realChoose = room.askToChoosePlayers
    local realInvoke = room.askToSkillInvoke
    local give_pattern
    room.askToCards = function(self, who, params)
      if params.skill_name ~= j_guoyuan_fangwen.name then
        return realCards(self, who, params)
      end
      if who == me then return { equip.id } end
      give_pattern = params.pattern
      return { given.id }
    end
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_guoyuan_fangwen.name then return { comp } end
      return realChoose(self, who, params)
    end
    room.askToSkillInvoke = function(self, who, params)
      if params.skill_name == j_guoyuan_fangwen.name then return false end
      return realInvoke(self, who, params)
    end

    local eff = j_guoyuan_fangwen.effects[1]
    eff:onUse(room, { from = me, tos = {}, cards = {} })
    room.askToCards = realCards
    room.askToChoosePlayers = realChoose
    room.askToSkillInvoke = realInvoke

    lu.assertNotNil(give_pattern, "应要求目标交出不同类型的牌")
    lu.assertTrue(string.find(give_pattern, "%^equip") ~= nil, "展示装备牌时应排除装备: " .. give_pattern)
    lu.assertTrue(table.contains(me:getCardIds("h"), given.id), "国渊应获得目标交来的牌")
    lu.assertNotNil(Fk.all_card_types["duel"], "决斗牌应已注册")
  end)
end)

-- 测试2：展示基本牌 → 目标交锦囊牌，不触发决斗询问
j_guoyuan_fangwen:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guoyuan_fangwen.name)
    me.phase = Player.Play
    comp.hp = comp.maxHp
    room:moveCards{
      ids = me:getCardIds("h"),
      toArea = Card.DiscardPile,
      reason = fk.ReasonDiscard,
      from = me,
    }
    room:moveCards{
      ids = comp:getCardIds("h"),
      toArea = Card.DiscardPile,
      reason = fk.ReasonDiscard,
      from = comp,
    }
    local mine = room:printCard("slash", Card.Spade, 3)
    local trick = room:printCard("dismantlement", Card.Club, 4)
    room:obtainCard(me, { mine.id }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp, { trick.id }, true, fk.ReasonDraw, comp, "test")

    local realCards = room.askToCards
    local realChoose = room.askToChoosePlayers
    local realInvoke = room.askToSkillInvoke
    local invoke_count = 0
    room.askToCards = function(self, who, params)
      if params.skill_name ~= j_guoyuan_fangwen.name then
        return realCards(self, who, params)
      end
      if who == me then return { mine.id } end
      return { trick.id }
    end
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_guoyuan_fangwen.name then return { comp } end
      return realChoose(self, who, params)
    end
    room.askToSkillInvoke = function(self, who, params)
      if params.skill_name == j_guoyuan_fangwen.name then
        invoke_count = invoke_count + 1
        return false
      end
      return realInvoke(self, who, params)
    end

    local eff = j_guoyuan_fangwen.effects[1]
    eff:onUse(room, { from = me, tos = {}, cards = {} })
    room.askToCards = realCards
    room.askToChoosePlayers = realChoose
    room.askToSkillInvoke = realInvoke

    lu.assertEquals(invoke_count, 0, "交来的牌不是基本牌时不应询问决斗")
    lu.assertTrue(table.contains(me:getCardIds("h"), trick.id), "国渊应获得目标交来的锦囊牌")
  end)
end)

-- 测试3：没有符合牌型的角色时，不会弹选择框
j_guoyuan_fangwen:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guoyuan_fangwen.name)
    me.phase = Player.Play
    for i = 1, #room.players do
      room:moveCards{
        ids = room.players[i]:getCardIds("h"),
        toArea = Card.DiscardPile,
        reason = fk.ReasonDiscard,
        from = room.players[i],
      }
    end
    local mine = room:printCard("slash", Card.Spade, 3)
    local same = room:printCard("jink", Card.Club, 4)
    room:obtainCard(me, { mine.id }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp, { same.id }, true, fk.ReasonDraw, comp, "test")

    local realCards = room.askToCards
    local choose_called = false
    room.askToCards = function(self, who, params)
      if params.skill_name ~= j_guoyuan_fangwen.name then
        return realCards(self, who, params)
      end
      return { mine.id }
    end
    local realChoose = room.askToChoosePlayers
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_guoyuan_fangwen.name then
        choose_called = true
        return {}
      end
      return realChoose(self, who, params)
    end

    local eff = j_guoyuan_fangwen.effects[1]
    eff:onUse(room, { from = me, tos = {}, cards = {} })
    room.askToCards = realCards
    room.askToChoosePlayers = realChoose

    lu.assertFalse(choose_called, "没有符合条件的角色时不应弹出选择框")
    lu.assertTrue(table.contains(comp:getCardIds("h"), same.id), "目标的同类型牌不应被拿走")
  end)
end)

return j_guoyuan_fangwen
