local j_zhixin = fk.CreateSkill {
  name = "j_zhixin",
  tags = { Skill.Switch },
}

Fk:loadTranslationTable{
  ["j_zhixin"] = "智心",
  [":j_zhixin"] = "转换技，每回合限一次。阳：你可以将一非基本牌当任意基本牌使用且不能被响应，若此牌未造成伤害，阳形态视为未发动过。阴：你可以将一基本牌当任一普通锦囊牌使用，若你不为此牌目标，你对一名目标角色造成一点伤害。",
  [":j_zhixin_yang"] = "转换技，<font color='#E0DB2F'>阳：你可以将一非基本牌当任意基本牌使用且不能被响应，若此牌未造成伤害，阳形态视为未发动过；</font><font color='grey'>阴：你可以将一基本牌当任一普通锦囊牌使用，若你不为此牌目标，你对一名目标角色造成一点伤害。</font>",
  [":j_zhixin_yin"] = "转换技，<font color='grey'>阳：你可以将一非基本牌当任意基本牌使用且不能被响应，若此牌未造成伤害，阳形态视为未发动过；</font><font color='#E0DB2F'>阴：你可以将一基本牌当任一普通锦囊牌使用，若你不为此牌目标，你对一名目标角色造成一点伤害。</font>",

  ["#j_zhixin-damage"] = "智心：选择一名目标角色造成一点伤害",

  ["$j_zhixin1"] = "运筹帷幄之中，决胜千里之外！",
  ["$j_zhixin2"] = "以智破敌，以心驭局！",
}

-- 普通锦囊候选（排除延时锦囊）
local function trick_names()
  local names = {}
  for _, name in ipairs(Fk:getAllCardNames("t", true)) do
    local proto = Fk.all_card_types[name]
    if proto and proto.type == Card.TypeTrick and proto.sub_type ~= Card.SubtypeDelayedTrick then
      table.insert(names, name)
    end
  end
  return names
end

local basic_names = { "slash", "jink", "peach", "analeptic" }

-- 智心：阴阳共用一个视为技，按当前形态决定转化方向
j_zhixin:addEffect("viewas", {
  anim_type = "offensive",
  card_num = 1,
  card_filter = function(self, player, to_select, selected, selected_targets)
    if #selected >= 1 then return false end
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    local card = Fk:getCardById(to_select)
    if player:getSwitchSkillState(j_zhixin.name) == fk.SwitchYang then
      return card.type ~= Card.TypeBasic
    else
      return card.type == Card.TypeBasic
    end
  end,
  interaction = function(self, player)
    if player:getSwitchSkillState(j_zhixin.name) == fk.SwitchYang then
      return UI.CardNameBox { choices = basic_names, all_choices = basic_names }
    else
      local tricks = trick_names()
      return UI.CardNameBox { choices = tricks, all_choices = tricks }
    end
  end,
  view_as = function(self, player, cards)
    if player:getMark("j_zhixin_used") ~= 0 then return end
    if #cards ~= 1 or not self.interaction.data then return end
    local card = Fk:cloneCard(self.interaction.data)
    card.skillName = j_zhixin.name
    card:addSubcard(cards[1])
    return card
  end,
  can_use = function(self, player)
    return player:getMark("j_zhixin_used") == 0
  end,
  enabled_at_play = function(self, player)
    return player:getMark("j_zhixin_used") == 0
  end,
  after_use = function(self, player, use)
    -- 阴转化（锦囊）：使用即消耗本回合限次；阳转化（基本牌）等出牌阶段结束时判定
    local proto = use and use.card and Fk.all_card_types[use.card.trueName]
    if proto and proto.type == Card.TypeTrick then
      player.room:setPlayerMark(player, "j_zhixin_yin_used", 1)
      player.room:setPlayerMark(player, "j_zhixin_used", 1)
    end
  end,
})

-- 阳转化的基本牌不能被响应
j_zhixin:addEffect(fk.PreCardUse, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zhixin.name) then return false end
    if not data.card then return false end
    return data.card.skillName == j_zhixin.name and data.card.type == Card.TypeBasic
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data.disresponsiveList = table.simpleClone(player.room.players)
  end,
})

-- 智心转化牌造成伤害：记录（阳成功发动，限次消耗）
j_zhixin:addEffect(fk.Damaged, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if data.from ~= player then return false end
    if not data.card or data.card.skillName ~= j_zhixin.name then return false end
    return player:hasSkill(j_zhixin.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_zhixin_damaged", 1)
    player.room:setPlayerMark(player, "j_zhixin_used", 1)
  end,
})

-- 出牌阶段结束：阳转化未造成伤害则视为未发动（形态翻回阳、限次不消耗）
j_zhixin:addEffect(fk.EventPhaseEnd, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_zhixin.name) and player.phase == Player.Play
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local yin_used = player:getMark("j_zhixin_yin_used") == 1
    if not yin_used and player:getMark("j_zhixin_damaged") == 0 then
      -- 阳使用后已自动翻转为阴形态 → 翻回阳
      if player:getSwitchSkillState(j_zhixin.name) == fk.SwitchYin then
        local pre = MarkEnum.SwithSkillPreName .. j_zhixin.name
        local cur = player:getMark(pre)
        room:setPlayerMark(player, pre, cur < 1 and 1 or 0)
      end
      room:setPlayerMark(player, "j_zhixin_used", 0)
    end
    room:setPlayerMark(player, "j_zhixin_damaged", 0)
    room:setPlayerMark(player, "j_zhixin_yin_used", 0)
  end,
})

-- 回合开始：重置本回合限次
j_zhixin:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_zhixin.name) and player.phase == Player.Start
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_zhixin_used", 0)
    player.room:setPlayerMark(player, "j_zhixin_damaged", 0)
    player.room:setPlayerMark(player, "j_zhixin_yin_used", 0)
  end,
})

-- 阴转化（锦囊）结算完成：若自身不是目标，对一名目标角色造成一点伤害
j_zhixin:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not data or not data.card then return false end
    if data.card.skillName ~= j_zhixin.name then return false end
    if data.from ~= player then return false end
    if not player:hasSkill(j_zhixin.name) then return false end
    local proto = Fk.all_card_types[data.card.trueName]
    if not proto or proto.type ~= Card.TypeTrick then return false end
    if not data.tos or #data.tos == 0 then return false end
    return not table.contains(data.tos, player)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local victims = {}
    for _, p in ipairs(data.tos) do
      if p:isAlive() then
        table.insert(victims, p)
      end
    end
    if #victims == 0 then return end
    local t = room:askToChoosePlayers(player, {
      targets = victims,
      min_num = 1,
      max_num = 1,
      skill_name = j_zhixin.name,
      prompt = "#j_zhixin-damage",
    })
    if t and #t > 0 then
      room:damage{ from = player, to = t[1], damage = 1, damageType = fk.NormalDamage, skillName = j_zhixin.name, card = data.card }
    end
  end,
})

return j_zhixin
