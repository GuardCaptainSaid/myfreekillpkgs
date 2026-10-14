local j_xiandao = fk.CreateSkill {
  name = "j_xiandao",
  tags = { Skill.Wake },
}

Fk:loadTranslationTable{
  ["j_xiandao"] = "献刀",
  [":j_xiandao"] = "觉醒技，出牌阶段，当你装备装备牌时，你可以弃置所有区域的牌，然后摸等量的牌。若你弃置的牌中有基本牌，你摸三张牌并获得技能“奸雄”；若你弃置的牌中有锦囊牌，你令一名角色加一点体力上限并获得技能“集智”；若你弃置的牌中有武器牌，你将其交给一名角色并获得技能“强袭”；若你弃置的牌中有坐骑牌，你将-1马移出游戏并获得技能“马术”；若你弃置的牌中有防具牌，你废除防具栏并获得技能“空城”；若你至少执行了三项，你失去“献刀”并获得技能“遗风”。",

  ["#j_xiandao-maxhp"] = "献刀：选择一名角色，令其增加一点体力上限",
  ["#j_xiandao-give"] = "献刀：选择一名角色，将武器牌交给其",
}

-- 觉醒技：出牌阶段装备装备牌时发动
j_xiandao:addEffect(fk.AfterCardsMove, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xiandao.name) then return false end
    if player:getMark("j_xiandao_used") ~= 0 then return false end
    if player.phase ~= Player.Play then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.PlayerEquip and move.to == player then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_xiandao.name })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room

    -- 标记已觉醒（觉醒技一次性）
    room:setPlayerMark(player, "j_xiandao_used", 1)

    -- 1. 弃置所有区域的牌（手牌+装备+判定），记录被弃的牌
    local cards = {}
    table.insertTable(cards, player:getCardIds(Player.Hand))
    table.insertTable(cards, player:getCardIds(Player.Equip))
    table.insertTable(cards, player:getCardIds(Player.Judge))
    local n = #cards
    if n > 0 then
      room:throwCard(cards, j_xiandao.name, player, player)
    end

    -- 2. 摸等量的牌
    if n > 0 then
      room:drawCards(player, n, j_xiandao.name)
    end

    -- 3. 按弃置牌类型分类
    local has_basic, has_trick, has_armor = false, false, false
    local weapon_card, ride_card
    for _, id in ipairs(cards) do
      local c = Fk:getCardById(id)
      if c.type == Card.TypeBasic then
        has_basic = true
      elseif c.type == Card.TypeTrick then
        has_trick = true
      elseif c.sub_type == Card.SubtypeWeapon then
        weapon_card = weapon_card or id
      elseif c.sub_type == Card.SubtypeDefensiveRide or c.sub_type == Card.SubtypeOffensiveRide then
        ride_card = ride_card or id
      elseif c.sub_type == Card.SubtypeArmor then
        has_armor = true
      end
    end

    local executed = 0

    -- 基本牌：摸三张牌，获得"奸雄"
    if has_basic then
      executed = executed + 1
      room:drawCards(player, 3, j_xiandao.name)
      room:handleAddLoseSkills(player, "jianxiong", j_xiandao.name)
    end

    -- 锦囊牌：令一名角色加一点体力上限，获得"集智"
    if has_trick then
      executed = executed + 1
      local targets = table.filter(room.alive_players, function(p)
        return p ~= player
      end)
      if #targets > 0 then
        local chosen = room:askToChoosePlayers(player, {
          targets = targets,
          min_num = 1,
          max_num = 1,
          skill_name = j_xiandao.name,
          prompt = "#j_xiandao-maxhp",
          cancelable = false,
        })
        room:changeMaxHp(chosen[1], 1)
      end
      room:handleAddLoseSkills(player, "jizhi", j_xiandao.name)
    end

    -- 武器牌：交给一名角色，获得"强袭"
    if weapon_card then
      executed = executed + 1
      local targets = table.filter(room.alive_players, function(p)
        return p ~= player
      end)
      if #targets > 0 then
        local chosen = room:askToChoosePlayers(player, {
          targets = targets,
          min_num = 1,
          max_num = 1,
          skill_name = j_xiandao.name,
          prompt = "#j_xiandao-give",
          cancelable = false,
        })
        room:moveCardTo(weapon_card, Card.PlayerHand, chosen[1], fk.ReasonGive, j_xiandao.name, nil, true, player)
      end
      room:handleAddLoseSkills(player, "j_qiangxi", j_xiandao.name)
    end

    -- 坐骑牌：移出游戏，获得"马术"
    if ride_card then
      executed = executed + 1
      room:moveCardTo(ride_card, Card.Void, nil, fk.ReasonJustMove, j_xiandao.name)
      room:handleAddLoseSkills(player, "mashu", j_xiandao.name)
    end

    -- 防具牌：废除防具栏，获得"空城"
    if has_armor then
      executed = executed + 1
      room:abortPlayerArea(player, Player.ArmorSlot)
      room:handleAddLoseSkills(player, "kongcheng", j_xiandao.name)
    end

    -- 4. 至少执行三项：失去"献刀"，获得"遗风"
    if executed >= 3 then
      -- 移除主技能时不能传 source_skill（会走 derivative 分支导致移不掉），分两次调用
      room:handleAddLoseSkills(player, "-j_xiandao")
      room:handleAddLoseSkills(player, "j_yifeng", j_xiandao.name)
    end
  end,
})

