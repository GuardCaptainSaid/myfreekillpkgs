local j_jizhi = fk.CreateSkill {
  name = "j_jizhi",
}

Fk:loadTranslationTable{
  ["j_jizhi"] = "计智",
  [":j_jizhi"] = "出牌阶段，你可将X+1张花色不同的手牌当作一张本轮未使用过的普通锦囊牌使用。（X为本轮此技能发动的次数）",

  ["#j_jizhi-viewas"] = "计智：选择X+1张花色不同的手牌",

  ["$j_jizhi1"] = "运筹帷幄，决胜千里！",
  ["$j_jizhi2"] = "以智取胜，方为上策。",
}

-- 本轮未使用过的普通锦囊候选（核心自动按牌名记录本轮使用历史）
local function available_tricks(player)
  local names = {}
  for _, name in ipairs(Fk:getAllCardNames("t", true)) do
    if player:usedCardTimes(name, Player.HistoryRound) == 0 then
      table.insert(names, name)
    end
  end
  return names
end

j_jizhi:addEffect("viewas", {
  anim_type = "offensive",
  prompt = "#j_jizhi-viewas",
  pattern = ".",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    local X = player:getMark("j_jizhi_count-round") or 0
    if #selected >= X + 1 then return false end
    if not table.contains(player:getHandlyIds(), to_select) then return false end

    local card = Fk:getCardById(to_select)
    local suit = card.suit
    for _, cid in ipairs(selected) do
      if Fk:getCardById(cid).suit == suit then
        return false
      end
    end
    return true
  end,
  interaction = function(self, player)
    return UI.CardNameBox { choices = available_tricks(player) }
  end,
  view_as = function(self, player, cards)
    if not self.interaction.data or #cards < 1 then return nil end

    local X = player:getMark("j_jizhi_count-round") or 0
    if #cards ~= X + 1 then return nil end

    local suits = {}
    for _, cid in ipairs(cards) do
      local suit = Fk:getCardById(cid).suit
      if suits[suit] then return nil end
      suits[suit] = true
    end

    local new_card = Fk:cloneCard(self.interaction.data)
    new_card:addSubcards(cards)
    new_card.skillName = j_jizhi.name
    return new_card
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play
  end,
  enabled_at_response = function(self, player, response)
    return false
  end,
  before_use = function(self, player, use)
    local count = player:getMark("j_jizhi_count-round") or 0
    player.room:setPlayerMark(player, "j_jizhi_count-round", count + 1)
  end,
})

return j_jizhi
