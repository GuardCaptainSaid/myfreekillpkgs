local j_huaxin = fk.CreateSkill {
  name = "j_huaxin",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_huaxin"] = "化薪",
  [":j_huaxin"] = "锁定技，你使用伤害类牌时失去一点体力或两点体力上限，然后令此牌额外结算一次或不可被响应。你每造成一点伤害便摸一张牌。",

  ["#j_huaxin-cost"] = "化薪：选择失去一点体力或两点体力上限",
  ["#j_huaxin-effect"] = "化薪：选择额外结算一次或不可被响应",
  ["j_huaxin-option1"] = "失去一点体力",
  ["j_huaxin-option2"] = "失去两点体力上限",
  ["j_huaxin-effect1"] = "额外结算一次",
  ["j_huaxin-effect2"] = "不可被响应",

  ["$j_huaxin1"] = "燃烧自己，照亮前路！",
  ["$j_huaxin2"] = "以身为薪，焚尽敌寇！",
}

local DAMAGE_CARDS = { "slash", "fire_attack", "duel", "archery_attack", "lightning", "thunder_strike" }

local function is_damage_card(card)
  return table.contains(DAMAGE_CARDS, card.trueName)
end

j_huaxin:addEffect(fk.CardUsing, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if data.card:getMark("j_huaxin_no_cost") == 1 then
      return false
    end
    return target == player and player:hasSkill(j_huaxin.name) and is_damage_card(data.card)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room

    local cost_choice = room:askToChoice(player, {
      choices = { "j_huaxin-option1", "j_huaxin-option2" },
      skill_name = j_huaxin.name,
      prompt = "#j_huaxin-cost",
      cancelable = false,
    })

    if cost_choice == "j_huaxin-option1" then
      room:damage({
        from = player,
        to = player,
        damage = 1,
        skillName = j_huaxin.name,
      })
    else
      room:changeMaxHp(player, -2)
    end

    if player.dead then return end

    local effect_choice = room:askToChoice(player, {
      choices = { "j_huaxin-effect1", "j_huaxin-effect2" },
      skill_name = j_huaxin.name,
      prompt = "#j_huaxin-effect",
      cancelable = false,
    })

    if effect_choice == "j_huaxin-effect1" then
      room:setCardMark(data.card, "j_huaxin_extra", 1)
    else
      data.disresponsiveList = table.simpleClone(room.alive_players)
    end
  end,
})

j_huaxin:addEffect(fk.CardUseFinished, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_huaxin.name) and data.card:getMark("j_huaxin_extra") == 1
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setCardMark(data.card, "j_huaxin_extra", 0)
    room:setCardMark(data.card, "j_huaxin_no_cost", 1)
    room:useCard{
      card = data.card,
      from = player,
      tos = data.tos,
      skillName = j_huaxin.name,
      extraUse = true,
    }
    room:setCardMark(data.card, "j_huaxin_no_cost", 0)
  end,
})

j_huaxin:addEffect(fk.Damaged, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_huaxin.name) and data.damage > 0 and data.from == player
  end,
  on_use = function(self, event, target, player, data)
    player.room:drawCards(player, data.damage, j_huaxin.name)
  end,
})

return j_huaxin