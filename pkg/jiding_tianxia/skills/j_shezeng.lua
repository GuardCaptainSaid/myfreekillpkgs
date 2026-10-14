local j_shezeng = fk.CreateSkill {
  name = "j_shezeng",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_shezeng"] = "奢赠",
  [":j_shezeng"] = "锁定技，游戏开始时，你将四张【指仓相赠】加入牌堆。",
}

j_shezeng:addEffect(fk.GameStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_shezeng.name, true)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local suits = { Card.Spade, Card.Heart, Card.Club, Card.Diamond }
    for i = 1, 4 do
      local card = Fk:cloneCard("j_zicangxiangzeng", suits[math.random(#suits)], math.random(1, 13))
      table.insert(room.draw_pile, card.id)
      room:setCardArea(card.id, Card.DrawPile)
    end
    table.shuffle(room.draw_pile)
  end,
})

return j_shezeng
