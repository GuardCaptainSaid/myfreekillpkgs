-- 舒邵三号·争刑
-- 当一名其他角色即将受到可令其进入濒死的伤害时，你可与其拼点：
-- 若你赢，则此伤害由你承担；若相等，你与其各摸1张牌并再次拼点，
-- 若仍相等，则你与其本回合免疫所有伤害；若你输，其摸2张牌。
local s_zhengxing = fk.CreateSkill {
  name = "s_zhengxing",
}

Fk:loadTranslationTable{
  ["s_zhengxing"] = "争刑",
  [":s_zhengxing"] = "当一名其他角色即将受到可令其进入濒死的伤害时，你可与其拼点，若你赢，则此伤害由你承担；若相等，你与其各摸1张牌并再次拼点，若仍相等，则你与其本回合免疫所有伤害；若你输，其摸2张牌。",

  ["#s_zhengxing-invoke"] = "争刑：%src 即将受到致命伤害，是否与其拼点？",
  ["#s_zhengxing-immune_log"] = "争刑：%arg 与 %arg2 本回合免疫所有伤害",

  ["$s_zhengxing1"] = "刑争一线，胜负由天！",
  ["$s_zhengxing2"] = "此刑我担，何惧之有！",
}

-- 致命伤害时：拼点转移/免疫/摸牌
s_zhengxing:addEffect(fk.DamageInflicted, {
  anim_type = "defensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_zhengxing.name) then return false end
    if not target or target == player or target.dead then return false end
    if not data or data.damage < 1 then return false end
    -- 可令其进入濒死：伤害不小于其当前体力
    return data.damage >= target.hp
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = s_zhengxing.name,
      prompt = "#s_zhengxing-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 第一次拼点
    local pd = player:pindian({ target }, s_zhengxing.name)
    local res = pd.results[target]
    if not res then return end
    if res.winner == player then
      -- 你赢：伤害由你承担
      data.to = player
      return
    elseif res.winner == target then
      -- 你输：其摸2张牌
      target:drawCards(2, s_zhengxing.name)
      return
    end
    -- 相等：各摸1张牌并再次拼点
    player:drawCards(1, s_zhengxing.name)
    target:drawCards(1, s_zhengxing.name)
    local pd2 = player:pindian({ target }, s_zhengxing.name)
    local res2 = pd2.results[target]
    if not res2 then return end
    if res2.winner == player then
      data.to = player
    elseif res2.winner == target then
      target:drawCards(2, s_zhengxing.name)
    else
      -- 仍相等：双方本回合免疫所有伤害（含当前伤害）
      room:setPlayerMark(player, "@s_zhengxing_immune", 1)
      room:setPlayerMark(target, "@s_zhengxing_immune", 1)
      room:sendLog{ type = "#s_zhengxing-immune_log", from = player.id, arg = player.id, arg2 = target.id }
      data.damage = 0
    end
  end,
})

-- 本回合免疫所有伤害
s_zhengxing:addEffect(fk.DamageInflicted, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target and not target.dead and target:getMark("@s_zhengxing_immune") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data.damage = 0
  end,
})

-- 回合结束时清除免疫标记
s_zhengxing:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(s_zhengxing.name)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room.alive_players) do
      if p:getMark("@s_zhengxing_immune") > 0 then
        room:setPlayerMark(p, "@s_zhengxing_immune", 0)
      end
    end
  end,
})

-- 测试：致命伤害拼点赢 → 伤害转移给舒邵
s_zhengxing:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  local myBig, tgtSmall
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_zhengxing.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 1
    comp3.maxHp = 3
    comp3.hp = 3
    -- 舒邵点数大，目标点数小
    myBig = room:printCard("slash", Card.Spade, 13)
    tgtSmall = room:printCard("slash", Card.Heart, 2)
    room:obtainCard(me, { myBig }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { tgtSmall }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    -- askToSkillInvoke "1"；拼点回复用 ReplyChooseCards（choose_cards_skill 格式）
    FkTest.setNextReplies(me, { "1", FkTest.ReplyChooseCards({ myBig.id }) })
    FkTest.setNextReplies(comp2, { FkTest.ReplyChooseCards({ tgtSmall.id }) })
    local dmg = DamageData:new{ from = comp3, to = comp2, damage = 2, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, comp2, dmg)
    assert(dmg.to == me, "争刑：赢时应将伤害转移给舒邵")
  end)
end)

-- 测试：致命伤害拼点输 → 其摸2张牌
s_zhengxing:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  local mySmall, tgtBig
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_zhengxing.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 1
    comp3.maxHp = 3
    comp3.hp = 3
    mySmall = room:printCard("slash", Card.Spade, 2)
    tgtBig = room:printCard("slash", Card.Heart, 13)
    room:obtainCard(me, { mySmall }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { tgtBig }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1", FkTest.ReplyChooseCards({ mySmall.id }) })
    FkTest.setNextReplies(comp2, { FkTest.ReplyChooseCards({ tgtBig.id }) })
    local hBefore = #comp2:getCardIds("h")
    local dmg = DamageData:new{ from = comp3, to = comp2, damage = 2, damageType = fk.NormalDamage }
    room.logic:trigger(fk.DamageInflicted, comp2, dmg)
    assert(dmg.to == comp2, "争刑：输时伤害不转移")
    -- 拼点牌-1，其摸2张 → 手牌净增1
    assert(#comp2:getCardIds("h") == hBefore + 1, "争刑：输时其应净增1张牌（拼点牌消耗1、摸2）")
  end)
end)

return s_zhengxing