local bazhen = fk.CreateSkill {
  name = "bazhen",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["bazhen"] = "八阵",
  [":bazhen"] = "锁定技，若你没有装备防具，你视为装备着【八卦阵】。",
}

local bazhen_on_use = function(self, event, target, player, data)
  local room = player.room
  local judgeData = {
    who = player,
    reason = bazhen.name,
    pattern = ".|.|red",
  }
  room:judge(judgeData)
  if judgeData:matchPattern() then
    local new_card = Fk:cloneCard("jink")
    new_card.skillName = bazhen.name
    local result = {
      from = player,
      card = new_card,
    }
    if event:isInstanceOf(fk.AskForCardUse) then
      result.tos = {}
    end
    data.result = result
    return true
  end
end

bazhen:addEffect(fk.AskForCardUse, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(bazhen.name) and
      Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none") and
      not player:getEquipment(Card.SubtypeArmor)
  end,
  on_use = bazhen_on_use,
})

bazhen:addEffect(fk.AskForCardResponse, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(bazhen.name) and
      Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none") and
      not player:getEquipment(Card.SubtypeArmor)
  end,
  on_use = bazhen_on_use,
})

return bazhen