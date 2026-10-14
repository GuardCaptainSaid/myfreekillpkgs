local j_junmou = fk.CreateSkill {
  name = "j_junmou",
}

Fk:loadTranslationTable{
  ["j_junmou"] = "峻谋",
  [":j_junmou"] = "当你受到伤害时，你可以选择任意名角色，这些角色将手牌数调整至你的体力值，然后因此技能失去牌的角色依次视为对一名因此技能获得牌的角色使用一张无距离限制的【杀】。",

  ["#j_junmou-invoke"] = "峻谋：是否发动？",
  ["#j_junmou-target"] = "峻谋：选择任意名角色",
  ["#j_junmou-slash"] = "峻谋：选择一名获得牌的角色，视为对其使用一张【杀】",

  ["$j_junmou1"] = "明于治乱，密于存亡！",
  ["$j_junmou2"] = "运筹帷幄，决胜千里！",
}

j_junmou:addEffect(fk.Damaged, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_junmou.name) and data.damage >= 1
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_junmou.name, prompt = "#j_junmou-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local hp = player.hp

    -- 选择任意名手牌数不等于自身体力值的角色
    local candidates = {}
    for _, p in ipairs(room.alive_players) do
      if #p:getCardIds("h") ~= hp then
        table.insert(candidates, p)
      end
    end
    local chosen = room:askToChoosePlayers(player, {
      targets = candidates,
      min_num = 0,
      max_num = #candidates,
      skill_name = j_junmou.name,
      prompt = "#j_junmou-target",
    })
    if not chosen or #chosen == 0 then return end

    -- 调整手牌数至体力值
    local losers, winners = {}, {}
    for _, p in ipairs(chosen) do
      local hand = #p:getCardIds("h")
      if hand > hp then
        local ids = p:getCardIds("h")
        local to_discard = {}
        for i = hp + 1, hand do
          to_discard[#to_discard + 1] = ids[i]
        end
        room:throwCard(to_discard, j_junmou.name, p, p)
        table.insert(losers, p)
      elseif hand < hp then
        room:drawCards(p, hp - hand, j_junmou.name)
        table.insert(winners, p)
      end
    end

    -- 失去牌的角色按座位顺序依次对一名获得牌的角色视为使用无距离限制的【杀】
    if #losers > 0 and #winners > 0 then
      local ordered = {}
      for _, p in ipairs(room.alive_players) do
        if table.contains(losers, p) then
          table.insert(ordered, p)
        end
      end
      for _, loser in ipairs(ordered) do
        if loser:isAlive() then
          local target = room:askToChoosePlayers(loser, {
            targets = winners,
            min_num = 1,
            max_num = 1,
            skill_name = j_junmou.name,
            prompt = "#j_junmou-slash",
          })
          if target and #target > 0 then
            local slash = Fk:cloneCard("slash")
            slash.skillName = j_junmou.name
            room:useCard{
              from = loser,
              card = slash,
              tos = { target[1] },
              extra_data = { bypass_distances = true },
            }
          end
        end
      end
    end
  end,
})

-- 测试：峻谋受伤害后调整手牌并视为使用无距离杀
j_junmou:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_junmou.name)
  end)

  FkTest.runInRoom(function()
    -- me 当前 3 体力；给 comp2 发 5 张手牌、comp3 0 张
    local cards = {}
    for i = 1, 5 do
      cards[i] = room:printCard("slash", Card.Spade, i)
    end
    room:obtainCard(comp2, cards, true, fk.ReasonDraw, comp2, "test")

    -- 触发伤害：comp2 打 me 1 点
    FkTest.setNextReplies(me, { "1", FkTest.ReplyChoosePlayer({ comp2, comp3 }) })
    FkTest.setNextReplies(comp2, { FkTest.ReplyChoosePlayer({ comp3 }) })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }

    -- me（测试房曹操 4 血）受 1 伤后体力 3 → comp2 弃到 3 张、comp3 摸到 3 张
    lu.assertEquals(me.hp, 3, "me 应受 1 点伤害")
    lu.assertEquals(#comp2:getCardIds("h"), 3, "comp2 手牌应弃至 me 体力值")
    lu.assertEquals(#comp3:getCardIds("h"), 3, "comp3 手牌应摸至 me 体力值")
    -- comp2（失去牌者）对 comp3（获得牌者）视为使用杀 → comp3 未响应受伤
    lu.assertEquals(comp3.hp, 3, "comp3 应受到视为使用的杀造成的一点伤害")
  end)
end)

-- 测试：不发动峻谋时无任何效果
j_junmou:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_junmou.name)
    local cards = {}
    for i = 1, 4 do
      cards[i] = room:printCard("slash", Card.Club, i)
    end
    room:obtainCard(comp2, cards, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "" })          -- 拒绝发动
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(#comp2:getCardIds("h"), 4, "拒绝发动时 comp2 手牌不变")
    lu.assertEquals(comp3.hp, 4, "拒绝发动时 comp3 不受影响")
  end)
end)

return j_junmou