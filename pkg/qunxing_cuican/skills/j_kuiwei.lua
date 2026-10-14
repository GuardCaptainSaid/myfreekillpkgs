local j_kuiwei = fk.CreateSkill {
  name = "j_kuiwei",
  tags = { Skill.AttachedKingdom },
  attached_kingdom = { "shu" },
}

Fk:loadTranslationTable{
  ["j_kuiwei"] = "溃围",
  [":j_kuiwei"] = "蜀势力技，当你造成伤害时，你将手牌摸至体力上限。",
}

-- 当你造成伤害时（来源时机），摸牌至体力上限
j_kuiwei:addEffect(fk.Damage, {
  global = true,
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return data.from == player and player:hasSkill(j_kuiwei.name)
      and data.damage >= 1 and #player:getCardIds("h") < player.maxHp
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local n = player.maxHp - #player:getCardIds("h")
    if n > 0 then
      player.room:drawCards(player, n, j_kuiwei.name)
    end
  end,
})

-- 测试：造成伤害后摸牌至体力上限
j_kuiwei:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_kuiwei.name)
  end)

  FkTest.runInRoom(function()
    local c1 = room:printCard("peach")
    local c2 = room:printCard("peach")
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")

    room:damage{ from = me, to = comp2, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(#me:getCardIds("h"), me.maxHp, "溃围：造成伤害后应摸牌至体力上限")
  end)
end)

return j_kuiwei