-- 舒邵四号·散粮
-- 出牌阶段限一次，你可以将任意数量的手牌置于武将牌上，称为“粮”。然后你可以令至多X名角色各摸一张牌（X为你以此法放置的“粮”的数量且至多为你已损失的体力值+1）。若此时你的“粮”达到3张或以上，你可以立即弃置所有“粮”，视为对一名其他角色使用一张【杀】或【过河拆桥】。
local s_sanliang4 = fk.CreateSkill {
  name = "s_sanliang4",
}

Fk:loadTranslationTable{
  ["s_sanliang4"] = "散粮",
  [":s_sanliang4"] = "出牌阶段限一次，你可以将任意数量的手牌置于武将牌上，称为“粮”。然后你可以令至多X名角色各摸一张牌（X为你以此法放置的“粮”的数量且至多为你已损失的体力值+1）。若此时你的“粮”达到3张或以上，你可以立即弃置所有“粮”，视为对一名其他角色使用一张【杀】或【过河拆桥】。",

  ["#s_sanliang4-cards"] = "散粮：选择任意数量手牌置于武将牌上",
  ["#s_sanliang4-draw-target"] = "散粮：令至多%arg名角色各摸一张牌",
  ["#s_sanliang4-convert"] = "散粮：“粮”已达%arg枚，是否弃置所有“粮”视为使用一张牌？",
  ["#s_sanliang4-use-target"] = "散粮：选择【%arg】的目标",
  ["@s_sanliang4_liang"] = "粮",
  ["@s_sanliang4_used"] = "散粮",
  ["s_sanliang4_slash"] = "使用【杀】",
  ["s_sanliang4_dismantle"] = "使用【过河拆桥】",
  ["s_sanliang4_cancel"] = "不发动",

  ["$s_sanliang41"] = "仓廪积粮，以济征伐！",
  ["$s_sanliang42"] = "散粮聚众，攻守由我！",
}

-- 回合开始：重置本回合已用标记
s_sanliang4:addEffect(fk.TurnStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    return player:hasSkill(s_sanliang4.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@s_sanliang4_used-turn", 0)
  end,
})

-- 主动技：放粮、令摸牌、粮≥3可转换
s_sanliang4:addEffect("active", {
  anim_type = "support",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:getMark("@s_sanliang4_used-turn") ~= 0 then return false end
    return #player:getCardIds("h") > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player.dead then return end
    local hand = player:getCardIds("h")
    if #hand == 0 then return end
    -- 选任意数量手牌置于武将牌上
    local c = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      min = 1,
      max = #hand,
      cancelable = true,
      pattern = ".",
      skill_name = s_sanliang4.name,
      prompt = "#s_sanliang4-cards",
    })
    if not c or #c == 0 then return end
    room:setPlayerMark(player, "@s_sanliang4_used-turn", 1)
    -- 弃置入弃牌堆，计粮
    room:throwCard(c, fk.ReasonSkill, player, player, s_sanliang4.name)
    local liang = player:getMark("@s_sanliang4_liang") + #c
    room:setPlayerMark(player, "@s_sanliang4_liang", liang)
    -- 令至多X名角色各摸1（X=本次放粮数，至多 已损失体力+1）
    local x = math.min(#c, player:getLostHp() + 1)
    if x > 0 then
      local tos = room:askToChoosePlayers(player, {
        targets = room.alive_players,
        min_num = 0,
        max_num = x,
        cancelable = true,
        skill_name = s_sanliang4.name,
        prompt = "#s_sanliang4-draw-target",
      })
      for _, p in ipairs(tos) do
        p:drawCards(1, s_sanliang4.name)
      end
    end
    -- 粮≥3：可弃所有粮视为使用杀/过河拆桥
    if liang >= 3 then
      local choice = room:askToChoice(player, {
        skill_name = s_sanliang4.name,
        choices = { "s_sanliang4_slash", "s_sanliang4_dismantle", "s_sanliang4_cancel" },
        prompt = "#s_sanliang4-convert",
      })
      if choice ~= "s_sanliang4_cancel" then
        local cardName = choice == "s_sanliang4_slash" and "slash" or "dismantle"
        local tos2 = room:askToChoosePlayers(player, {
          targets = room:getOtherPlayers(player),
          min_num = 1,
          max_num = 1,
          cancelable = false,
          skill_name = s_sanliang4.name,
          prompt = "#s_sanliang4-use-target",
        })
        if tos2[1] and not tos2[1].dead then
          local vcard = Fk:cloneCard(cardName)
          vcard.skillName = s_sanliang4.name
          room:useCard{ from = player, tos = { tos2[1] }, card = vcard, extraUse = true }
        end
        room:setPlayerMark(player, "@s_sanliang4_liang", 0)
      end
    end
  end,
})

-- 测试1：放2张粮，满血令1名角色摸1，无转换
s_sanliang4:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_sanliang4.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 3
    comp2.hp = 3
    room.current = me
    me.phase = Player.Play
    local h1 = room:printCard("slash", Card.Spade, 3)
    local h2 = room:printCard("jink", Card.Heart, 4)
    room:obtainCard(me, { h1, h2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local h = me:getCardIds("h")
    local comp2Hand = #comp2:getCardIds("h")
    FkTest.setNextReplies(me, { { h[1], h[2] }, { card = { subcards = {} }, targets = { comp2.id } } })
    local active_sk
    for _, sk in ipairs(s_sanliang4.effects) do
      if sk:isInstanceOf(ActiveSkill) then active_sk = sk break end
    end
    lu.assertNotNil(active_sk, "散粮：应存在主动技子技能")
    active_sk:onUse(room, { from = me, tos = {}, cards = {} })
    lu.assertEquals(me:getMark("@s_sanliang4_liang"), 2, "散粮：应计2枚粮")
    lu.assertEquals(me:getMark("@s_sanliang4_used-turn"), 1, "散粮：应记录本回合已用")
    lu.assertEquals(#comp2:getCardIds("h"), comp2Hand + 1, "散粮：满血时最多令1名角色摸1张")
  end)
end)

-- 测试2：已有2枚粮，再放1张触发转换，视为使用杀
s_sanliang4:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_sanliang4.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 3
    comp2.hp = 3
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "@s_sanliang4_liang", 2)
    local h1 = room:printCard("peach", Card.Club, 5)
    room:obtainCard(me, { h1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local h = me:getCardIds("h")
    -- me：选牌1张 → 令摸牌目标 comp2 → 选择转换“杀” → 杀目标 comp2
    FkTest.setNextReplies(me, { { h[1] }, { card = { subcards = {} }, targets = { comp2.id } }, "s_sanliang4_slash", { card = { subcards = {} }, targets = { comp2.id } } })
    -- comp2：杀结算不出闪
    FkTest.setNextReplies(comp2, { "0" })
    local active_sk
    for _, sk in ipairs(s_sanliang4.effects) do
      if sk:isInstanceOf(ActiveSkill) then active_sk = sk break end
    end
    lu.assertNotNil(active_sk, "散粮：应存在主动技子技能")
    active_sk:onUse(room, { from = me, tos = {}, cards = {} })
    lu.assertEquals(me:getMark("@s_sanliang4_liang"), 0, "散粮：转换后应清空粮")
    lu.assertEquals(comp2.hp, 2, "散粮：视为使用的杀应命中")
  end)
end)

return s_sanliang4