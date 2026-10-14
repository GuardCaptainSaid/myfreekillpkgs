-- 超人强二号 · 健体（s_jianti）
-- 锁定技，你的攻击范围及使用【杀】的次数+X（X为你使用牌被抵消次数且最多为你的体力上限）。
local s_jianti = fk.CreateSkill {
  name = "s_jianti",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable {
  ["s_jianti"] = "健体",
  [":s_jianti"] = "锁定技，你的攻击范围及使用【杀】的次数+X（X为你使用牌被抵消次数且最多为你的体力上限）。",
  ["$s_jianti1"] = "体魄强健，百折不挠！",
  ["$s_jianti2"] = "越挫越勇，越战越强！",
}

local function getX(player)
  return math.min(player:getMark("@@s_jianti_count"), player.maxHp)
end

-- 攻击范围 +X
s_jianti:addEffect("atkrange", {
  correct_func = function(self, player)
    if not player:hasSkill(s_jianti.name) then return 0 end
    return getX(player)
  end,
})

-- 使用【杀】的次数 +X（出牌阶段）
s_jianti:addEffect("targetmod", {
  residue_func = function(self, player, scope, card)
    if not player:hasSkill(s_jianti.name) then return 0 end
    if scope ~= Player.HistoryPhase then return 0 end
    if card and card.trueName ~= "slash" then return 0 end
    return getX(player)
  end,
})

-- 你使用的牌被抵消时，计数 +1
s_jianti:addEffect(fk.CardEffectCancelledOut, {
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_jianti.name) then return false end
    -- target 为被抵消牌的使用者
    if target ~= player then return false end
    return data ~= nil and data.card ~= nil
  end,
  on_use = function(self, event, target, player, data)
    player.room:addPlayerMark(player, "@@s_jianti_count")
  end,
})

-- 测试：使用牌被抵消后计数+1，攻击范围与杀次数上限随X提升
s_jianti:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_jianti.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    local sl = room:printCard("slash", Card.Spade, 3)
    local jink = room:printCard("jink", Card.Heart, 8)
    room:obtainCard(me, { sl }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { jink }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local slashId = me:getCardIds("h")[1]
    local jink = Fk:getCardById(comp2:getCardIds("h")[1])
    FkTest.setNextReplies(comp2, { FkTest.ReplyCard(jink) })
    room:useCard{ from = me, tos = { comp2 }, card = Fk:getCardById(slashId) }
    lu.assertEquals(me:getMark("@@s_jianti_count"), 1, "健体：杀被抵消应计数+1")
    lu.assertEquals(me:getAttackRange(), 2, "健体：攻击范围应+X（基础1+X1=2）")
    -- X 不超过体力上限
    room:setPlayerMark(me, "@@s_jianti_count", 99)
    lu.assertEquals(me:getAttackRange(), 1 + me.maxHp, "健体：X最多为体力上限")
  end)
end)

return s_jianti