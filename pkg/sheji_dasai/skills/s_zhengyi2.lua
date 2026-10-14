-- 舒邵五号·争义
-- 当一名角色受到伤害时，你可失去一点体力，并防止该伤害，然后你摸等同于你体力值张牌。
local s_zhengyi2 = fk.CreateSkill {
  name = "s_zhengyi2",
}

Fk:loadTranslationTable{
  ["s_zhengyi2"] = "争义",
  [":s_zhengyi2"] = "当一名角色受到伤害时，你可失去一点体力，并防止该伤害，然后你摸等同于你体力值张牌。",

  ["#s_zhengyi2-invoke"] = "争义：是否失去1点体力防止此伤害，然后摸体力值张牌？",

  ["$s_zhengyi1"] = "义之所向，虽损何妨！",
  ["$s_zhengyi2"] = "以吾之躯，承彼之伤！",
}

-- 任意角色受到伤害时：可失1体防伤害，摸体力值张牌
s_zhengyi2:addEffect(fk.DamageInflicted, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_zhengyi2.name) then return false end
    if data.damage <= 0 then return false end
    -- 需有体力可失
    return player.hp > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = s_zhengyi2.name, prompt = "#s_zhengyi2-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:loseHp(player, 1, s_zhengyi2.name)
    data.damage = 0
    if not player.dead then
      player:drawCards(player.hp, s_zhengyi2.name)
    end
  end,
})

-- 测试1：自己受伤害时发动，防伤害、失1体、摸体力值张
s_zhengyi2:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_zhengyi2.name)
    me.maxHp = 4
    me.hp = 4
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    local handBefore = #me:getCardIds("h")
    local dmg = DamageData:new{ from = me, to = me, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, me, dmg)
    lu.assertEquals(dmg.damage, 0, "争义：应防止伤害")
    lu.assertEquals(me.hp, 3, "争义：应失去1点体力")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 3, "争义：应摸体力值（3）张牌")
  end)
end)

-- 测试2：其他角色受伤害时也可发动，防伤害、失1体、摸体力值张
s_zhengyi2:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_zhengyi2.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 3
    comp2.hp = 3
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    local handBefore = #me:getCardIds("h")
    local dmg = DamageData:new{ from = comp2, to = comp2, damage = 2, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, comp2, dmg)
    lu.assertEquals(dmg.damage, 0, "争义：应防止伤害")
    lu.assertEquals(me.hp, 3, "争义：应失去1点体力")
    lu.assertEquals(#me:getCardIds("h"), handBefore + 3, "争义：应摸体力值（3）张牌")
  end)
end)

return s_zhengyi2