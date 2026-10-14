local huoji = fk.CreateSkill {
  name = "huoji",
}

Fk:loadTranslationTable{
  ["huoji"] = "火计",
  [":huoji"] = "出牌阶段限一次，你可以将一张红色手牌当作【火攻】使用。",
}

huoji:addEffect("viewas", {
  anim_type = "offensive",
  pattern = "fire_attack",
  prompt = "#huoji",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).color == Card.Red and table.contains(player:getHandlyIds(), to_select)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    local card = Fk:cloneCard("fire_attack")
    card.skillName = huoji.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play and player:usedSkillTimes(huoji.name, Player.HistoryPhase) == 0
  end,
})

return huoji