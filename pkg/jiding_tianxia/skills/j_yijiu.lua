-- 计蒋济·义疚（锁定技）
-- 当一名角色阵亡时，若其成为过【劝降】的目标，你失去一点体力并摸三张牌；
-- 若其未成为过【劝降】的目标，你下个回合使用【劝降】的次数+1。
local j_yijiu = fk.CreateSkill {
  name = "j_yijiu",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_yijiu"] = "义疚",
  [":j_yijiu"] = "锁定技，当一名角色阵亡时，若其成为过【劝降】的目标，你失去一点体力并摸三张牌；若其未成为过【劝降】的目标，你下个回合使用【劝降】的次数+1。",
}

j_yijiu:addEffect(fk.Death, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_yijiu.name) or player.dead then return false end
    if not target or not target.dead then return false end
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if target:getMark("@@j_quanjiang_targeted") > 0 then
      -- 成为过劝降目标：失去一点体力并摸三张牌
      room:loseHp(player, 1, j_yijiu.name, player)
      if not player.dead then
        room:drawCards(player, 3, j_yijiu.name)
      end
    else
      -- 未成为过劝降目标：下个回合使用劝降的次数+1
      room:setPlayerMark(player, "j_yijiu_bonus", player:getMark("j_yijiu_bonus") + 1)
    end
  end,
})

-- 下个回合开始时，把“劝降”次数奖励转为本回合可用次数
j_yijiu:addEffect(fk.TurnStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_yijiu.name) and not player.dead
      and player:getMark("j_yijiu_bonus") > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_quanjiang_extra-turn", player:getMark("j_yijiu_bonus"))
    room:setPlayerMark(player, "j_yijiu_bonus", 0)
  end,
})

-- 测试：阵亡者成为过劝降目标 → 失去一点体力并摸三张牌
j_yijiu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yijiu.name)
    room:setPlayerMark(comp2, "@@j_quanjiang_targeted", 1)
  end)
  FkTest.runInRoom(function()
    local beforeHand = #me:getCardIds("h")
    local beforeHp = me.hp
    room.logic:trigger(fk.Death, comp2, { who = comp2 })
    lu.assertEquals(me.hp, beforeHp - 1, "应失去一点体力")
    lu.assertEquals(#me:getCardIds("h"), beforeHand + 3, "应摸三张牌")
  end)
end)

-- 测试：阵亡者未成为过劝降目标 → 下回合劝降次数+1
j_yijiu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yijiu.name)
    room:handleAddLoseSkills(me, j_quanjiang.name)
  end)
  FkTest.runInRoom(function()
    local beforeHp = me.hp
    room.logic:trigger(fk.Death, comp2, { who = comp2 })
    lu.assertEquals(me.hp, beforeHp, "不应失去体力")
    lu.assertEquals(me:getMark("j_yijiu_bonus"), 1, "应获得下回合劝降次数奖励")

    -- 下个回合开始：奖励转为可用次数
    room.logic:trigger(fk.TurnStart, me, {})
    lu.assertEquals(me:getMark("j_quanjiang_extra-turn"), 1, "本回合劝降次数应+1")
    lu.assertEquals(me:getMark("j_yijiu_bonus"), 0, "奖励应被消耗")
  end)
end)

return j_yijiu
