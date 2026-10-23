-- 计杨阜·忘股
-- 当你受到伤害后，若伤害来源体力值和手牌数均大于你，你可以令其弃置任意张点数和≥13的牌，
-- 否则你摸X张牌。（X为13-其弃置牌点数之和）
local j_wanggu = fk.CreateSkill {
  name = "j_wanggu",
}

Fk:loadTranslationTable{
  ["j_wanggu"] = "忘股",
  [":j_wanggu"] = "当你受到伤害后，若伤害来源体力值和手牌数均大于你，你可以令其弃置任意张点数和≥13的牌，否则你摸X张牌（X为13-其弃置牌点数之和）。",

  ["#j_wanggu-invoke"] = "忘股：是否令伤害来源弃置点数和≥13的牌？（否则你摸差额张牌）",
  ["#j_wanggu-discard"] = "忘股：请弃置任意张点数和≥13的牌，否则杨阜摸差额张牌",
}

j_wanggu:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(j_wanggu.name) then return false end
    local from = data and data.from
    if not from or from.dead or from == player then return false end
    return from.hp > player.hp and #from:getCardIds("h") > #player:getCardIds("h")
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_wanggu.name,
      prompt = "#j_wanggu-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if not from or from.dead then return end
    local ids = room:askToDiscard(from, {
      min_num = 0,
      max_num = #from:getCardIds("h"),
      skill_name = j_wanggu.name,
      prompt = "#j_wanggu-discard",
      cancelable = true,
    })
    local sum = 0
    for _, id in ipairs(ids or {}) do
      sum = sum + (Fk:getCardById(id).number or 0)
    end
    local x = 13 - sum
    if x > 0 and not player.dead then
      room:drawCards(player, x, j_wanggu.name)
    end
  end,
})

-- 测试：来源体力与手牌均大于你且未弃牌 → 杨阜摸13张
j_wanggu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_wanggu.name)
    me.hp = 2
    comp2.hp = 4
    local c1 = room:printCard("slash", Card.Spade, 7)
    local c2 = room:printCard("jink", Card.Heart, 8)
    room:obtainCard(comp2, { c1, c2 }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origDiscard = room.askToDiscard
    room.askToSkillInvoke = function(self, who, params)
      if who == me then return true end
      return origInvoke(self, who, params)
    end
    room.askToDiscard = function(self, who, params)
      if who == comp2 then return {} end -- 什么都不弃
      return origDiscard(self, who, params)
    end
    local before = #me:getCardIds("h")
    room.logic:trigger(fk.Damaged, me, { from = comp2, to = me, damage = 1 })
    room.askToSkillInvoke = origInvoke
    room.askToDiscard = origDiscard
    lu.assertEquals(#me:getCardIds("h"), before + 13, "来源未弃牌应摸13张")
  end)
end)

return j_wanggu
