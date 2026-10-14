local j_zhanhuo = fk.CreateSkill {
  name = "j_zhanhuo",
  tags = { Skill.Limited },
}

Fk:loadTranslationTable{
  ["j_zhanhuo"] = "绽火",
  [":j_zhanhuo"] = "限定技，出牌阶段，你可以弃置任意张牌，横置等量角色，并令其依次选择一项：1.弃置一张手牌；2.受到一点火焰伤害。",

  ["#j_zhanhuo-invoke"] = "绽火：是否发动限定技？",
  ["#j_zhanhuo-cards"] = "绽火：选择要弃置的牌",
  ["#j_zhanhuo-targets"] = "绽火：选择等量角色横置",
  ["#j_zhanhuo-choice"] = "绽火：选择一项",
  ["j_zhanhuo-option1"] = "弃置一张手牌",
  ["j_zhanhuo-option2"] = "受到一点火焰伤害",

  ["$j_zhanhuo1"] = "红莲烈火，焚尽一切！",
  ["$j_zhanhuo2"] = "绽放吧，烈火！",
}

j_zhanhuo:addEffect("active", {
  anim_type = "offensive",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0 and
      player:usedSkillTimes(j_zhanhuo.name, player.HistoryGame) == 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from

    local cards = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      skill_name = j_zhanhuo.name,
      prompt = "#j_zhanhuo-cards",
      min = 1,
      max = #player:getCardIds("h"),
    })
    if #cards == 0 then return end

    room:throwCard(cards, j_zhanhuo.name, player, player)

    local targets = room:askToChoosePlayers(player, {
      min_num = #cards,
      max_num = #cards,
      targets = room.alive_players,
      skill_name = j_zhanhuo.name,
      prompt = "#j_zhanhuo-targets",
      cancelable = false,
    })
    if #targets == 0 then return end

    for _, target in ipairs(targets) do
      target:setChainState(true)
    end

    for _, target in ipairs(targets) do
      if not target:isAlive() then goto continue end

      local choice = room:askToChoice(target, {
        choices = { "j_zhanhuo-option1", "j_zhanhuo-option2" },
        skill_name = j_zhanhuo.name,
        prompt = "#j_zhanhuo-choice",
        cancelable = false,
      })

      if choice == "j_zhanhuo-option1" then
        if #target:getCardIds("h") > 0 then
          local hand_card = room:askToChooseCard(target, {
            target = target,
            flag = "h",
            skill_name = j_zhanhuo.name,
          })
          if hand_card then
            room:throwCard(hand_card, j_zhanhuo.name, target, target)
          end
        else
          room:damage({
            from = player,
            to = target,
            damage = 1,
            damageType = fk.FireDamage,
            skillName = j_zhanhuo.name,
          })
        end
      else
        room:damage({
          from = player,
          to = target,
          damage = 1,
          damageType = fk.FireDamage,
          skillName = j_zhanhuo.name,
        })
      end

      ::continue::
    end
  end,
})

return j_zhanhuo