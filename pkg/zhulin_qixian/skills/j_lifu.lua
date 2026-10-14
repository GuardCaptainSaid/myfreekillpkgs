-- 山涛·励赋
-- 回合开始时，你声明一种花色，本回合出牌阶段内，每当一张牌进入弃牌堆时，
-- 若其与你声明的花色不同，回合结束时你摸一张牌；若其花色与你声明的花色相同，回合结束后你流失一点体力。
local j_lifu = fk.CreateSkill {
  name = "j_lifu",
}

Fk:loadTranslationTable{
  ["j_lifu"] = "励赋",
  [":j_lifu"] = "回合开始时，你声明一种花色，本回合出牌阶段内，每当一张牌进入弃牌堆时，若其与你声明的花色不同，回合结束时你摸一张牌；若其花色与你声明的花色相同，回合结束后你流失一点体力。",

  ["#j_lifu-choose"] = "励赋：声明一种花色",
  ["$j_lifu1"] = "山涛雅量，赋以励众。",
  ["$j_lifu2"] = "所赋唯诚，何惧得失。",
}

-- 回合开始：声明花色（mark 存花色常量 1-4：spade/club/heart/diamond）
j_lifu:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Start then return false end
    if target ~= player then return false end
    if not player:hasSkill(j_lifu.name) or player.dead then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = room:askToChoice(player, {
      choices = { "spade", "club", "heart", "diamond" },
      skill_name = j_lifu.name,
      prompt = "#j_lifu-choose",
      cancelable = false,
    })
    local suitMap = { spade = Card.Spade, club = Card.Club, heart = Card.Heart, diamond = Card.Diamond }
    room:setPlayerMark(player, "j_lifu_suit", suitMap[choice] or 0)
  end,
})

-- 本回合出牌阶段内进弃牌堆：按花色计数
j_lifu:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_lifu.name) or player.dead then return false end
    if player.room.current ~= player then return false end
    if player.phase ~= Player.Play then return false end
    if player:getMark("j_lifu_suit") == 0 then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local suit = player:getMark("j_lifu_suit")
    local drawN, loseN = 0, 0
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, id in ipairs(move.ids) do
          local c = Fk:getCardById(id)
          if c.suit == suit then
            loseN = loseN + 1
          else
            drawN = drawN + 1
          end
        end
      end
    end
    room:setPlayerMark(player, "j_lifu_draw", player:getMark("j_lifu_draw") + drawN)
    room:setPlayerMark(player, "j_lifu_lose", player:getMark("j_lifu_lose") + loseN)
  end,
})

-- 回合结束：结算（摸牌后流失）
j_lifu:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if data.to ~= Player.Finish then return false end
    if target ~= player then return false end
    if not player:hasSkill(j_lifu.name) or player.dead then return false end
    return player:getMark("j_lifu_draw") + player:getMark("j_lifu_lose") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local drawN = player:getMark("j_lifu_draw")
    local loseN = player:getMark("j_lifu_lose")
    room:setPlayerMark(player, "j_lifu_draw", 0)
    room:setPlayerMark(player, "j_lifu_lose", 0)
    if drawN > 0 then
      player:drawCards(drawN, j_lifu.name)
    end
    if loseN > 0 then
      room:loseHp(player, loseN, j_lifu.name, player)
    end
  end,
})

j_lifu:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_lifu.name,
  think = function(self, player)
    -- 常驻，无需 AI 决策
    return true
  end,
})

-- 测试：声明♥ → 出牌阶段♠(异花色)进弃牌堆 → 回合结束摸1
j_lifu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lifu.name)
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "j_lifu_suit", 0)
    room:setPlayerMark(me, "j_lifu_draw", 0)
    room:setPlayerMark(me, "j_lifu_lose", 0)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { { "heart" } })
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Finish, to = Player.Start })
    lu.assertEquals(me:getMark("j_lifu_suit"), Card.Heart, "励赋：应记录声明花色♥")
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local c1 = room:printCard("slash", Card.Spade, 7)
    room.logic:trigger(fk.AfterCardsMove, me, {
      { ids = { c1.id }, from = me, to = nil, toArea = Card.DiscardPile, moveReason = fk.ReasonDiscard, proposer = me },
    })
    lu.assertEquals(me:getMark("j_lifu_draw"), 1, "励赋：异花色应计入摸牌")
  end)

  FkTest.runInRoom(function()
    local before = #me:getCardIds("h")
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Play, to = Player.Finish })
    lu.assertEquals(#me:getCardIds("h"), before + 1, "励赋：回合结束应摸1张")
    lu.assertEquals(me:getMark("j_lifu_draw"), 0, "励赋：结算后计数清零")
  end)
end)

-- 测试：声明♥ → 出牌阶段♥(同花色)进弃牌堆 → 回合结束流失1体力
j_lifu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lifu.name)
    room.current = me
    me.phase = Player.Play
    room:setPlayerMark(me, "j_lifu_suit", Card.Heart)
    room:setPlayerMark(me, "j_lifu_draw", 0)
    room:setPlayerMark(me, "j_lifu_lose", 0)
  end)

  FkTest.runInRoom(function()
    local c1 = room:printCard("jink", Card.Heart, 8)
    room.logic:trigger(fk.AfterCardsMove, me, {
      { ids = { c1.id }, from = me, to = nil, toArea = Card.DiscardPile, moveReason = fk.ReasonDiscard, proposer = me },
    })
    lu.assertEquals(me:getMark("j_lifu_lose"), 1, "励赋：同花色应计入流失")
  end)

  FkTest.runInRoom(function()
    local hpBefore = me.hp
    room.logic:trigger(fk.EventPhaseStart, me, { from = Player.Play, to = Player.Finish })
    lu.assertEquals(me.hp, hpBefore - 1, "励赋：回合结束应流失1点体力")
  end)
end)

return j_lifu