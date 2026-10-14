local j_dizhi = fk.CreateSkill {
  name = "j_dizhi",
}

Fk:loadTranslationTable{
  ["j_dizhi"] = "缔智",
  [":j_dizhi"] = "每轮每名角色限一次，当一名角色受到伤害时，你可以展示牌堆底一张牌当作【指仓相赠】对其使用。",
}

j_dizhi:addEffect(fk.Damaged, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    local room = player.room
    if not room then return false end
    if not player:hasSkill(j_dizhi.name) then return false end
    if not target:isAlive() then return false end
    -- 【指仓相赠】不能对自己使用，受伤角色为技能持有者本人时不触发
    if target.id == player.id then return false end

    local round_count = room:getBanner("RoundCount") or 0
    local round_tag = "j_dizhi_round_" .. round_count
    local used_tag = round_tag .. "_" .. target.id
    if player:getMark(used_tag) > 0 then return false end

    return #room.draw_pile > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_dizhi.name })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if not target:isAlive() then return end
    local round_tag = "j_dizhi_round_" .. (room:getBanner("RoundCount") or 0)
    local used_tag = round_tag .. "_" .. target.id
    room:setPlayerMark(player, used_tag, 1)

    if #room.draw_pile == 0 then
      table.shuffle(room.discard_pile)
      table.insertTable(room.draw_pile, room.discard_pile)
      room.discard_pile = {}
      for _, id in ipairs(room.draw_pile) do
        room:setCardArea(id, Card.DrawPile)
      end
    end

    local bottom_card_id = room.draw_pile[#room.draw_pile]
    local bottom_card = Fk:getCardById(bottom_card_id)
    if not bottom_card then return end

    room:showCards({bottom_card_id}, player, j_dizhi.name)

    table.remove(room.draw_pile, #room.draw_pile)
    room:setCardArea(bottom_card_id, Card.DiscardPile)

    local zicang_card = Fk:cloneCard("j_zicangxiangzeng", bottom_card.suit, bottom_card.number)
    zicang_card.skillName = j_dizhi.name

    room:useCard{
      from = player,
      card = zicang_card,
      tos = {target},
      skillName = j_dizhi.name,
    }
  end,
})

return j_dizhi