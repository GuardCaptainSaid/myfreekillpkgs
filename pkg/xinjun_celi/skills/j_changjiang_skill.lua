-- 长江天堑·装备技能：当你需要使用/打出【闪】时，你可以进行判定，若结果为黑色，你视为使用/打出一张【闪】。
local j_changjiang_skill = fk.CreateSkill {
  name = "#j_changjiang_skill",
  attached_equip = "j_changjiang",
}

Fk:loadTranslationTable{
  ["#j_changjiang_skill"] = "长江天堑",
}

local spec = function(self, event, target, player, data)
  local room = player.room
  local judgeData = {
    who = player,
    reason = j_changjiang_skill.name,
    pattern = ".|.|black",
  }
  room:judge(judgeData)

  if judgeData:matchPattern() then
    local new_card = Fk:cloneCard('jink')
    new_card.skillName = "j_changjiang"
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

j_changjiang_skill:addEffect(fk.AskForCardUse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_changjiang_skill.name) and
      Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none") and
      not player:prohibitUse(Fk:cloneCard("jink"))
      and (data.extraData == {} or data.extraData.not_passive ~= true)
  end,
  on_use = spec,
})

j_changjiang_skill:addEffect(fk.AskForCardResponse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_changjiang_skill.name) and
      Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none") and
      not player:prohibitResponse(Fk:cloneCard("jink"))
  end,
  on_use = spec,
})

return j_changjiang_skill