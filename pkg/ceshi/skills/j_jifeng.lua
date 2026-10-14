local j_jifeng = fk.CreateSkill {
  name = "j_jifeng",
}

Fk:loadTranslationTable{
  ["j_jifeng"] = "祭风",
  [":j_jifeng"] = "出牌阶段限一次，你可以展示一张手牌，从牌堆随机获得一张锦囊牌。",

  ["#j_jifeng-invoke"] = "祭风：是否展示一张手牌？",
  ["#j_jifeng-card"] = "祭风：选择一张手牌展示",

  ["$j_jifeng1"] = "借东风，助我破敌！",
  ["$j_jifeng2"] = "风起云涌，势不可挡！",
}

j_jifeng:addEffect("active", {
  anim_type = "offensive",
  card_num = 1,
  target_num = 0,
  can_use = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0 and
      player:usedSkillTimes(j_jifeng.name, Player.HistoryPhase) == 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local card_id = effect.cards and effect.cards[1]

    if card_id then
      room:showCards({card_id}, player, "j_jifeng")
    end

    local trick_card = nil
    local trick_cards = {}
    for _, cid in ipairs(room.draw_pile) do
      local card = Fk:getCardById(cid)
      if card.type == Card.TypeTrick then
        table.insert(trick_cards, card)
      end
    end
    if #trick_cards > 0 then
      trick_card = trick_cards[math.random(#trick_cards)]
    end

    if trick_card then
      room:obtainCard(player, trick_card, true, fk.ReasonDraw, player, j_jifeng.name)
    else
      room:drawCards(player, 1, j_jifeng.name)
    end
  end,
})

return j_jifeng