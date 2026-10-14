local j_daoge = fk.CreateSkill {
  name = "j_daoge",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_daoge"] = "倒戈",
  [":j_daoge"] = "锁定技，当你受到伤害时，伤害来源弃置你一张牌，然后你摸两张牌并修改势力与伤害来源相同并获得相应势力技能。你始终拥有群势力技能。",

  ["#j_daoge-discard"] = "倒戈：弃置其一张牌",
}

-- 当你受到伤害后（锁定技，无询问）
j_daoge:addEffect(fk.Damaged, {
  global = true,
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_daoge.name)
      and data.from and data.from:isAlive() and data.damage >= 1
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local src = data.from

    -- 伤害来源弃置你一张牌（由来源选择你区域内的牌）
    local cards = player:getCardIds("he")
    if #cards > 0 then
      local id = room:askToChooseCard(src, {
        target = player,
        flag = "he",
        skill_name = j_daoge.name,
        prompt = "#j_daoge-discard",
      })
      if id then
        room:throwCard(id, j_daoge.name, player, src)
      end
    end

    -- 然后你摸两张牌
    room:drawCards(player, 2, j_daoge.name)

    -- 修改势力与伤害来源相同（changeKingdom 会自动增减对应势力技）
    if src.kingdom and src.kingdom ~= player.kingdom then
      room:changeKingdom(player, src.kingdom, true)
    end
  end,
})

-- 测试：受到伤害后被来源弃1张、摸2张，势力变为与来源相同
j_daoge:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_daoge.name)
  end)

  FkTest.runInRoom(function()
    local c1 = room:printCard("slash")
    local c2 = room:printCard("peach")
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")

    FkTest.setNextReplies(comp2, { c2.id })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(#me:getCardIds("h"), 3, "倒戈：弃1张摸2张后应余3张")
    lu.assertEquals(me.kingdom, comp2.kingdom, "倒戈：势力应与伤害来源相同")
  end)
end)

-- 复现测试：别人的回合内受伤触发倒戈（改势力→势力技增删），轮到己方回合应能正常出牌
j_daoge:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    -- 变身宋宪&魏续（群势力），真实武将技能列表参与势力技增删
    room:setPlayerGeneral(me, "songxian_weixu", true)
    room:handleAddLoseSkills(me, "j_daoge|j_qishe|j_yuji|j_xianji|j_kuiwei|j_motu")
    -- comp2 保持默认势力
    lu.assertEquals(me.kingdom, "qun", "宋宪&魏续应为群势力")
  end)

  -- 模拟：别人的回合，别人对 me 造成 1 点伤害 → 倒戈触发（弃1摸2+改势力为来源势力）
  FkTest.runInRoom(function()
    local c1 = room:printCard("slash")
    local c2 = room:printCard("peach")
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    FkTest.setNextReplies(comp2, { c2.id })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me.kingdom, comp2.kingdom, "倒戈后势力应与伤害来源相同")
    -- 势力改变后自动增删势力技：吴匹配献戟；魏/蜀势力技被移除
    lu.assertIsTrue(me:hasSkill("j_xianji"), "改为吴势力后应自动获得献戟")
    lu.assertFalse(me:hasSkill("j_yuji"), "魏势力技余悸应随势力改变被移除")
    lu.assertFalse(me:hasSkill("j_kuiwei"), "蜀势力技溃围应随势力改变被移除")
  end)

  -- 轮到 me 的完整回合（开始→判定→摸牌→出牌）
  FkTest.runInRoom(function()
    local slash = room:printCard("slash")
    room:obtainCard(me, { slash }, true, fk.ReasonDraw, me, "test")
    GameEvent.Turn:create(TurnData:new(me, "game_rule", { Player.Start, Player.Judge, Player.Draw, Player.Play })):exec()

    -- 出牌阶段应能正常使用杀（未被卡死/牌未变灰）
    lu.assertIsTrue(me:canUse(slash), "倒戈改势力后轮到己方回合应能正常出牌")
    room:useCard{ from = me, tos = { comp2 }, card = slash }
    lu.assertNotIsNil(room:getCardArea(slash.id), "出牌阶段使用杀应正常结算")
  end)
end)

return j_daoge