-- 测试：出牌阶段装备装备牌时觉醒，弃置所有区域牌摸等量牌，按类型获得技能
j_xiandao:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiandao.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("guding_blade")  -- 武器牌
    local basic = room:printCard("slash")         -- 基本牌
    room:obtainCard(me, { equip, basic }, true, fk.ReasonDraw, me, "test")

    me.phase = Player.Play
    FkTest.setNextReplies(me, {
      "1",                                  -- 献刀觉醒询问
      FkTest.ReplyChoosePlayer({ comp2 }),  -- 武器牌交给 comp2
      "",
    })
    room:useCard{ from = me, tos = { me }, card = equip }
    me.phase = Player.NotActive

    -- 弃置 2 张（手牌基本牌 + 装备区武器牌）→ 摸 2；基本牌 → 再摸 3
    lu.assertEquals(#me:getCardIds("h"), 5, "献刀：弃2摸2+基本牌摸3应共5张")
    -- 获得奸雄与强袭
    lu.assertIsTrue(me:hasSkill("jianxiong"), "献刀：弃置基本牌应获得奸雄")
    lu.assertIsTrue(me:hasSkill("j_qiangxi"), "献刀：弃置武器牌应获得强袭")
    -- 武器牌交给 comp2
    lu.assertIsTrue(table.find(comp2:getCardIds("h"), function(id)
      return Fk:getCardById(id).trueName == "guding_blade"
    end) ~= nil, "献刀：武器牌应交给目标角色")
    -- 仅执行 2 项，献刀保留
    lu.assertIsTrue(me:hasSkill(j_xiandao.name), "献刀：不足三项时保留献刀")
    lu.assertFalse(me:hasSkill("j_yifeng"), "献刀：不足三项时不获得遗风")
  end)
end)

-- 测试：弃置牌覆盖三类以上时，失去献刀并获得遗风
j_xiandao:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiandao.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("guding_blade")   -- 武器牌
    local basic = room:printCard("slash")          -- 基本牌
    local trick = room:printCard("duel")           -- 锦囊牌
    local ride = room:printCard("chitu")           -- -1马
    local armor = room:printCard("nioh_shield")    -- 防具牌
    room:obtainCard(me, { equip, basic, trick, ride, armor }, true, fk.ReasonDraw, me, "test")

    me.phase = Player.Play
    FkTest.setNextReplies(me, {
      "1",                                  -- 献刀觉醒询问
      FkTest.ReplyChoosePlayer({ comp2 }),  -- 武器牌交给 comp2
      FkTest.ReplyChoosePlayer({ comp2 }),  -- 锦囊牌：comp2 增加体力上限
      "",
    })
    room:useCard{ from = me, tos = { me }, card = equip }
    me.phase = Player.NotActive

    -- 5 项全部执行 → 失去献刀，获得遗风
    lu.assertFalse(me:hasSkill(j_xiandao.name), "献刀：至少三项应失去献刀")
    lu.assertIsTrue(me:hasSkill("j_yifeng"), "献刀：至少三项应获得遗风")
    -- 锦囊牌：目标加一点体力上限
    lu.assertEquals(comp2.maxHp, 5, "献刀：锦囊牌令目标增加一点体力上限")
    -- 防具牌：废除防具栏
    lu.assertIsTrue(table.contains(me.sealedSlots, Player.ArmorSlot), "献刀：弃置防具牌应废除防具栏")
    -- 坐骑牌：移出游戏（Void 区）
    lu.assertEquals(room:getCardArea(ride.id), Card.Void, "献刀：坐骑牌应移出游戏")
    -- 基本牌：再摸 3（弃5摸5+3=8 张手牌）
    lu.assertEquals(#me:getCardIds("h"), 8, "献刀：弃5摸5+基本牌摸3应共8张")
  end)
end)

-- 测试：非出牌阶段装备装备牌时不触发觉醒
j_xiandao:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiandao.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("spear")
    me.phase = Player.NotActive
    FkTest.setNextReplies(me, { "1" })
    room:useCard{ from = me, tos = { me }, card = equip }
    me.phase = Player.NotActive

    lu.assertEquals(me:getMark("j_xiandao_used"), 0, "献刀：非出牌阶段不应觉醒")
  end)
end)

return j_xiandao