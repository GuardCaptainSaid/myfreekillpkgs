local j_liebei = fk.CreateSkill({
  name = "j_liebei",
  tags = { Skill.Compulsory },
})

Fk:loadTranslationTable{
  ["j_liebei"] = "烈北",
  [":j_liebei"] = "锁定技，你的攻击范围和出牌阶段内可使用【杀】的次数均加X（X为回合开始时你已损失体力值）。出牌阶段你使用杀的次数达到上限时，你增加一点体力上限。",

  ["$j_liebei1"] = "北地狼烟，燃尽敌寇！",
  ["$j_liebei2"] = "纵使身死，亦不退却！",
}

j_liebei:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_liebei.name) and player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local X = player:getLostHp()
    player.room:setPlayerMark(player, "j_liebei_X-turn", X)
    player.room:setPlayerMark(player, "j_liebei_slash_used-turn", 0)
    player.room:setPlayerMark(player, "j_liebei_maxed-turn", 0)
  end,
})

j_liebei:addEffect(fk.CardUsing, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_liebei.name) and
      data.card.trueName == "slash" and player.phase == Player.Play
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local used = player:getMark("j_liebei_slash_used-turn") or 0
    room:setPlayerMark(player, "j_liebei_slash_used-turn", used + 1)

    local X = player:getMark("j_liebei_X-turn") or 0
    if used + 1 >= 1 + X and player:getMark("j_liebei_maxed-turn") == 0 then
      room:setPlayerMark(player, "j_liebei_maxed-turn", 1)
      room:changeMaxHp(player, 1)
    end
  end,
})

j_liebei:addEffect("distance", {
  correct_func = function(self, from, to)
    if from:hasSkill(j_liebei.name) then
      return -(from:getMark("j_liebei_X-turn") or 0)
    end
    return 0
  end,
})

j_liebei:addEffect("targetmod", {
  residue_func = function(self, player, skill, scope, card)
    if not player:hasSkill(j_liebei.name) then return nil end
    if card and card.trueName == "slash" then
      return player:getMark("j_liebei_X-turn") or 0
    end
    return nil
  end,
})

return j_liebei