local j_weiji = fk.CreateSkill {
  name = "j_weiji",
}

Fk:loadTranslationTable{
  ["j_weiji"] = "伪计",
  [":j_weiji"] = "出牌阶段，你可以弃置一张手牌，将你装备区里的任意一张牌当作【杀】使用。",

  ["#j_weiji"] = "伪计：弃置一张手牌，将装备区里的一张牌当作【杀】使用",

  ["$j_weiji1"] = "伪作病笃，以慢其心。",
  ["$j_weiji2"] = "示之以虚，击之以实。",
}

-- 转化技：先选手牌，再选装备区的牌，二者作为【杀】的子牌（手牌即被弃置）
j_weiji:addEffect("viewas", {
  anim_type = "offensive",
  pattern = "slash",
  prompt = "#j_weiji",
  -- 必须展开装备区：客户端 ReqActiveSkill.expandPiles 仅当 include_equip 为真、
  -- 或装备牌在首轮选牌即可点亮时才会展开装备区；本技能首轮只允许选手牌，
  -- 缺少此字段会导致装备区永不展开、选不满两张牌，表现为“伪计无法使用”
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    if #selected == 0 then
      return table.contains(player:getCardIds("h"), to_select)
    elseif #selected == 1 then
      return table.contains(player:getCardIds("e"), to_select)
    end
    return false
  end,
  view_as = function(self, player, cards)
    if #cards ~= 2 then return end
    local card = Fk:cloneCard("slash")
    card.skillName = j_weiji.name
    card:addSubcards(cards)
    return card
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0 and #player:getCardIds("e") > 0
  end,
})

-- 测试：伪计选牌顺序（先手牌、后装备区牌）与转化结果
j_weiji:addTest(function(room, me)
  local handId, equipId
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_weiji.name)
    me.phase = Player.Play
    local hand = room:printCard("slash", Card.Spade, 7)
    local equip = room:printCard("guding_blade", Card.Spade, 2)
    room:obtainCard(me, { hand.id }, true, fk.ReasonDraw, me, "test")
    room:useCard{ from = me, tos = { me }, card = equip }
    handId = hand.id
    equipId = equip.id
    lu.assertEquals(#me:getCardIds("h"), 1, "前置：应有一张手牌")
    lu.assertEquals(#me:getCardIds("e"), 1, "前置：应有一张装备区牌")
  end)

  FkTest.runInRoom(function()
    local skel = Fk.skills[j_weiji.name]:getSkeleton()
    local eff = skel.effects[1]
    lu.assertEquals(eff:cardFilter(me, handId, {}), true, "第一轮应可选手牌")
    lu.assertEquals(eff:cardFilter(me, equipId, {}), false, "第一轮不应可选装备区牌")
    lu.assertEquals(eff:cardFilter(me, equipId, { handId }), true, "第二轮应可选装备区牌")
    lu.assertEquals(eff:enabledAtPlay(me), true, "出牌阶段且手牌/装备均非空时按钮应可用")
    local vc = eff:viewAs(me, { handId, equipId })
    lu.assertNotNil(vc, "两张子牌应能转化为虚拟牌")
    lu.assertEquals(vc.name, "slash", "应转化为【杀】")
    lu.assertEquals(#vc.subcards, 2, "虚拟杀应携带两张子牌")
    lu.assertEquals(vc.skillName, j_weiji.name, "虚拟杀应归属伪计")
  end)
end)

return j_weiji
