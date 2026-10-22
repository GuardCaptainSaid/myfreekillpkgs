-- 计董昭·矫械
-- 每回合限一次，当一名角色于回合外获得牌后，你可以弃置一张牌，
-- 然后观看并将其中x张放回牌堆底。（x为此技能本轮的次数且至多为3）
local j_jiaoxie = fk.CreateSkill {
  name = "j_jiaoxie",
}

Fk:loadTranslationTable{
  ["j_jiaoxie"] = "矫械",
  [":j_jiaoxie"] = "每回合限一次，当一名角色于回合外获得牌后，你可以弃置一张牌，然后观看并将其中x张放回牌堆底，然后你摸两张牌。（x为此技能本轮的次数且至多为3）",

  ["#j_jiaoxie-discard"] = "矫械：弃置一张牌，观看其获得的牌并将其中x张放回牌堆底，然后摸两张牌",
  ["#j_jiaoxie-choose"] = "矫械：选择 %arg 张获得的牌放回牌堆底",
}

-- 收集本次移动中“于回合外获得且仍在获得者手牌区”的牌
local function collectGainedOutsideTurn(room, data)
  local gained = {}
  local cur = room.current
  for _, move in ipairs(data) do
    if move.to and move.toArea == Card.PlayerHand and move.from ~= move.to then
      -- 回合外：获得者不是当前回合角色
      if not cur or move.to.id ~= cur.id then
        for _, info in ipairs(move.moveInfo) do
          local owner = room:getCardOwner(info.cardId)
          if owner == move.to and room:getCardArea(info.cardId) == Card.PlayerHand then
            table.insertIfNeed(gained, info.cardId)
          end
        end
      end
    end
  end
  return gained
end

j_jiaoxie:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jiaoxie.name) or player.dead then return false end
    -- 每回合限一次
    if player:usedSkillTimes(j_jiaoxie.name, Player.HistoryTurn) > 0 then return false end
    return #collectGainedOutsideTurn(player.room, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if #player:getCardIds("he") == 0 then return false end
    local discard = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = j_jiaoxie.name,
      prompt = "#j_jiaoxie-discard",
      cancelable = true,
    })
    if not discard or #discard == 0 then return false end
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local gained = collectGainedOutsideTurn(room, data)
    if #gained == 0 then return end
    -- x 为此技能本轮的次数（含本次）且至多为 3
    local x = math.min(player:usedSkillTimes(j_jiaoxie.name, Player.HistoryRound), 3, #gained)
    if x <= 0 then return end
    -- 观看获得的牌并选择 x 张放回牌堆底
    local chosen = room:askToChooseCardsAndChoice(player, {
      cards = gained,
      choices = { "OK" },
      min_num = x,
      max_num = x,
      skill_name = j_jiaoxie.name,
      prompt = "#j_jiaoxie-choose:::" .. x,
    })
    if not chosen or #chosen == 0 then return end
    for _, cid in ipairs(chosen) do
      local owner = room:getCardOwner(cid)
      if owner and room:getCardArea(cid) == Card.PlayerHand then
        room:moveCards {
          ids = { cid },
          from = owner,
          toArea = Card.DrawPile,
          moveReason = fk.ReasonPut,
          proposer = player,
          skillName = j_jiaoxie.name,
          drawPilePosition = -1,
        }
      end
    end
    -- 然后你摸两张牌
    if player:isAlive() then
      player:drawCards(2, j_jiaoxie.name)
    end
  end,
})

-- 测试：回合外获得牌 → 弃一张牌 → 将其中 1 张放回牌堆底
j_jiaoxie:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  local d1, c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jiaoxie.name)
    room.current = comp2
    d1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { d1 }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    c1 = room:printCard("jink", Card.Heart, 6)
    c2 = room:printCard("jink", Card.Diamond, 7)
    local origDiscard = room.askToDiscard
    local origChoice = room.askToChooseCardsAndChoice
    room.askToDiscard = function(self, who, params)
      if who == me then
        -- stub 只返回 id，需手动执行真实弃置（引擎 askToDiscard 被覆盖后不会自己弃）
        room:throwCard({ d1.id }, j_jiaoxie.name, me, me)
        return { d1.id }
      end
      return origDiscard(self, who, params)
    end
    room.askToChooseCardsAndChoice = function(self, who, params)
      if who == me then return { c1.id }, "OK" end
      return origChoice(self, who, params)
    end

    -- comp3 于回合外（当前回合角色为 comp2）获得两张牌
    room:obtainCard(comp3, { c1, c2 }, true, fk.ReasonDraw, me, "test")

    room.askToDiscard = origDiscard
    room.askToChooseCardsAndChoice = origChoice

    -- 首次发动本轮次数 x=1：c1 被放回牌堆底，c2 仍在 comp3 手中，me 摸两张牌
    lu.assertEquals(room.draw_pile[#room.draw_pile], c1.id, "c1 应被放回牌堆底")
    lu.assertTrue(table.contains(comp3:getCardIds("h"), c2.id), "c2 应仍在 comp3 手中")
    lu.assertTrue(not table.contains(me:getCardIds("h"), d1.id), "发动成本应弃置 d1")
    lu.assertEquals(#me:getCardIds("h"), 2, "发动后 me 应摸两张牌")
  end)
end)

return j_jiaoxie
