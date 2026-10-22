-- 计董昭·定畿
-- 出牌阶段开始时，你可以将两张牌置于牌堆顶，视为对任意名角色使用一张【五谷丰登】。
-- 获得牌点数最大的角色弃两张牌，最小的角色失去一点体力。
-- 本回合你对这两名角色中手牌数小于你的角色使用牌无次数限制。
local j_dingji = fk.CreateSkill {
  name = "j_dingji",
}

Fk:loadTranslationTable{
  ["j_dingji"] = "定畿",
  [":j_dingji"] = "出牌阶段开始时，你可以将两张牌置于牌堆顶，视为对任意名角色使用一张【五谷丰登】。获得牌点数最大的角色弃两张牌，最小的角色失去一点体力。本回合你对这两名角色中手牌数小于你的角色使用牌无次数限制。",

  ["#j_dingji-invoke"] = "定畿：是否将两张牌置于牌堆顶，视为使用【五谷丰登】？",
  ["#j_dingji-put"] = "定畿：选择两张手牌置于牌堆顶",
  ["#j_dingji-targets"] = "定畿：选择任意名角色作为【五谷丰登】目标",
  ["#j_dingji-discard"] = "定畿：弃置两张牌",
}

-- 出牌阶段开始时：置两张牌于牌堆顶，视为使用【五谷丰登】
j_dingji:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_dingji.name)
      and not player.dead and player.phase == Player.Play
  end,
  on_cost = function(self, event, target, player, data)
    if #player:getCardIds("h") < 2 then return false end
    return player.room:askToSkillInvoke(player, {
      skill_name = j_dingji.name,
      prompt = "#j_dingji-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 选两张手牌置于牌堆顶
    local ids = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      min = 2,
      max = 2,
      cancelable = false,
      pattern = ".",
      skill_name = j_dingji.name,
      prompt = "#j_dingji-put",
    })
    if not ids or #ids < 2 then return end
    for _, id in ipairs(ids) do
      room:moveCardTo(id, Card.DrawPile, nil, fk.ReasonPut, j_dingji.name)
    end
    -- 任意名角色作为【五谷丰登】目标
    local tos = room:askToChoosePlayers(player, {
      targets = room.alive_players,
      min_num = 1,
      max_num = #room.alive_players,
      skill_name = j_dingji.name,
      prompt = "#j_dingji-targets",
      cancelable = false,
    })
    if #tos == 0 then return end
    -- 视为使用【五谷丰登】：展示目标数张牌（置顶的两张在牌堆顶，自然包含其中）
    local toDisplay = room:getNCards(#tos)
    local ag = Fk:cloneCard("amazing_grace")
    ag.skillName = j_dingji.name
    for _, id in ipairs(toDisplay) do
      ag:addSubcard(id)
    end
    room:useCard{
      from = player,
      tos = tos,
      card = ag,
      extra_data = { orig_cards = toDisplay },
    }

    -- 统计实际被获得（仍在手牌区）的牌与获得者
    local gained = {}
    for _, cid in ipairs(ids) do
      local owner = room:getCardOwner(cid)
      if owner and owner:isAlive() and room:getCardArea(cid) == Card.PlayerHand then
        table.insert(gained, { id = cid, holder = owner, num = Fk:getCardById(cid).number })
      end
    end
    if #gained == 0 then return end
    table.sort(gained, function(a, b) return a.num > b.num end)
    local maxEntry = gained[1]
    local minEntry = gained[#gained]

    -- 点数最大者弃两张牌
    local he = maxEntry.holder:getCardIds("he")
    if #he > 0 then
      room:askToDiscard(maxEntry.holder, {
        min_num = math.min(2, #he),
        max_num = math.min(2, #he),
        include_equip = true,
        skill_name = j_dingji.name,
        prompt = "#j_dingji-discard",
        cancelable = false,
      })
    end
    -- 点数最小者失去一点体力（若与最大者为同一人，两项均执行）
    if minEntry.holder ~= maxEntry.holder or minEntry.id ~= maxEntry.id then
      room:loseHp(minEntry.holder, 1, j_dingji.name, player)
    end

    -- 记录本回合无次数限制的目标
    local unlock = {}
    table.insertIfNeed(unlock, maxEntry.holder.id)
    table.insertIfNeed(unlock, minEntry.holder.id)
    room:setPlayerMark(player, "j_dingji_unlock-turn", unlock)
  end,
})

-- 本回合对这两名角色中手牌数小于你的角色使用牌无次数限制
j_dingji:addEffect("targetmod", {
  bypass_times = function(self, player, skill, scope, card, to)
    if not to or not player:hasSkill(j_dingji.name) or player.dead then return false end
    local unlock = player:getTableMark("j_dingji_unlock-turn")
    if #unlock == 0 then return false end
    return table.contains(unlock, to.id) and to:getHandcardNum() < player:getHandcardNum()
  end,
})

-- 测试：定畿完整流程——置顶两张牌 → 五谷丰登展示目标数张牌（3 目标展示 3 张）→
-- 最大点数获得者弃两张牌 → 记录无次数限制目标
j_dingji:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  local comp4 = room.players[4]
  local c1, c2, j1, j2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_dingji.name)
    room.current = me
    me.phase = Player.Play
    c1 = room:printCard("slash", Card.Spade, 13)
    c2 = room:printCard("slash", Card.Heart, 2)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    j1 = room:printCard("jink", Card.Club, 3)
    j2 = room:printCard("jink", Card.Diamond, 4)
    room:obtainCard(comp2, { j1, j2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    local origChooseCards = room.askToChooseCards
    local origChoosePlayers = room.askToChoosePlayers
    local origDiscard = room.askToDiscard
    local origAG = room.askToAG
    room.askToSkillInvoke = function(self, who, params) return true end
    room.askToChooseCards = function(self, who, params)
      if who == me then return { c1.id, c2.id } end
      return origChooseCards(self, who, params)
    end
    room.askToChoosePlayers = function(self, who, params)
      return { comp2, comp3, comp4 }
    end
    -- 依次选择：comp2 拿点数最大的 c1，comp3 拿 c2，comp4 拿剩余展示牌
    room.askToAG = function(self, who, params)
      if who == comp2 then return c1.id end
      if who == comp3 then return c2.id end
      return params.id_list[1]
    end
    room.askToDiscard = function(self, who, params)
      if who == comp2 then
        -- stub 只返回 id，需手动执行真实弃置（引擎 askToDiscard 被覆盖后不会自己弃）
        room:throwCard({ j1.id, j2.id }, j_dingji.name, comp2, me)
        return { j1.id, j2.id }
      end
      return origDiscard(self, who, params)
    end

    room.logic:trigger(fk.EventPhaseStart, me, {})

    room.askToSkillInvoke = origInvoke
    room.askToChooseCards = origChooseCards
    room.askToChoosePlayers = origChoosePlayers
    room.askToAG = origAG
    room.askToDiscard = origDiscard

    -- 五谷丰登应展示目标数（3）张牌：置顶的 c1、c2 都在展示牌中，三人都获得了一张牌
    lu.assertTrue(table.contains(comp2:getCardIds("h"), c1.id), "comp2 应获得点数最大的牌")
    lu.assertTrue(table.contains(comp3:getCardIds("h"), c2.id), "comp3 应获得置顶的另一张牌")
    lu.assertTrue(#comp4:getCardIds("h") == 1, "comp4 应获得第三张展示牌")
    lu.assertTrue(not table.contains(comp2:getCardIds("h"), j1.id), "点数最大者应弃置牌1")
    lu.assertTrue(not table.contains(comp2:getCardIds("h"), j2.id), "点数最大者应弃置牌2")
    -- 无次数限制目标应记录 comp2
    lu.assertTrue(table.contains(me:getTableMark("j_dingji_unlock-turn"), comp2.id), "应记录无次数限制目标")
  end)
end)

return j_dingji
