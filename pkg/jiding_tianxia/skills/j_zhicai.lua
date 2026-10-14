local j_zhicai = fk.CreateSkill {
  name = "j_zhicai",
  tags = { Skill.Switch },
}

Fk:loadTranslationTable{
  ["j_zhicai"] = "智才",
  [":j_zhicai"] = "转换技，阳：你受到一点伤害时，你摸两张牌并令一名角色的手牌上限加二直到你的下回合结束，若其的下个弃牌阶段没有弃置牌，你令其摸两张牌；阴：准备阶段，你亮出牌堆顶的两张牌并获得其中一张，然后本回合你可以将此牌当任一单目标普通锦囊牌使用，使用与此牌颜色不同的手牌时摸一张牌。",
  [":j_zhicai_yang"] = "转换技，<font color='#E0DB2F'>阳：你受到一点伤害时，你摸两张牌并令一名角色的手牌上限加二直到你的下回合结束，若其的下个弃牌阶段没有弃置牌，你令其摸两张牌；</font><font color='grey'>阴：准备阶段，你亮出牌堆顶的两张牌并获得其中一张，然后本回合你可以将此牌当任一单目标普通锦囊牌使用，使用与此牌颜色不同的手牌时摸一张牌。</font>",
  [":j_zhicai_yin"] = "转换技，<font color='grey'>阳：你受到一点伤害时，你摸两张牌并令一名角色的手牌上限加二直到你的下回合结束，若其的下个弃牌阶段没有弃置牌，你令其摸两张牌；</font><font color='#E0DB2F'>阴：准备阶段，你亮出牌堆顶的两张牌并获得其中一张，然后本回合你可以将此牌当任一单目标普通锦囊牌使用，使用与此牌颜色不同的手牌时摸一张牌。</font>",

  ["#j_zhicai-target"] = "智才：选择一名角色",
  ["#j_zhicai-select"] = "智才：选择一张牌获得",
  ["#j_zhicai-viewas"] = "智才：选择一张单目标普通锦囊牌",
  ["#j_zhicai-convert"] = "智才：是否将此牌当一张单目标普通锦囊牌使用？",

  ["$j_zhicai1"] = "运筹帷幄，决胜千里！",
  ["$j_zhicai2"] = "才识过人，智计无双！",
}

j_zhicai:addEffect(fk.Damaged, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_zhicai.name) and
      player:getSwitchSkillState(j_zhicai.name) == fk.SwitchYang and
      data.damage >= 1
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_zhicai.name })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:drawCards(player, 2, j_zhicai.name)

    local targets = room:getAlivePlayers()
    local target = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = j_zhicai.name,
      prompt = "#j_zhicai-target",
    })
    if target and #target > 0 then
      target = target[1]
      room:setPlayerMark(target, MarkEnum.AddMaxCards, 2)
      room:setPlayerMark(target, "j_zhicai_check_discard", 1)
      room:setPlayerMark(target, "j_zhicai_caster", player.id)
      room:setPlayerMark(target, "j_zhicai_discard_count", 0)
    end
  end,
})

j_zhicai:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player:getMark("j_zhicai_check_discard") ~= 1 then return false end
    for _, move in ipairs(data) do
      if move.from == player and move.toArea == Card.DiscardPile then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local count = player:getMark("j_zhicai_discard_count") or 0
    local add = 0
    for _, move in ipairs(data) do
      if move.from == player and move.toArea == Card.DiscardPile then
        add = add + #move.moveInfo
      end
    end
    player.room:setPlayerMark(player, "j_zhicai_discard_count", count + add)
  end,
})

j_zhicai:addEffect(fk.EventPhaseEnd, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player.phase == Player.Discard and
      player:getMark("j_zhicai_check_discard") == 1
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local caster_id = player:getMark("j_zhicai_caster")
    local discard_num = player:getMark("j_zhicai_discard_count") or 0
    if caster_id > 0 and discard_num == 0 then
      local caster = room:getPlayerById(caster_id)
      if caster and caster:isAlive() then
        room:drawCards(player, 2, j_zhicai.name)
      end
    end
    room:setPlayerMark(player, "j_zhicai_check_discard", 0)
    room:setPlayerMark(player, "j_zhicai_discard_count", 0)
  end,
})

