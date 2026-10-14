-- 山涛·逊尊
-- 出牌阶段限X-1次（X为你已损失的体力值），你可以将一张手牌置于牌堆底，摸一张牌并选择一项：
-- 1.令一名体力值大于你的角色流失一点体力并重铸一张牌；
-- 2.令一名体力值小于等于你的角色回复一点体力并摸一张牌。
local j_xunzun = fk.CreateSkill {
  name = "j_xunzun",
}

j_xunzun:addEffect("active", {
  anim_type = "control",
  card_num = 0,
  can_use = function(self, player)
    local lost = player.maxHp - player.hp
    local limit = math.max(0, lost - 1)
    if limit <= 0 then return false end
    if player:usedSkillTimes(j_xunzun.name, Player.HistoryTurn) >= limit then return false end
    return #player:getCardIds("h") > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from

    -- 一张手牌置于牌堆底
    local picked = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      min = 1,
      max = 1,
      cancelable = false,
      pattern = ".",
      skill_name = j_xunzun.name,
      prompt = "#j_xunzun-put",
    })
    if not picked or #picked == 0 then return end
    room:moveCards {
      ids = picked,
      from = player,
      toArea = Card.DrawPile,
      moveReason = fk.ReasonPut,
      proposer = player,
      skillName = j_xunzun.name,
      drawPilePosition = -1,
    }
    player:drawCards(1, j_xunzun.name)

    -- 选择一项
    local choice = room:askToChoice(player, {
      choices = { "j_xunzun:lose", "j_xunzun:recover" },
      skill_name = j_xunzun.name,
      prompt = "#j_xunzun-choice",
    })
    if choice == "j_xunzun:lose" then
      -- 1.体力值大于你的角色：流失1点体力并重铸一张牌
      local candidates = table.filter(room:getOtherPlayers(player), function(p)
        return not p.dead and p.hp > player.hp
      end)
      if #candidates == 0 then return end
      local t = room:askToChoosePlayers(player, {
        targets = candidates,
        min_num = 1,
        max_num = 1,
        cancelable = false,
        skill_name = j_xunzun.name,
        prompt = "#j_xunzun-lose",
      })[1]
      if t then
        room:loseHp(t, 1, j_xunzun.name, player)
        local rec = room:askToChooseCards(t, {
          target = t,
          flag = "h",
          min = 1,
          max = 1,
          cancelable = true,
          pattern = ".",
          skill_name = j_xunzun.name,
          prompt = "#j_xunzun-recast",
        })
        if rec and #rec > 0 then
          room:recastCard(rec, t, j_xunzun.name)
        end
      end
    else
      -- 2.体力值小于等于你的角色：回复1点体力并摸一张牌
      local candidates = table.filter(room:getOtherPlayers(player), function(p)
        return not p.dead and p.hp <= player.hp
      end)
      if #candidates == 0 then return end
      local t = room:askToChoosePlayers(player, {
        targets = candidates,
        min_num = 1,
        max_num = 1,
        cancelable = false,
        skill_name = j_xunzun.name,
        prompt = "#j_xunzun-recover",
      })[1]
      if t then
        room:recover{ who = t, num = 1, recoverBy = player, skillName = j_xunzun.name }
        t:drawCards(1, j_xunzun.name)
      end
    end
  end,
})

Fk:loadTranslationTable{
  ["j_xunzun"] = "逊尊",
  [":j_xunzun"] = "出牌阶段限X-1次（X为你已损失的体力值），你可以将一张手牌置于牌堆底，摸一张牌并选择一项：1.令一名体力值大于你的角色流失一点体力并重铸一张牌；2.令一名体力值小于等于你的角色回复一点体力并摸一张牌。",

  ["#j_xunzun-put"] = "逊尊：将一张手牌置于牌堆底",
  ["#j_xunzun-choice"] = "逊尊：选择一项",
  ["j_xunzun:lose"] = "令一名体力值大于你的角色流失一点体力并重铸一张牌",
  ["j_xunzun:recover"] = "令一名体力值小于等于你的角色回复一点体力并摸一张牌",
  ["#j_xunzun-lose"] = "逊尊：选择一名体力值大于你的角色",
  ["#j_xunzun-recast"] = "逊尊：令其选择一张手牌重铸",
  ["#j_xunzun-recover"] = "逊尊：选择一名体力值小于等于你的角色",

  ["$j_xunzun1"] = "尊贤逊位，人皆称善。",
  ["$j_xunzun2"] = "才逊于德，敢不谦冲。",
}

