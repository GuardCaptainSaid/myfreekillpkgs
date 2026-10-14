local j_qianxun = fk.CreateSkill {
  name = "j_qianxun",
}

Fk:loadTranslationTable{
  ["j_qianxun"] = "谦逊",
  [":j_qianxun"] = "当你成为一张牌的目标时，你可以弃置x张牌取消之。（x为本轮此技能发动次数加一）",

  ["#j_qianxun-invoke"] = "谦逊：是否弃置x张牌取消该牌效果？",

  ["$j_qianxun1"] = "谦谦君子，温润如玉。",
  ["$j_qianxun2"] = "退一步海阔天空。",
}

j_qianxun:addEffect(fk.TargetConfirmed, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_qianxun.name) then return false end

    local X = player:getMark("j_qianxun_count-round") or 0
    return #player:getCardIds("h") >= X + 1
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_qianxun.name, prompt = "#j_qianxun-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local X = player:getMark("j_qianxun_count-round") or 0
    player.room:setPlayerMark(player, "j_qianxun_count-round", X + 1)

    local cards = player.room:askToChooseCards(player, {
      target = player,
      flag = "h",
      skill_name = j_qianxun.name,
      min = X + 1,
      max = X + 1,
    })
    player.room:throwCard(cards, j_qianxun.name, player, player)

    data.use.nullifiedTargets = data.use.nullifiedTargets or {}
    table.insertIfNeed(data.use.nullifiedTargets, player)
  end,
})

return j_qianxun