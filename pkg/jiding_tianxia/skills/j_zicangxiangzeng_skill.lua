local j_zicangxiangzeng_skill = fk.CreateSkill {
  name = "j_zicangxiangzeng_skill",
}

Fk:loadTranslationTable{
  ["j_zicangxiangzeng_skill"] = "指仓相赠",
  [":j_zicangxiangzeng_skill"] = "出牌阶段，对一名其他角色使用，将其置于其判定区。判定阶段，若判定结果与此牌花色相同或点数奇偶相同，将此牌置于其武将牌上，称为“囷”，然后重复此流程；否则你摸两张牌。“囷”可以视为手牌使用或打出，使用“囷”无次数限制。",

  ["#j_zicangxiangzeng_skill"] = "指仓相赠",
}

-- 判定阶段结算（判定区牌由引擎移入处理区后触发）：发起判定，结果由“囷”技能处理
j_zicangxiangzeng_skill:addEffect("cardskill", {
  prompt = "#j_zicangxiangzeng_skill",
  mod_target_filter = function(self, player, to_select, selected, card, distance_limited)
    return to_select ~= player
  end,
  target_filter = Util.CardTargetFilter,
  target_num = 1,
  on_effect = function(self, room, effect)
    local to = effect.to
    local card = effect.card
    -- 统一以实体牌记录（转化使用时取子牌）
    local real_id = card:isVirtual() and card.subcards[1] or card.id
    room:setCardMark(Fk:getCardById(real_id), "j_zicang_target", to.id)
    room:setPlayerMark(to, "j_zicang_in_judge", real_id)

    local judge = {
      who = to,
      reason = "j_zicangxiangzeng",
      pattern = ".",
    }
    room:judge(judge)

    -- 判定被终止（无改判等异常）：兜底弃牌并清除标记
    if not judge.results then
      local move = { ids = { real_id }, toArea = Card.DiscardPile, moveReason = fk.ReasonPut, skillName = "j_zicangxiangzeng_skill" }
      if card:isVirtual() then move.virtualEquip = card end
      room:moveCards(move)
      room:setPlayerMark(to, "j_zicang_in_judge", 0)
    end
  end,
  on_nullified = function(self, room, effect)
    local card = effect.card
    local real_id = card:isVirtual() and card.subcards[1] or card.id
    local move = { ids = { real_id }, toArea = Card.DiscardPile, moveReason = fk.ReasonPut, skillName = "j_zicangxiangzeng_skill" }
    if card:isVirtual() then move.virtualEquip = card end
    room:moveCards(move)
    if effect.to then
      room:setPlayerMark(effect.to, "j_zicang_in_judge", 0)
    end
  end,
})

-- 使用【指仓相赠】时，把使用者记录到实体牌（判定阶段结算时无法从 effect 取得使用者）
j_zicangxiangzeng_skill:addEffect(fk.TargetConfirmed, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not data.card then return false end
    if data.card.name ~= "j_zicangxiangzeng" then return false end
    if not data.from or data.from.dead then return false end
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local real = room:getSubcardsByRule(data.card, { Card.Processing })
    if #real == 0 then
      real = data.card.subcards or {}
    end
    for _, id in ipairs(real) do
      room:setCardMark(Fk:getCardById(id), "j_zicang_source", data.from.id)
    end
  end,
})

return j_zicangxiangzeng_skill
