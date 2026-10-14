local j_cangzhuo = fk.CreateSkill {
  name = "j_cangzhuo",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_cangzhuo"] = "藏拙",
  [":j_cangzhuo"] = "锁定技，弃牌阶段开始时，你的锦囊牌不计入手牌上限。若你弃牌阶段没有弃置手牌，则摸一张牌。",

  ["$j_cangzhuo1"] = "深藏不露，静待时机。",
  ["$j_cangzhuo2"] = "韬光养晦，厚积薄发。",
}

j_cangzhuo:addEffect("maxcards", {
  exclude_from = function(self, player, card)
    return player:hasSkill(j_cangzhuo.name) and card.type == Card.TypeTrick
  end,
})

j_cangzhuo:addEffect(fk.EventPhaseStart, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_cangzhuo.name) and player.phase == Player.Discard
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_cangzhuo_discarded-turn", 0)
  end,
})

j_cangzhuo:addEffect(fk.AfterCardsMove, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if not (player:hasSkill(j_cangzhuo.name) and player.phase == Player.Discard) then return false end
    for _, move in ipairs(data) do
      if move.from == player and move.toArea == Card.DiscardPile then
        return true
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_cangzhuo_discarded-turn", 1)
  end,
})

j_cangzhuo:addEffect(fk.EventPhaseEnd, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_cangzhuo.name) and player.phase == Player.Discard
  end,
  on_use = function(self, event, target, player, data)
    if player:getMark("j_cangzhuo_discarded-turn") == 0 then
      player.room:drawCards(player, 1, j_cangzhuo.name)
    end
  end,
})

return j_cangzhuo
