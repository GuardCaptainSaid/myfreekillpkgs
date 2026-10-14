-- 君曹操·定业
-- 限定技，当你进入濒死状态时，你可令所有其他角色依次选择是否交给你一张牌。若你因此共获得牌的数量不小于游戏开始时角色数的一半，则你回复至3点体力，且本局游戏中“奉天”改为将手牌当作普通锦囊牌使用；否则你减1点体力上限，然后回复1点体力。
local j_dingye = fk.CreateSkill {
  name = "j_dingye",
}

Fk:loadTranslationTable{
  ["j_dingye"] = "定业",
  [":j_dingye"] = "限定技，当你进入濒死状态时，你可令所有其他角色依次选择是否交给你一张牌。若你因此共获得牌的数量不小于游戏开始时角色数的一半，则你回复至3点体力，且本局游戏中“奉天”改为将手牌当作普通锦囊牌使用；否则你减1点体力上限，然后回复1点体力。",

  ["#j_dingye-invoke"] = "定业：是否令所有其他角色依次选择交给你一张牌？",
  ["#j_dingye-give"] = "定业：是否交给君曹操一张牌？",

  ["$j_dingye1"] = "汉室倾颓，朕当定此基业！",
  ["$j_dingye2"] = "此业既定，天下归一！",
}

-- 游戏开始时记录角色数
j_dingye:addEffect(fk.GameStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_dingye.name, true)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@j_dingye_players", #player.room.alive_players)
  end,
})

-- 濒死时发动
j_dingye:addEffect(fk.EnterDying, {
  anim_type = "rescue",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_dingye.name) or player.dead then return false end
    if player:getMark("@j_dingye_used") > 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_dingye.name, prompt = "#j_dingye-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "@j_dingye_used", 1)
    local gained = 0
    for _, p in ipairs(room:getOtherPlayers(player)) do
      if not p.dead and not p:isAllNude() then
        local c = room:askToChooseCards(p, {
          target = p,
          flag = "hej",
          min = 0,
          max = 1,
          cancelable = true,
          pattern = ".",
          skill_name = j_dingye.name,
          prompt = "#j_dingye-give",
        })
        if c and #c > 0 then
          room:obtainCard(player, c, true, fk.ReasonGive, p, j_dingye.name)
          gained = gained + 1
        end
      end
    end
    local initial = math.max(player:getMark("@j_dingye_players"), 1)
    local need = math.ceil(initial / 2)
    if gained >= need then
      -- 回复至3点体力，且奉天改为转化普通锦囊牌
      if player.hp < 3 then
        room:recover{ who = player, num = 3 - player.hp, recoverBy = player, skillName = j_dingye.name }
      end
      room:setPlayerMark(player, "@j_fengtian_enhanced", 1)
    else
      -- 减1点体力上限，然后回复1点体力
      room:changeMaxHp(player, -1)
      if player.hp < player.maxHp then
        room:recover{ who = player, num = 1, recoverBy = player, skillName = j_dingye.name }
      end
    end
  end,
})

-- 测试：交牌达到一半 → 回复至3且奉天强化
j_dingye:addTest(function(room, me)
  local comp2, comp3, comp4 = room.players[2], room.players[3], room.players[4]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_dingye.name)
    me.maxHp = 4
    me.hp = 4
    room:setPlayerMark(me, "@j_dingye_players", #room.alive_players)
    room:setPlayerMark(me, "@j_dingye_used", 0)
    -- 三名角色各有一张牌可交（8人场一半=4，需至少4人交牌；再造2张给 comp5/6）
    for i = 2, math.min(6, #room.players) do
      local p = room.players[i]
      local c = room:printCard("slash", Card.Spade, i)
      room:obtainCard(p, { c }, true, fk.ReasonDraw, p, "test")
    end
  end)

  FkTest.runInRoom(function()
    me.hp = 1
    local before = me.hp
    -- 回复序列：前4名角色各交一张（给 me），其余取消
    local replies = {}
    for i = 2, math.min(6, #room.players) do
      local p = room.players[i]
      local hand = p:getCardIds("h")
      if i <= 5 then
        table.insert(replies, { hand[1] })
      else
        table.insert(replies, {})
      end
    end
    FkTest.setNextReplies(me, { "1" })
    -- 注意：askToChooseCards 的询问对象是各角色 p，回复表按询问顺序对应
    -- 直接按全局回复：第一项是定业询问（me 答 1），其后依次为各角色交牌回复
    local globalReplies = { "1" }
    for i = 2, math.min(6, #room.players) do
      local p = room.players[i]
      local hand = p:getCardIds("h")
      if i <= 5 then
        table.insert(globalReplies, { hand[1] })
      else
        table.insert(globalReplies, {})
      end
    end
    FkTest.setNextReplies(me, globalReplies)
    room.logic:trigger(fk.EnterDying, me, {})
    lu.assertEquals(me.hp, 3, "定业：应回复至3点体力")
    lu.assertEquals(me:getMark("@j_fengtian_enhanced"), 1, "定业：奉天应强化为转化锦囊")
    lu.assertEquals(me:getMark("@j_dingye_used"), 1, "定业：限定技应已发动")
  end)
end)

-- 测试：交牌不足一半 → 减1体力上限并回复1点
j_dingye:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_dingye.name)
    me.maxHp = 4
    me.hp = 4
    room:setPlayerMark(me, "@j_dingye_players", #room.alive_players)
    room:setPlayerMark(me, "@j_dingye_used", 0)
    -- 所有其他角色都不交牌（无牌）
    for i = 2, #room.players do
      local p = room.players[i]
      room:moveCards{ ids = p:getCardIds("hej"), toArea = Card.DiscardPile, moveReason = fk.ReasonPut }
    end
  end)

  FkTest.runInRoom(function()
    me.hp = 1
    local maxBefore = me.maxHp
    FkTest.setNextReplies(me, { "1" })
    room.logic:trigger(fk.EnterDying, me, {})
    lu.assertEquals(me.maxHp, maxBefore - 1, "定业：应减1点体力上限")
    lu.assertEquals(me.hp, 2, "定业：应回复1点体力（hp=1+1）")
    lu.assertEquals(me:getMark("@j_fengtian_enhanced"), 0, "定业：交牌不足不应强化奉天")
  end)
end)

return j_dingye