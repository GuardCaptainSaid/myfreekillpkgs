local j_miji = fk.CreateSkill {
  name = "j_miji",
}

Fk:loadTranslationTable{
  ["j_miji"] = "秘计",
  [":j_miji"] = "当你受到伤害或回合结束时，你可以进行判定，若结果为：<font color='black'>黑色</font>，你观看牌堆顶的X张牌（X为你已损失的体力值），然后将这些牌交给一名角色；<font color='red'>红色</font>，你获得判定牌（不计入手牌上限）。出牌阶段，你可以将一张有“秘计”标记的牌当作任意基本牌使用。",

  ["#j_miji-invoke"] = "秘计：是否进行判定？",
  ["#j_miji-choose"] = "秘计：选择一名角色获得“秘计”牌",
  ["#j_miji-viewas"] = "秘计：选择一张有标记的牌当作基本牌使用",
  ["@j_miji_red"] = "秘计",

  ["$j_miji1"] = "奇谋，只在绝境中诞生！",
  ["$j_miji2"] = "我将尽我所能！",
}

local function j_miji_trigger(player)
  local room = player.room
  local judge = {
    who = player,
    reason = j_miji.name,
    pattern = ".|.|black",
  }
  room:judge(judge)

  if judge:matchPattern() then
    local n = player:getLostHp()
    if n <= 0 or player.dead then return end

    local cards = room:getNCards(n)
    room:viewCards(player, {
      cards = cards,
      skill_name = j_miji.name,
    })

    local to = room:askToChoosePlayers(player, {
      targets = room.alive_players,
      min_num = 1,
      max_num = 1,
      skill_name = j_miji.name,
      prompt = "#j_miji-choose",
    })
    if #to > 0 then
      room:obtainCard(to[1], cards, true, fk.ReasonGive, player, j_miji.name)
    end
  else
    if player.dead then return end

    local judge_card = judge.card
    room:setCardMark(judge_card, "@j_miji_red", 1)
    room:obtainCard(player, judge_card, true, fk.ReasonJustMove, player, j_miji.name)
  end
end

j_miji:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_miji.name)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_miji.name, prompt = "#j_miji-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    j_miji_trigger(player)
  end,
})

j_miji:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_miji.name) and player.phase == Player.Finish
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_miji.name, prompt = "#j_miji-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    j_miji_trigger(player)
  end,
})

j_miji:addEffect("viewas", {
  anim_type = "offensive",
  prompt = "#j_miji-viewas",
  pattern = "peach,slash,jink,analeptic",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    local card = Fk:getCardById(to_select)
    return card:getMark("@j_miji_red") == 1
  end,
  interaction = function(self, player)
    local card_names = { "slash", "peach", "jink", "analeptic" }
    local choices = {}
    for _, name in ipairs(card_names) do
      table.insert(choices, Fk:translate(name))
    end
    return UI.ComboBox { choices = choices }
  end,
  view_as = function(self, player, cards)
    if not self.interaction.data or #cards ~= 1 then return nil end
    local card = Fk:getCardById(cards[1])
    if card:getMark("@j_miji_red") ~= 1 then return nil end

    local card_names = { "slash", "peach", "jink", "analeptic" }
    local card_name = nil
    for _, name in ipairs(card_names) do
      if Fk:translate(name) == self.interaction.data then
        card_name = name
        break
      end
    end

    if not card_name then return nil end

    local new_card = Fk:cloneCard(card_name)
    new_card:addSubcard(cards[1])
    new_card.skillName = j_miji.name
    return new_card
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play
  end,
  enabled_at_response = function(self, player, response)
    return false
  end,
  before_use = function(self, player, use)
    local card = Fk:getCardById(use.card.subcards[1])
    if card then
      player.room:setCardMark(card, "@j_miji_red", 0)
    end
  end,
})

j_miji:addEffect("maxcards", {
  exclude_from = function(self, player, card)
    return card:getMark("@j_miji_red") == 1
  end,
})

return j_miji
