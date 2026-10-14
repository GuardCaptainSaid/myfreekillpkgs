local j_bazheng = fk.CreateSkill {
  name = "j_bazheng",
}

Fk:loadTranslationTable{
  ["j_bazheng"] = "霸争",
  [":j_bazheng"] = "每回合每项限一次，当你使用红色牌指定其他角色为唯一目标，或其他角色使用红色牌指定你为唯一目标时，你可以将你与其区域内一种花色的牌全部置于牌堆顶（由你控制这些牌的排放顺序），失去牌多者视为对失去少者使用一张“决斗”并摸一张牌。",

  ["#j_bazheng-invoke"] = "霸争：是否发动？",
  ["#j_bazheng-suit"] = "霸争：选择一种花色",
  ["#j_bazheng-arrange"] = "霸争：将这些牌以任意顺序置于牌堆顶",
}

-- 每名角色回合开始时重置两项限制
-- 这里是纯记账，必须走静默的 refresh。
-- 若写成带 on_use 的触发效果而不给 on_cost，TriggerSkill:cost 会回退到
-- askToSkillInvoke（trigger.lua:101-110），于是每个角色回合开始时都会弹「是否发动」。
j_bazheng:addEffect(fk.EventPhaseStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(j_bazheng.name) and target.phase == Player.Start
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_bazheng1_used", 0)
    room:setPlayerMark(player, "j_bazheng2_used", 0)
  end,
})

j_bazheng:addEffect(fk.TargetSpecified, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_bazheng.name) then return false end
    local card = data.card
    if not card or card.color ~= Card.Red then return false end
    local tos = data.use and data.use.tos
    if not tos or #tos ~= 1 then return false end
    local the_other = tos[1]
    if not the_other then return false end

    -- 项一：你使用红色牌指定其他角色为唯一目标
    if data.from == player then
      if the_other == player then return false end
      return player:getMark("j_bazheng1_used") == 0
    end
    -- 项二：其他角色使用红色牌指定你为唯一目标（被指定目标必须是你本人）
    if the_other ~= player then return false end
    return player:getMark("j_bazheng2_used") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_bazheng.name, prompt = "#j_bazheng-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = event.room
    local tos = data.use and data.use.tos
    if not tos or #tos ~= 1 then return end
    local the_other = tos[1]

    local mark_name
    if data.from == player then
      the_other = the_other
      mark_name = "j_bazheng1_used"
    else
      -- 项二防御：被指定目标必须是你本人
      if the_other ~= player then return end
      the_other = data.from
      mark_name = "j_bazheng2_used"
    end
    if not the_other or the_other == player or not the_other:isAlive() then return end
    room:setPlayerMark(player, mark_name, 1)

    -- 选择一种花色
    local choice = room:askToChoice(player, {
      choices = { "log_spade", "log_heart", "log_club", "log_diamond" },
      skill_name = j_bazheng.name,
      prompt = "#j_bazheng-suit",
    })
    local suit
    if choice == "log_spade" then
      suit = Card.Spade
    elseif choice == "log_heart" then
      suit = Card.Heart
    elseif choice == "log_club" then
      suit = Card.Club
    else
      suit = Card.Diamond
    end

    -- 收集你与其区域内该花色的牌
    local card_ids = {}
    local me_lost, other_lost = 0, 0
    for _, p in ipairs{ player, the_other } do
      for _, cid in ipairs(p:getCardIds("hej")) do
        local c = Fk:getCardById(cid)
        if c and c.suit == suit then
          table.insert(card_ids, cid)
          if p == player then
            me_lost = me_lost + 1
          else
            other_lost = other_lost + 1
          end
        end
      end
    end
    if #card_ids == 0 then return end

    -- 由你控制排放顺序，置于牌堆顶（首张在最上方）
    local arranged = room:askToArrangeCards(player, {
      card_map = { card_ids },
      skill_name = j_bazheng.name,
      prompt = "#j_bazheng-arrange",
      free_arrange = true,
      min_limit = { #card_ids, 0 },
      max_limit = { #card_ids, 0 },
      area_names = { j_bazheng.name, "toObtain" },
    })
    local top_order = card_ids
    if arranged and type(arranged) == "table" then
      if type(arranged[1]) == "table" then
        top_order = arranged[1]
      else
        top_order = arranged
      end
    end
    for i = #top_order, 1, -1 do
      room:moveCardTo(top_order[i], Card.DrawPile, nil, fk.ReasonPut, j_bazheng.name)
    end

    -- 失去牌多者视为对失去少者使用一张“决斗”并摸一张牌
    if me_lost == other_lost then return end
    local winner, loser
    if me_lost > other_lost then
      winner, loser = player, the_other
    else
      winner, loser = the_other, player
    end
    local duel = Fk:cloneCard("duel")
    duel.skillName = j_bazheng.name
    room:useCard{ from = winner, tos = { loser }, card = duel }
    room:drawCards(winner, 1, j_bazheng.name)
  end,
})

return j_bazheng
