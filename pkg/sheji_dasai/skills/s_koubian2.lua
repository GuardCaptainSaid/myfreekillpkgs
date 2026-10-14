-- 轲比能二号·寇边
-- 出牌阶段限一次，你可以令一名其他角色选择一项：1.令你随机获得其区域内的一张牌；2.本回合内下一次受到你的伤害+1。
local s_koubian2 = fk.CreateSkill {
  name = "s_koubian2",
}

Fk:loadTranslationTable{
  ["s_koubian2"] = "寇边",
  [":s_koubian2"] = "出牌阶段限一次，你可以令一名其他角色选择一项：1.令你随机获得其区域内的一张牌；2.本回合内下一次受到你的伤害+1。",

  ["#s_koubian2"] = "寇边：令一名其他角色选择",
  ["#s_koubian2-choice"] = "寇边：选择一项",
  ["s_koubian2_choice1"] = "令其随机获得你区域内的一张牌",
  ["s_koubian2_choice2"] = "本回合内下一次受到你的伤害+1",
}

s_koubian2:addEffect("active", {
  anim_type = "offensive",
  prompt = "#s_koubian2",
  max_phase_use_time = 1,
  target_num = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player and not to_select.dead
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    local choice = room:askToChoice(target, {
      choices = { "s_koubian2_choice1", "s_koubian2_choice2" },
      skill_name = s_koubian2.name,
      prompt = "#s_koubian2-choice",
      cancelable = false,
    })
    if choice == "s_koubian2_choice1" then
      -- 令你随机获得其区域内的一张牌
      local areaIds = {}
      for _, area in ipairs({ "h", "e", "j" }) do
        for _, id in ipairs(target:getCardIds(area)) do
          table.insert(areaIds, id)
        end
      end
      if #areaIds > 0 then
        local id = areaIds[math.random(#areaIds)]
        room:obtainCard(player, { id }, true, fk.ReasonPrey, nil, s_koubian2.name)
      end
    else
      -- 本回合内下一次受到你的伤害+1
      room:setPlayerMark(target, "@s_koubian2_dmg", 1)
    end
  end,
})

-- 标记伤害+1（一次性）
s_koubian2:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    return target:getMark("@s_koubian2_dmg") > 0
      and player:hasSkill(s_koubian2.name)
      and data.from == player
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data:changeDamage(1)
    player.room:setPlayerMark(target, "@s_koubian2_dmg", 0)
  end,
})

-- 回合结束时清除未触发的标记（本回合内）
s_koubian2:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, player, data)
    return target:getMark("@s_koubian2_dmg") > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(target, "@s_koubian2_dmg", 0)
  end,
})

-- 测试1：选项2 → 标记；下次受到你的伤害+1 后标记清零
s_koubian2:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_koubian2.name)
    comp2.hp = 4
    room.current = me
    me.phase = Player.Play
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(comp2, { "s_koubian2_choice2" })
    s_koubian2:onUse(room, { from = me, tos = { comp2 }, cards = {}, cost_data = {} })
    lu.assertEquals(comp2:getMark("@s_koubian2_dmg"), 1, "寇边：选项2应标记目标")
    local rd = room.logic:trigger(fk.DamageInflicted, comp2, { from = me, to = comp2, damage = 1 })
    lu.assertEquals(rd.damage, 2, "寇边：标记伤害应+1")
    lu.assertEquals(comp2:getMark("@s_koubian2_dmg"), 0, "寇边：伤害结算后标记应清零")
  end)
end)

-- 测试2：选项1 → 随机获得其区域内一张牌
s_koubian2:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_koubian2.name)
    local card = room:printCard("slash", Card.Spade, 1)
    room:moveCardTo(card, Player.Hand, comp2, fk.ReasonGive, "test")
    local before = #me:getCardIds("h")
    FkTest.setNextReplies(comp2, { "s_koubian2_choice1" })
    s_koubian2:onUse(room, { from = me, tos = { comp2 }, cards = {}, cost_data = {} })
    lu.assertEquals(#me:getCardIds("h"), before + 1, "寇边：选项1应随机获得目标区域内一张牌")
  end)
end)

return s_koubian2