j_zhicai:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_zhicai.name) and
      player:getSwitchSkillState(j_zhicai.name) == fk.SwitchYin and
      player.phase == Player.Start
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_zhicai.name })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_zhicai_special_card", 0)
    room:setPlayerMark(player, "j_zhicai_special_color", 0)

    local cards = room:getNCards(2)
    if #cards >= 2 then
      room:showCards(cards, player, j_zhicai.name)
      local selected = room:askToChooseCardsAndChoice(player, {
        cards = cards,
        choices = {"OK"},
        skill_name = j_zhicai.name,
        prompt = "#j_zhicai-select",
        min_num = 1,
        max_num = 1,
      })
      if selected and #selected > 0 then
        local selected_id = selected[1]
        local card = Fk:getCardById(selected_id)
        room:obtainCard(player, card, true, fk.ReasonDraw, player, j_zhicai.name)
        room:setPlayerMark(player, "j_zhicai_special_card", selected_id)
        room:setPlayerMark(player, "j_zhicai_special_color", card.color)
        for _, cid in ipairs(cards) do
          if cid ~= selected_id then
            room:moveCardTo(cid, Card.DiscardPile, nil, fk.ReasonPut, j_zhicai.name)
          end
        end
      else
        room:moveCardTo(cards, Card.DiscardPile, nil, fk.ReasonPut, j_zhicai.name)
      end
    end
  end,
})

j_zhicai:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_zhicai.name) and player.phase == Player.Start
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room.alive_players) do
      if p:getMark("j_zhicai_caster") == player.id then
        room:setPlayerMark(p, MarkEnum.AddMaxCards, 0)
        room:setPlayerMark(p, "j_zhicai_caster", 0)
        room:setPlayerMark(p, "j_zhicai_check_discard", 0)
        room:setPlayerMark(p, "j_zhicai_discard_count", 0)
      end
    end
  end,
})

-- 单目标普通锦囊候选（排除延时锦囊、AOE、无中、被动响应牌）
local function single_target_tricks()
  local names = {}
  for _, name in ipairs(Fk:getAllCardNames("t")) do
    local proto = Fk.all_card_types[name]
    if proto and proto.type == Card.TypeTrick and proto.sub_type ~= Card.SubtypeDelayedTrick then
      local cs = proto.skill
      -- 仅保留：恰好 1 个目标、且可主动使用（排除无懈等被动响应牌）
      if cs and cs.target_num == 1 and cs.canUse ~= Util.FalseFunc then
        table.insert(names, name)
      end
    end
  end
  return names
end

-- 智才阴：使用特殊牌时拦截，弹窗询问是否当单目标普通锦囊使用（无主动技按钮）
j_zhicai:addEffect(fk.PreCardUse, {
  anim_type = "switch",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zhicai.name) then return false end
    local sid = player:getMark("j_zhicai_special_card")
    if not sid or sid == 0 then return false end
    if not data.card then return false end
    return table.contains(Card:getIdList(data.card), sid)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    return room:askToSkillInvoke(player, {
      skill_name = j_zhicai.name,
      prompt = "#j_zhicai-convert",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local names = single_target_tricks()
    if #names == 0 then return end
    local choice = room:askToChoice(player, {
      choices = names,
      skill_name = j_zhicai.name,
      prompt = "#j_zhicai-viewas",
      cancelable = false,
    })
    if not choice then return end

    local new_card = Fk:cloneCard(choice)
    new_card.skillName = j_zhicai.name
    new_card.id = data.card.id
    local sub = Card:getIdList(data.card)
    if #sub > 0 then
      new_card:addSubcards(sub)
    else
      new_card:addSubcard(data.card.id)
    end

    -- 过滤该锦囊的合法目标（单目标）
    local cs = new_card:getSkill(player)
    local valid = {}
    for _, p in ipairs(room.alive_players) do
      if cs:targetFilter(player, p, {}, new_card.subcards, new_card, nil) then
        table.insert(valid, p)
      end
    end
    if #valid == 0 then return end

    local chosen = room:askToChoosePlayers(player, {
      targets = valid,
      min_num = 1,
      max_num = 1,
      skill_name = j_zhicai.name,
      prompt = "#j_zhicai-target",
    })
    if not chosen or #chosen == 0 then return end

    data.card = new_card
    data.tos = { chosen[1] }
    -- 特殊牌已使用，清除牌标记；颜色标记保留到回合结束（本回合内使用不同色手牌仍可摸牌）
    room:setPlayerMark(player, "j_zhicai_special_card", 0)
  end,
})

-- 回合结束：清理阴效果的颜色标记（本回合有效期止）
j_zhicai:addEffect(fk.TurnEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_zhicai.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_zhicai_special_card", 0)
    player.room:setPlayerMark(player, "j_zhicai_special_color", 0)
  end,
})

j_zhicai:addEffect(fk.CardUsing, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    local special_color = player:getMark("j_zhicai_special_color")
    if not special_color or special_color == 0 then return false end
    if not data.card then return false end
    if not data:isUsingHandcard(player) then return false end
    local used_color
    local sub = data.card.subcards and data.card.subcards[1]
    if sub then
      used_color = Fk:getCardById(sub).color
    else
      used_color = data.card.color
    end
    if used_color == 0 or used_color == special_color then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:drawCards(player, 1, j_zhicai.name)
  end,
})

return j_zhicai
