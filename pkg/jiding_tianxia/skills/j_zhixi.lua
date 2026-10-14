local j_zhixi = fk.CreateSkill {
  name = "j_zhixi",
}

Fk:loadTranslationTable{
  ["j_zhixi"] = "质玺",
  [":j_zhixi"] = "出牌阶段或你受到伤害后，你可以弃置至少X张牌（X为本轮游戏进入弃牌堆的花色数且至少为2），然后你摸三张牌。",

  ["#j_zhixi-invoke"] = "质玺：是否弃置至少X张牌，然后摸三张牌？",
  ["#j_zhixi-discard"] = "质玺：弃置至少%arg2张牌，然后摸三张牌",
}

local function zhixi_trigger(player)
  local room = player.room
  local suits = player:getTableMark("j_zhixi_suits")
  local x = math.max(#suits, 2)
  local hand = player:getCardIds("h")
  if #hand == 0 then return end

  local min_x = math.min(x, #hand)
  local discarded = room:askToDiscard(player, {
    min_num = min_x,
    max_num = #hand,
    skill_name = j_zhixi.name,
    prompt = "#j_zhixi-discard:::" .. #hand .. ":" .. min_x,
  })
  if #discarded > 0 then
    room:drawCards(player, 3, j_zhixi.name)
  end
end

-- 主动释放：出牌阶段点击技能按钮，直接进入选牌，无需询问
j_zhixi:addEffect("active", {
  anim_type = "drawcard",
  card_num = 0,
  can_use = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0
  end,
  on_use = function(self, room, effect)
    zhixi_trigger(effect.from)
  end,
})

-- 你受到伤害后（被动技，唯一弹窗时机；仅限回合外）
j_zhixi:addEffect(fk.Damaged, {
  global = true,
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_zhixi.name) then return false end
    if target ~= player then return false end
    -- 回合内由上面的主动技负责，此处必须排除自己的回合，
    -- 否则在自己的回合内受伤会额外弹一次询问（即“回合内违规弹窗”）。
    if player.room.current == player then return false end
    return data.damage >= 1
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_zhixi.name, prompt = "#j_zhixi-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    zhixi_trigger(player)
  end,
})

-- 记录本轮进入弃牌堆的花色（静默refresh，不弹任何询问）
j_zhixi:addEffect(fk.AfterCardsMove, {
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(j_zhixi.name)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local suits = player:getTableMark("j_zhixi_suits")
    local changed = false
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo) do
          local card = Fk:getCardById(info.cardId)
          if card and card.suit >= Card.Spade and card.suit <= Card.Diamond
            and not table.contains(suits, card.suit) then
            table.insert(suits, card.suit)
            changed = true
          end
        end
      end
    end
    if changed then
      room:setPlayerMark(player, "j_zhixi_suits", suits)
    end
  end,
})

-- 每轮开始重置花色记录（静默refresh）
j_zhixi:addEffect(fk.RoundStart, {
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(j_zhixi.name)
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_zhixi_suits", {})
  end,
})

return j_zhixi
