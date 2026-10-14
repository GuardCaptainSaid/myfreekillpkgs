-- 刘伶·醉狂
-- 锁定技，你使用酒时获得一层“醉意”，当其数量等于场上人数时，你失去所有“醉意”对所有其他角色使用一张【杀】，然后摸x张牌。（x为已受伤角色数）
local j_zuiukuang = fk.CreateSkill {
  name = "j_zuiukuang",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_zuiukuang"] = "醉狂",
  [":j_zuiukuang"] = "锁定技，你使用酒时获得一层“醉意”，当其数量等于场上人数时，你失去所有“醉意”对所有其他角色使用一张【杀】，然后摸x张牌。（x为已受伤角色数）",

  ["$j_zuiukuang1"] = "醉里乾坤大，壶中日月长。",
  ["$j_zuiukuang2"] = "但愿长醉不愿醒！",
}

j_zuiukuang:addEffect(fk.CardUsing, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zuiukuang.name, true) or player.dead then return false end
    return data.card and data.card.trueName == "analeptic"
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local num = player:getMark("@j_zuiukuang") + 1
    if num < #room.alive_players then
      room:setPlayerMark(player, "@j_zuiukuang", num)
      return
    end
    -- 醉意达到场上人数：清空并对所有其他角色使用杀，然后摸x张（x为已受伤角色数）
    room:setPlayerMark(player, "@j_zuiukuang", 0)
    local others = table.filter(room:getOtherPlayers(player), function(p) return not p.dead end)
    if #others > 0 then
      local slash = Fk:cloneCard("slash")
      room:useCard{ from = player, card = slash, tos = others }
    end
    local wounded = table.filter(room.alive_players, function(p) return p.hp < p.maxHp end)
    if #wounded > 0 then
      player:drawCards(#wounded, j_zuiukuang.name)
    end
  end,
})

-- 测试：醉意达到场上人数时对所有其他角色使用杀并摸牌
j_zuiukuang:addTest(function(room, me)
  local comps = {}
  for i = 2, #room.players do table.insert(comps, room.players[i]) end
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zuiukuang.name)
    me.maxHp = 3
    me.hp = 3
    -- 造伤：让 comps[1] 受伤（hp=maxHp-1），其余满血
    comps[1].maxHp = 3
    comps[1].hp = 2
    room.current = me
    me.phase = Player.Play
    local wine = room:printCard("analeptic", Card.Spade, 3)
    room:obtainCard(me, { wine }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local aliveCount = #room.alive_players
    local w = Fk:getCardById(me:getCardIds("h")[1])
    local hps = {}
    for i, c in ipairs(comps) do hps[i] = c.hp end
    local handBefore = #me:getCardIds("h")
    -- 使用 aliveCount-1 次酒：醉意累积（未达人数）
    for i = 1, aliveCount - 1 do
      room.logic:trigger(fk.CardUsing, me, { card = w })
      lu.assertEquals(me:getMark("@j_zuiukuang"), i, "醉狂：第" .. i .. "层醉意")
    end
    -- 第 aliveCount 次使用：达到场上人数 → 触发群杀 + 摸牌
    room.logic:trigger(fk.CardUsing, me, { card = w })
    lu.assertEquals(me:getMark("@j_zuiukuang"), 0, "醉狂：触发后醉意应清空")
    for i, c in ipairs(comps) do
      lu.assertEquals(c.hp, hps[i] - 1, "醉狂：目标" .. (i + 1) .. "应受1点伤害")
    end
    -- 已受伤角色数 = 其他角色数（全部被群杀打伤）
    lu.assertEquals(#me:getCardIds("h"), handBefore + #comps, "醉狂：应摸已受伤角色数张牌")
  end)
end)

return j_zuiukuang