local j_qun = fk.CreateSkill {
  name = "j_qun",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_qun"] = "囷",
  [":j_qun"] = "锁定技，一名角色的判定区内有【指仓相赠】并判定时，若判定结果与此【指仓相赠】花色相同或点数奇偶相同，你获得此牌并置于你的武将牌上，称为“囷”，然后将一张新的【指仓相赠】置入其判定区，重复此流程；否则其原使用者摸两张牌。你拥有的“囷”可以视为手牌使用或打出，使用“囷”无次数限制。",
  ["@j_qun"] = "囷",
}

j_qun:addEffect(fk.FinishJudge, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_qun.name) then return false end
    if not target:isAlive() then return false end
    if data.reason ~= "j_zicangxiangzeng" then return false end
    return target:getMark("j_zicang_in_judge") ~= 0
  end,
  on_use = function(self, event, target, player, data)
    local room = event.room
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
    if not source or not source:isAlive() then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    local judge_card = data.card
    if not judge_card then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    local match_suit = real_card.suit ~= Card.NoSuit and real_card.suit == judge_card.suit
    local match_parity = (real_card.number % 2) == (judge_card.number % 2)

    if match_suit or match_parity then
      -- 判定成功：置于拥有者武将牌上，称为“囷”
      local move = {
        ids = { real_id },
        to = player,
        toArea = Card.PlayerSpecial,
        specialName = "j_qun",
        moveReason = fk.ReasonPut,
        skillName = j_qun.name,
      }
      if zicang_card:isVirtual() then
        move.virtualEquip = zicang_card
      end
      room:moveCards(move)

      -- 重复此流程：新的【指仓相赠】置入其判定区
      local new_card = room:printCard("j_zicangxiangzeng", real_card.suit, real_card.number)
      room:moveCardTo(new_card.id, Card.PlayerJudge, target, fk.ReasonPut, j_qun.name)
      room:setCardMark(new_card, "j_zicang_target", target.id)
      room:setCardMark(new_card, "j_zicang_source", source_id)

      room:setPlayerMark(target, "j_zicang_in_judge", new_card.id)
    else
      -- 判定失败：原使用者摸两张牌
      source:drawCards(2, j_qun.name)
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

-- “囷”视为手牌：武将牌上的囷可如手牌般使用或打出
j_qun:addEffect("filter", {
  handly_cards = function(self, player)
    return player:getPile("j_qun")
  end,
})

return j_qun
