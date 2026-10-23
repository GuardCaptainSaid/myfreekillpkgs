-- 计辛毗·审度
-- 回合开始时，你可以进行体力值次判定，然后令【抗辞】次数+x。（x为其中红色的数量）
local j_shendu = fk.CreateSkill {
  name = "j_shendu",
}

Fk:loadTranslationTable{
  ["j_shendu"] = "审度",
  [":j_shendu"] = "回合开始时，你可以进行体力值次判定，然后令【抗辞】次数+X（X为其中红色的数量）。",

  ["#j_shendu-invoke"] = "审度：是否进行体力值次判定，令【抗辞】次数+其中红色的数量？",
  ["#j_shendu-count"] = "审度：令【抗辞】次数+%arg",
}

j_shendu:addEffect(fk.TurnStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_shendu.name) and player.hp > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_shendu.name,
      prompt = "#j_shendu-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local red = 0
    for _ = 1, math.max(player.hp, 0) do
      if player.dead then break end
      local judge = {
        who = player,
        reason = j_shendu.name,
        pattern = ".",
      }
      room:judge(judge)
      local card = judge.card
      if card and card:getColorString() == "red" then
        red = red + 1
      end
    end
    if red > 0 and not player.dead then
      room:addPlayerMark(player, "j_kangci_count-turn", red)
      room:sendLog{
        type = "#j_shendu-count",
        from = player.id,
        arg = tostring(red),
      }
    end
  end,
})

-- 测试：审度判定 → 红色数量转为抗辞次数
j_shendu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shendu.name)
    room.current = me
    me.hp = 2
    -- 牌堆顶放两张红牌（判定必定红色）
    local r1 = room:printCard("slash", Card.Heart, 2)
    local r2 = room:printCard("jink", Card.Diamond, 3)
    room:moveCards{ ids = { r2.id, r1.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut }
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return true end
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToSkillInvoke = origInvoke
    lu.assertEquals(me:getMark("j_kangci_count-turn"), 2, "两张红色判定 → 抗辞次数+2")
  end)
end)

return j_shendu
