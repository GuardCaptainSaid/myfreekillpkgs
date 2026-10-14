local j_zhenlie = fk.CreateSkill {
  name = "j_zhenlie",
}

Fk:loadTranslationTable{
  ["j_zhenlie"] = "贞烈",
  [":j_zhenlie"] = "每回合限一次，当你成为其他角色使用【杀】或普通锦囊牌的唯一目标时，你可以弃置其一张牌并取消之，然后你对自己造成1点伤害。",

  ["#j_zhenlie-invoke"] = "贞烈：是否发动？",

  ["$j_zhenlie1"] = "虽是妇人，亦当奋身一搏！",
  ["$j_zhenlie2"] = "为雪前耻，不惜吾身！",
}

j_zhenlie:addEffect(fk.TargetConfirmed, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if player:usedEffectTimes(j_zhenlie.name, Player.HistoryPhase) > 0 then return false end
    local tos = data.use.tos or {}
    if #tos ~= 1 then return false end
    return target == player and player:hasSkill(j_zhenlie.name) and data.from ~= player and
      (data.card.trueName == "slash" or data.card:isCommonTrick())
  end,

  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_zhenlie.name,
      prompt = "#j_zhenlie-invoke",
    })
  end,

  on_use = function(self, event, target, player, data)
    local room = player.room
    local source = data.from

    if source.dead or source:isNude() then
      data.use.nullifiedTargets = data.use.nullifiedTargets or {}
      table.insertIfNeed(data.use.nullifiedTargets, player)
      room:damage{
        from = player,
        to = player,
        damage = 1,
        skillName = j_zhenlie.name,
      }
      return
    end

    local id = room:askToChooseCard(player, {
      target = source,
      flag = "he",
      skill_name = j_zhenlie.name,
    })

    if id then
      room:throwCard(id, j_zhenlie.name, source, player)
    end

    data.use.nullifiedTargets = data.use.nullifiedTargets or {}
    table.insertIfNeed(data.use.nullifiedTargets, player)

    room:damage{
      from = player,
      to = player,
      damage = 1,
      skillName = j_zhenlie.name,
    }
  end,
})

return j_zhenlie