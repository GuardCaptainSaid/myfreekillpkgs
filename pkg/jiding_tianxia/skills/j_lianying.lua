local j_lianying = fk.CreateSkill {
  name = "j_lianying",
}

Fk:loadTranslationTable{
  ["j_lianying"] = "连营",
  [":j_lianying"] = "当你失去牌时，你摸一张牌。然后若手牌中有花色相同的牌，此技能本回合失效。",

  ["$j_lianying1"] = "火舞连营，势不可挡！",
  ["$j_lianying2"] = "绵绵不绝，生生不息。",
}

j_lianying:addEffect(fk.AfterCardsMove, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_lianying.name) then return false end
    if player:getMark("j_lianying_disabled-turn") > 0 then return false end
    for _, move in ipairs(data) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            return true
          end
        end
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, j_lianying.name)

    local suits = {}
    for _, cid in ipairs(player:getCardIds("h")) do
      local suit = Fk:getCardById(cid).suit
      if suits[suit] then
        player.room:setPlayerMark(player, "j_lianying_disabled-turn", 1)
        return
      end
      suits[suit] = true
    end
  end,
})

return j_lianying