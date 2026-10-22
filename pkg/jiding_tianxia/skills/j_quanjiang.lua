-- 计蒋济·劝降
-- 出牌阶段限一次（义疚可增加次数），令一名其他角色选择一项：
-- 1.横置武将牌并交给你一张手牌；2.失去一点体力并对你使用一张杀（有距离限制）。
local j_quanjiang = fk.CreateSkill {
  name = "j_quanjiang",
}

Fk:loadTranslationTable{
  ["j_quanjiang"] = "劝降",
  [":j_quanjiang"] = "出牌阶段限一次，你可以令一名其他角色选择一项：1.横置武将牌并交给你一张手牌；2.失去一点体力并对你使用一张【杀】（有距离限制）。",

  ["#j_quanjiang-target"] = "劝降：选择一名其他角色",
  ["#j_quanjiang-choose"] = "劝降：请选择一项",
  ["#j_quanjiang-give"] = "劝降：交给其一张手牌",
  ["j_quanjiang_opt1"] = "横置武将牌并交给其一张手牌",
  ["j_quanjiang_opt2"] = "失去一点体力并对其使用一张【杀】",
}

j_quanjiang:addEffect("active", {
  anim_type = "control",
  prompt = "#j_quanjiang-target",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    -- 次数上限 = 1 + 义疚提供的下回合加成
    return player:usedSkillTimes(j_quanjiang.name, Player.HistoryTurn)
      < 1 + player:getMark("j_quanjiang_extra-turn")
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    if not target or target.dead then return end
    -- 记录“成为过劝降目标”（供义疚判定，永久标记）
    room:setPlayerMark(target, "@@j_quanjiang_targeted", 1)
    -- 选项2需在目标攻击范围内（对其使用【杀】有距离限制）
    local choices = { "j_quanjiang_opt1" }
    if not target.dead and target:inMyAttackRange(player) then
      table.insert(choices, "j_quanjiang_opt2")
    end
    local choice = room:askToChoice(target, {
      choices = choices,
      skill_name = j_quanjiang.name,
      prompt = "#j_quanjiang-choose",
      cancelable = false,
    })
    if choice == "j_quanjiang_opt1" then
      -- 横置武将牌并交给其一张手牌
      if not target.chained then
        target:setChainState(true)
      end
      if not target.dead and #target:getCardIds("h") > 0 then
        local give = room:askToChooseCards(target, {
          target = target,
          flag = "h",
          min = 1,
          max = 1,
          cancelable = false,
          pattern = ".",
          skill_name = j_quanjiang.name,
          prompt = "#j_quanjiang-give",
        })
        if give and #give > 0 then
          room:moveCardTo(give, Card.PlayerHand, player, fk.ReasonGive, j_quanjiang.name, nil, false, target)
        end
      end
    elseif choice == "j_quanjiang_opt2" then
      -- 失去一点体力并对其使用一张【杀】
      room:loseHp(target, 1, j_quanjiang.name, player)
      if not target.dead then
        room:askToUseVirtualCard(target, {
          name = "slash",
          skill_name = j_quanjiang.name,
          cancelable = false,
          extra_data = { fix_targets = { player.id } },
        })
      end
    end
  end,
})

-- 测试：选项1 → 目标横置并交给你一张手牌
j_quanjiang:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_quanjiang.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(comp2, { c1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local origChoice = room.askToChoice
    local origChooseCards = room.askToChooseCards
    room.askToChoice = function(self, who, params)
      if who == comp2 then return "j_quanjiang_opt1" end
      return origChoice(self, who, params)
    end
    room.askToChooseCards = function(self, who, params)
      if who == comp2 then return { c1.id } end
      return origChooseCards(self, who, params)
    end

    local skel = Fk.skills[j_quanjiang.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    spec:on_use(room, { from = me, tos = { comp2 }, cards = {} })

    room.askToChoice = origChoice
    room.askToChooseCards = origChooseCards
    lu.assertTrue(comp2.chained, "选项1应横置目标武将牌")
    lu.assertTrue(table.contains(me:getCardIds("h"), c1.id), "应获得目标交的手牌")
    lu.assertTrue(comp2:getMark("@@j_quanjiang_targeted") > 0, "应记录劝降目标")
  end)
end)

-- 测试：选项2 → 目标失去一点体力并对你使用一张杀
j_quanjiang:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_quanjiang.name)
    room.current = me
    me.phase = Player.Play
  end)
  FkTest.runInRoom(function()
    local origChoice = room.askToChoice
    local origUseVirtual = room.askToUseVirtualCard
    local usedOn = nil
    room.askToChoice = function(self, who, params)
      if who == comp2 then return "j_quanjiang_opt2" end
      return origChoice(self, who, params)
    end
    room.askToUseVirtualCard = function(self, who, params)
      if who == comp2 then
        usedOn = params.extra_data and params.extra_data.fix_targets
        return true
      end
      return origUseVirtual(self, who, params)
    end

    local skel = Fk.skills[j_quanjiang.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    spec:on_use(room, { from = me, tos = { comp2 }, cards = {} })

    room.askToChoice = origChoice
    room.askToUseVirtualCard = origUseVirtual
    lu.assertEquals(comp2.hp, comp2.maxHp - 1, "选项2应失去一点体力")
    lu.assertNotNil(usedOn, "应使用一张杀")
    lu.assertTrue(table.contains(usedOn, me.id), "杀应对你使用")
  end)
end)

return j_quanjiang
