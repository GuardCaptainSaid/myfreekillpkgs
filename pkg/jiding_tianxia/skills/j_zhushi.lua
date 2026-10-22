-- 计刘晔·烛势
-- 出牌阶段每种花色限1次，你可以重铸任意张相同花色的牌，且本轮攻击范围增加x(x为你重铸牌数)。
local j_zhushi = fk.CreateSkill {
  name = "j_zhushi",
}

Fk:loadTranslationTable{
  ["j_zhushi"] = "烛势",
  [":j_zhushi"] = "出牌阶段每种花色限1次，你可以重铸任意张相同花色的牌，且本轮攻击范围增加x（x为你重铸的牌数）。",

  ["#j_zhushi"] = "烛势：重铸任意张相同花色的牌（每种花色限一次）",

  ["@j_zhushi_range"] = "攻击范围",
}

j_zhushi:addEffect("active", {
  anim_type = "offensive",
  prompt = "#j_zhushi",
  min_card_num = 1,
  max_card_num = function(self, player)
    return #player:getCardIds("h")
  end,
  target_num = 0,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    -- 手牌中需存在未使用过花色的牌
    for _, id in ipairs(player:getCardIds("h")) do
      if not table.contains(player:getTableMark("j_zhushi_used-turn"), Fk:getCardById(id):getSuitString()) then
        return true
      end
    end
    return false
  end,
  card_filter = function(self, player, to_select, selected)
    local suit = Fk:getCardById(to_select):getSuitString()
    -- 该花色本出牌阶段未用过
    if table.contains(player:getTableMark("j_zhushi_used-turn"), suit) then return false end
    -- 必须与已选牌同花色
    if #selected == 0 then return true end
    return Fk:getCardById(selected[1]):getSuitString() == suit
  end,
  -- 注意：feasible 参数顺序为 (player, selected_targets, selected_cards)
  feasible = function(self, player, selected_targets, selected_cards)
    return #selected_cards > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local ids = effect.cards
    if not ids or #ids == 0 then return end
    local suit = Fk:getCardById(ids[1]):getSuitString()
    room:recastCard(ids, player, j_zhushi.name)
    local used = player:getTableMark("j_zhushi_used-turn")
    table.insertIfNeed(used, suit)
    room:setPlayerMark(player, "j_zhushi_used-turn", used)
    -- 本轮攻击范围增加 x（破橹会在 SkillEffect 时机检测攻击范围变化）
    room:setPlayerMark(player, "j_zhushi_range-round", player:getMark("j_zhushi_range-round") + #ids)
    -- 在武将牌上显示当前攻击范围
    room:setPlayerMark(player, "@j_zhushi_range", player:getAttackRange())
  end,
})

-- 本轮攻击范围增加 x
j_zhushi:addEffect("atkrange", {
  correct_func = function(self, player)
    return player:getMark("j_zhushi_range-round")
  end,
})

-- 测试：重铸两张黑桃牌 → 记录花色 + 攻击范围 +2
j_zhushi:addTest(function(room, me)
  local s1, s2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhushi.name)
    s1 = room:printCard("slash", Card.Spade, 7)
    s2 = room:printCard("jink", Card.Spade, 8)
    room:obtainCard(me, { s1, s2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local skel = Fk.skills[j_zhushi.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")

    local origRecast = room.recastCard
    local recastIds = nil
    room.recastCard = function(self, ids, who, skill)
      recastIds = ids
    end
    spec:on_use(room, { from = me, cards = { s1.id, s2.id } })
    room.recastCard = origRecast

    lu.assertNotNil(recastIds, "应调用重铸")
    lu.assertTrue(table.contains(me:getTableMark("j_zhushi_used-turn"), "spade"), "应记录黑桃已用")
    lu.assertEquals(me:getMark("j_zhushi_range-round"), 2, "攻击范围标记应增加2")
    lu.assertEquals(me:getAttackRange(), 3, "实际攻击范围应为1+2=3")
    lu.assertEquals(me:getMark("@j_zhushi_range"), 3, "武将牌应显示当前攻击范围")
  end)
end)

return j_zhushi
