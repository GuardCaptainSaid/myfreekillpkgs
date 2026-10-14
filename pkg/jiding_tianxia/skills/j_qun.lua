local j_qun = fk.CreateSkill {
  name = "j_qun",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_qun"] = "囷",
  [":j_qun"] = "锁定技，一名角色的判定区内有【指仓相赠】并判定时，若判定结果与此【指仓相赠】花色相同或点数奇偶相同，此角色获得此牌并置于其武将牌上，称为“囷”，然后将一张新的【指仓相赠】置入其判定区，重复此流程；否则其原使用者摸两张牌。“囷”可以视为手牌使用或打出，使用“囷”无次数限制。",
  ["@j_qun"] = "囷",
}

local function syncQunMark(room, player)
  if not player or player.dead then return end
  room:setPlayerMark(player, "@j_qun", #player:getPile("j_qun"))
end

j_qun:addEffect(fk.FinishJudge, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player ~= target then return false end
    if not target:isAlive() then return false end
    if data.reason ~= "j_zicangxiangzeng" then return false end
    return target:getMark("j_zicang_in_judge") ~= 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local zicang_card_id = target:getMark("j_zicang_in_judge")
    local zicang_card = Fk:getCardById(zicang_card_id)
    if not zicang_card then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    -- 统一以实体牌操作（转化使用时判定区为虚拟牌，取其子牌）
    local real_id = zicang_card:isVirtual() and zicang_card.subcards[1] or zicang_card.id
    local real_card = real_id and Fk:getCardById(real_id)
    if not real_card then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    local source_id = real_card:getMark("j_zicang_source")
    local source = source_id and source_id > 0 and room:getPlayerById(source_id) or nil

    local judge_card = data.card
    if not judge_card then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    local match_suit = real_card.suit ~= Card.NoSuit and real_card.suit == judge_card.suit
    local match_parity = (real_card.number % 2) == (judge_card.number % 2)

    if match_suit or match_parity then
      -- 判定成功：判定者（此角色）获得此牌，置于其武将牌上，称为“囷”
      local move = {
        ids = { real_id },
        to = target,
        toArea = Card.PlayerSpecial,
        specialName = "j_qun",
        moveReason = fk.ReasonPut,
        skillName = j_qun.name,
      }
      if zicang_card:isVirtual() then
        move.virtualEquip = zicang_card
      end
      room:moveCards(move)
      syncQunMark(room, target)

      -- 重复此流程：新的【指仓相赠】置入其判定区
      local new_card = room:printCard("j_zicangxiangzeng", real_card.suit, real_card.number)
      room:moveCardTo(new_card.id, Card.PlayerJudge, target, fk.ReasonPut, j_qun.name)
      room:setCardMark(new_card, "j_zicang_target", target.id)
      if source then
        room:setCardMark(new_card, "j_zicang_source", source.id)
      end

      room:setPlayerMark(target, "j_zicang_in_judge", new_card.id)
    else
      -- 判定失败：原使用者摸两张牌
      if source and source:isAlive() then
        source:drawCards(2, j_qun.name)
      end
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      local move = {
        ids = { real_id },
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPut,
        skillName = j_qun.name,
      }
      if zicang_card:isVirtual() then
        move.virtualEquip = zicang_card
      end
      room:moveCards(move)
    end
  end,
})

-- 同步“囷”标记（囷被使用/打出/移动后刷新武将牌上的计数）
j_qun:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    for _, move in ipairs(data) do
      for _, info in ipairs(move.moveInfo) do
        if (info.fromArea == Card.PlayerSpecial and info.fromSpecialName == "j_qun") or
           (move.toArea == Card.PlayerSpecial and move.specialName == "j_qun") then
          return true
        end
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, move in ipairs(data) do
      if move.toArea == Card.PlayerSpecial and move.specialName == "j_qun" and move.to then
        syncQunMark(room, move.to)
      end
      for _, info in ipairs(move.moveInfo) do
        if info.fromArea == Card.PlayerSpecial and info.fromSpecialName == "j_qun" and move.from then
          syncQunMark(room, move.from)
        end
      end
    end
  end,
})

-- “囷”视为手牌：武将牌上的囷可如手牌般使用或打出（全局生效）
j_qun:addEffect("filter", {
  global = true,
  handly_cards = function(self, player)
    return player:getPile("j_qun")
  end,
})

-- 测试：指仓相赠判定匹配 → 判定者获得囷（置于武将牌）+ 新指仓相赠入其判定区（重复流程）
j_qun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qun.name)
  end)

  FkTest.runInRoom(function()
    local zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)

    -- 模拟判定阶段：判定区牌移入处理区后再判定
    room:moveCardTo(zicang.id, Card.Processing, nil, fk.ReasonPut, "phase_judge")

    local judge_card = room:printCard("peach")
    judge_card.suit = Card.Heart
    judge_card.number = 5
    table.insert(room.draw_pile, 1, judge_card.id)

    room:judge{ who = comp2, reason = "j_zicangxiangzeng", pattern = "." }
    lu.assertEquals(#comp2:getPile("j_qun"), 1, "匹配时囷应置于判定者武将牌上")
    lu.assertEquals(comp2:getMark("@j_qun"), 1, "判定者应有囷标记")
    lu.assertEquals(#comp2:getCardIds(Player.Judge), 1, "匹配后新指仓相赠应留在其判定区")
    lu.assertEquals(comp2:getMark("j_zicang_in_judge") ~= 0, true, "应指向新指仓相赠")
  end)
end)

-- 测试：指仓相赠判定不匹配 → 原使用者摸两张牌，判定区清空
j_qun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qun.name)
  end)

  FkTest.runInRoom(function()
    local zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)

    -- 模拟判定阶段：判定区牌移入处理区后再判定
    room:moveCardTo(zicang.id, Card.Processing, nil, fk.ReasonPut, "phase_judge")

    local judge_card = room:printCard("slash")
    judge_card.suit = Card.Spade
    judge_card.number = 4
    table.insert(room.draw_pile, 1, judge_card.id)

    local hand_before = #me:getCardIds("h")
    room:judge{ who = comp2, reason = "j_zicangxiangzeng", pattern = "." }
    lu.assertEquals(#me:getCardIds("h"), hand_before + 2, "不匹配时原使用者摸两张牌")
    lu.assertEquals(#comp2:getCardIds(Player.Judge), 0, "不匹配时判定区应清空")
    lu.assertEquals(comp2:getMark("@j_qun"), 0, "不匹配时不应有囷标记")
  end)
end)

return j_qun