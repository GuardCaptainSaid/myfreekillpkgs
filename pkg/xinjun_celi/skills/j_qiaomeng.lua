-- 君公孙瓒·趫猛（破阵附属技能）
-- 当你使用【杀】对一名角色造成伤害后，你可弃置其区域里的一张牌。若此牌为坐骑牌，你获得之。
local j_qiaomeng = fk.CreateSkill {
  name = "j_qiaomeng",
}

Fk:loadTranslationTable{
  ["j_qiaomeng"] = "趫猛",
  [":j_qiaomeng"] = "当你使用【杀】对一名角色造成伤害后，你可弃置其区域里的一张牌。若此牌为坐骑牌，你获得之。",

  ["#j_qiaomeng-invoke"] = "趫猛：是否弃置其区域里的一张牌？",
  ["#j_qiaomeng-discard"] = "趫猛：选择其区域内一张牌弃置",

  ["$j_qiaomeng1"] = "乘胜逐北，夺其坐骑！",
  ["$j_qiaomeng2"] = "轻骑突袭，直取其器！",
}

j_qiaomeng:addEffect(fk.DamageFinished, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if data.from ~= player then return false end
    if not player:hasSkill(j_qiaomeng.name) or player.dead then return false end
    if not data.card or data.card.trueName ~= "slash" then return false end
    if not target or target.dead or target:isAllNude() then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_qiaomeng.name, prompt = "#j_qiaomeng-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local c = room:askToChooseCards(player, {
      target = target,
      flag = "hej",
      min = 1,
      max = 1,
      cancelable = false,
      pattern = ".",
      skill_name = j_qiaomeng.name,
      prompt = "#j_qiaomeng-discard",
    })
    if not c or #c == 0 then return end
    local id = c[1]
    local card = Fk:getCardById(id)
    -- 若为坐骑牌则获得之，否则弃置
    if card.sub_type == Card.SubtypeOffensiveRide or card.sub_type == Card.SubtypeDefensiveRide then
      room:obtainCard(player, { id }, true, fk.ReasonGive, target, j_qiaomeng.name)
    else
      room:throwCard({ id }, j_qiaomeng.name, target, target)
    end
  end,
})

-- 测试：杀伤害后弃其牌；坐骑牌则获得
j_qiaomeng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qiaomeng.name)
    me.maxHp = 4
    me.hp = 4
    -- comp2 一张手牌（普通牌）
    local h1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(comp2, { h1 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    local slash = room:printCard("slash", Card.Club, 6)
    FkTest.setNextReplies(me, { "1", { comp2:getCardIds("h")[1] } })
    room:damage{ from = me, to = comp2, damage = 1, damageType = fk.NormalDamage, card = slash }
    lu.assertEquals(#comp2:getCardIds("h"), 0, "趫猛：应弃置其一张牌")
  end)
end)

-- 测试：坐骑牌获得
j_qiaomeng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qiaomeng.name)
    me.maxHp = 4
    me.hp = 4
    -- comp2 装备一匹+1马（坐骑）
    local horse = room:printCard("hualiu", Card.Diamond, 8)
    room:moveCardTo(horse, Player.Equip, comp2, fk.ReasonPut, j_qiaomeng.name)
  end)

  FkTest.runInRoom(function()
    local slash = room:printCard("slash", Card.Club, 6)
    local horseId = comp2:getCardIds("e")[1]
    FkTest.setNextReplies(me, { "1", { horseId } })
    room:damage{ from = me, to = comp2, damage = 1, damageType = fk.NormalDamage, card = slash }
    lu.assertEquals(#comp2:getCardIds("e"), 0, "趫猛：坐骑应离开其装备区")
    lu.assertTrue(table.contains(me:getCardIds("h"), horseId), "趫猛：坐骑牌应获得")
  end)
end)

return j_qiaomeng