j_xunzun:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_xunzun.name,
  think = function(self, player)
    return #player:getCardIds("h") > 0
  end,
})

-- 测试：hp=2（损失2，限1次）→ 发动选项1：置牌堆底+摸1 → 目标流失1并重铸
j_xunzun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xunzun.name)
    me.maxHp = 4
    me.hp = 2
    room.current = me
    me.phase = Player.Play
    local c1 = room:printCard("slash", Card.Club, 2)
    local c2 = room:printCard("jink", Card.Spade, 3)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    -- comp2 体力 3 > 2，且有手牌供重铸
    local t1 = room:printCard("peach", Card.Heart, 4)
    room:obtainCard(comp2, { t1 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    local meHand = me:getCardIds("h")
    local compHand = comp2:getCardIds("h")
    local compHpBefore = comp2.hp
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { { meHand[1] }, { "j_xunzun:lose" }, FkTest.ReplyChoosePlayer({ comp2 }) })
    FkTest.setNextReplies(comp2, { { compHand[1] } })
    local sk = Fk.skills[j_xunzun.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})

    -- 置底+摸1 → 手牌数不变
    lu.assertEquals(#me:getCardIds("h"), handBefore, "逊尊：置底1张摸1张，手牌数应不变")
    -- 置于牌堆底
    lu.assertEquals(room.draw_pile[#room.draw_pile], meHand[1], "逊尊：手牌应置于牌堆底")
    -- 目标流失1点体力
    lu.assertEquals(comp2.hp, compHpBefore - 1, "逊尊：目标应流失1点体力")
    -- 目标重铸1张：弃1摸1 → 手牌数不变
    lu.assertEquals(#comp2:getCardIds("h"), 1, "逊尊：目标重铸后手牌数应不变")
    -- 次数记录
    lu.assertEquals(me:usedSkillTimes(j_xunzun.name, Player.HistoryTurn), 1, "逊尊：应记录发动次数")
  end)
end)

-- 测试：选项2 → 目标回复1并摸1
j_xunzun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xunzun.name)
    me.maxHp = 4
    me.hp = 2
    comp2.maxHp = 3
    comp2.hp = 2
    room.current = me
    me.phase = Player.Play
    local c1 = room:printCard("slash", Card.Club, 2)
    local c2 = room:printCard("jink", Card.Spade, 3)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local meHand = me:getCardIds("h")
    local compHpBefore = comp2.hp
    local compHandBefore = #comp2:getCardIds("h")
    FkTest.setNextReplies(me, { { meHand[1] }, { "j_xunzun:recover" }, FkTest.ReplyChoosePlayer({ comp2 }) })
    local sk = Fk.skills[j_xunzun.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    lu.assertEquals(comp2.hp, compHpBefore + 1, "逊尊：目标应回复1点体力")
    lu.assertEquals(#comp2:getCardIds("h"), compHandBefore + 1, "逊尊：目标应摸1张牌")
  end)
end)

-- 测试：满血（损失0）→ 不能发动
j_xunzun:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xunzun.name)
    me.maxHp = 4
    me.hp = 4
    local c1 = room:printCard("slash", Card.Club, 2)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
  end)
  local sk = Fk.skills[j_xunzun.name]
  local skel = sk:getSkeleton()
  local eff
  for _, spec in ipairs(skel.effect_spec_list) do
    if spec[1] == "active" then eff = spec[3] break end
  end
  lu.assertNotNil(eff, "逊尊：应存在主动效果")
  lu.assertFalse(eff.can_use(eff, me), "逊尊：满血时不应可发动")
end)

return j_xunzun