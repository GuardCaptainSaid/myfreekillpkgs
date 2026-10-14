local j_yanshi = fk.CreateSkill {
  name = "j_yanshi",
}

Fk:loadTranslationTable{
  ["j_yanshi"] = "演势",
  [":j_yanshi"] = "出牌阶段限一次，你可以从牌堆顶或牌堆底摸一张牌并使用，若因此使用以此法获得的牌，此技能视为未发动过。",

  ["#j_yanshi-draw"] = "演势：选择从牌堆顶或牌堆底摸一张牌",
  ["#j_yanshi-use"] = "演势：你可以使用摸到的牌",
  ["j_yanshi:top"] = "从牌堆顶摸牌",
  ["j_yanshi:bottom"] = "从牌堆底摸牌",

  ["$j_yanshi1"] = "卧龙待时，一鸣惊人！",
  ["$j_yanshi2"] = "静观其变，乘势而起！",
}

-- 演势：主动技，摸一张并使用，使用摸到的牌则不消耗限次
j_yanshi:addEffect("active", {
  anim_type = "draw",
  card_num = 0,
  can_use = function(self, player)
    if player:getMark("j_yanshi_used") ~= 0 then return false end
    return player.phase == Player.Play
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    -- 标记已发动（若使用摸到的牌则视为未发动）
    room:setPlayerMark(player, "j_yanshi_used", 1)
    local choice = room:askToChoice(player, {
      choices = { "j_yanshi:top", "j_yanshi:bottom" },
      skill_name = j_yanshi.name,
      prompt = "#j_yanshi-draw",
    })
    local fromPlace = choice == "j_yanshi:bottom" and "bottom" or "top"

    -- 摸一张（drawCards 返回摸到的牌 id）
    local ids = player:drawCards(1, j_yanshi.name, fromPlace)
    local drawnId = ids and ids[1]
    if drawnId then
      -- 记录摸到的牌：若使用它则视为未发动
      local drawn = room:getTag("j_yanshi_drawn") or {}
      drawn[drawnId] = true
      room:setTag("j_yanshi_drawn", drawn)
      -- 尝试使用该牌
      room:askToUseCard(player, {
        pattern = Fk:getCardById(drawnId).name,
        skill_name = j_yanshi.name,
        prompt = "#j_yanshi-use",
        cancelable = true,
      })
    end
  end,
})

-- 使用了摸到的牌 → 视为未发动过（限次不消耗）
j_yanshi:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_yanshi.name) then return false end
    if player:getMark("j_yanshi_used") ~= 1 then return false end
    if not data or not data.card then return false end
    local drawn = player.room:getTag("j_yanshi_drawn") or {}
    for _, id in ipairs(data.card.subcards or {}) do
      if drawn[id] then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_yanshi_used", 0)
  end,
})

-- 每回合开始重置限次
j_yanshi:addEffect(fk.EventPhaseStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_yanshi.name) and player.phase == Player.Play
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_yanshi_used", 0)
  end,
})

return j_yanshi
