local j_zaoshi = fk.CreateSkill {
  name = "j_zaoshi",
}

Fk:loadTranslationTable{
  ["j_zaoshi"] = "造势",
  [":j_zaoshi"] = "当你成为一张牌的目标时，你可以将一张手牌置于牌堆顶或牌堆底，然后从牌堆顶或牌堆底摸一张牌。",

  ["#j_zaoshi-invoke"] = "造势：你可以将一张手牌置入牌堆并摸一张牌",
  ["#j_zaoshi-choose"] = "造势：选择一张手牌置于牌堆",
  ["#j_zaoshi-place"] = "造势：置于牌堆顶或牌堆底",
  ["#j_zaoshi-draw"] = "造势：从牌堆顶或牌堆底摸一张牌",
  ["j_zaoshi:top"] = "牌堆顶",
  ["j_zaoshi:bottom"] = "牌堆底",

  ["$j_zaoshi1"] = "虚实相生，攻守易势。",
  ["$j_zaoshi2"] = "造势而动，以静制动！",
}

j_zaoshi:addEffect(fk.TargetSpecified, {
  global = true,
  anim_type = "defense",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zaoshi.name) then return false end
    if player.dead then return false end
    return #player:getCardIds("h") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, { skill_name = j_zaoshi.name, prompt = "#j_zaoshi-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = room:askToChooseCards(player, {
      target = player, flag = "h", min = 1, max = 1,
      cancelable = false, skill_name = j_zaoshi.name, prompt = "#j_zaoshi-choose",
    })
    if not cards or #cards ~= 1 then
      return end

    local where = room:askToChoice(player, {
      choices = { "j_zaoshi:top", "j_zaoshi:bottom" },
      skill_name = j_zaoshi.name,
      prompt = "#j_zaoshi-place",
    })
    local ok
    if where == "j_zaoshi:bottom" then
      ok = room:moveCards { ids = cards, from = player, toArea = Card.DrawPile, moveReason = fk.ReasonPut, skillName = j_zaoshi.name, proposer = player, drawPilePosition = -1 }
    else
      ok = room:moveCards { ids = cards, from = player, toArea = Card.DrawPile, moveReason = fk.ReasonPut, skillName = j_zaoshi.name, proposer = player, drawPilePosition = 1 }
    end
    if not ok then return end

    local where2 = room:askToChoice(player, {
      choices = { "j_zaoshi:top", "j_zaoshi:bottom" },
      skill_name = j_zaoshi.name,
      prompt = "#j_zaoshi-draw",
    })
    player:drawCards(1, j_zaoshi.name, where2 == "j_zaoshi:bottom" and "bottom" or "top")
  end,
})

j_zaoshi:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_zaoshi.name,
  think = function(self, player)
    -- 手牌充裕时发动（保留防御牌）
    return #player:getCardIds("h") >= 3
  end,
})

return j_zaoshi
