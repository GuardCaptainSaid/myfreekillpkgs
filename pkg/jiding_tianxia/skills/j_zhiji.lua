local j_zhiji = fk.CreateSkill {
  name = "j_zhiji",
}

Fk:loadTranslationTable{
  ["j_zhiji"] = "智计",
  [":j_zhiji"] = "每回限一次，你可以将一张红色/黑色牌当做不能被抵消的【火攻】/【无懈可击】使用。",

  ["#j_zhiji-prompt"] = "智计：将一张红色牌当【火攻】或将一张黑色牌当【无懈可击】使用",

  ["$j_zhiji1"] = "计出万全，算无遗策！",
  ["$j_zhiji2"] = "运筹帷幄，决胜千里！",
}

-- 智计：红牌→火攻、黑牌→无懈可击，不能被抵消
j_zhiji:addEffect("viewas", {
  anim_type = "offensive",
  card_num = 1,
  card_filter = function(self, player, to_select, selected, selected_targets)
    if #selected >= 1 then return false end
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    local card = Fk:getCardById(to_select)
    if card.color == Card.NoColor then return false end
    if self.interaction.data == "fire_attack" then
      return card.color == Card.Red
    elseif self.interaction.data == "nullification" then
      return card.color == Card.Black
    end
    return true
  end,
  interaction = function(self, player)
    return UI.CardNameBox { choices = { "fire_attack", "nullification" }, all_choices = { "fire_attack", "nullification" } }
  end,
  view_as = function(self, player, cards)
    if player:getMark("j_zhiji_used") ~= 0 then return end
    if #cards ~= 1 or not self.interaction.data then return end
    local card = Fk:cloneCard(self.interaction.data)
    card.skillName = j_zhiji.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    return player:getMark("j_zhiji_used") == 0
  end,
  after_use = function(self, player, use)
    player.room:setPlayerMark(player, "j_zhiji_used", 1)
  end,
})

-- 智计转化的牌不能被抵消（不可被响应）
j_zhiji:addEffect(fk.PreCardUse, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zhiji.name) then return false end
    if not data.card or data.card.skillName ~= j_zhiji.name then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data.disresponsiveList = table.simpleClone(player.room.players)
  end,
})

-- 每回合开始重置限次
j_zhiji:addEffect(fk.EventPhaseStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_zhiji.name) and player.phase == Player.Play
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_zhiji_used", 0)
  end,
})

return j_zhiji
