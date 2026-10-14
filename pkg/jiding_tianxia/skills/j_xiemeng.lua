local j_xiemeng = fk.CreateSkill {
  name = "j_xiemeng",
}

Fk:loadTranslationTable{
  ["j_xiemeng"] = "协盟",
  [":j_xiemeng"] = "当你的上家或下家成为一张非装备牌的唯一目标时，你可以令你的下家或上家也成为此牌的目标。",
}

j_xiemeng:addEffect(fk.CardUsing, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xiemeng.name) then return false end
    if not data.card then return false end
    -- 装备牌不触发协盟
    if data.card.type == Card.TypeEquip then return false end

    local targets = data.tos or {}
    if #targets ~= 1 then return false end

    local target = targets[1]
    local room = player.room
    if not room then return false end

    local players = room.alive_players
    local idx = -1
    for i, p in ipairs(players) do
      if p.id == player.id then
        idx = i
        break
      end
    end
    if idx == -1 then return false end

    local prev_idx = idx == 1 and #players or idx - 1
    local next_idx = idx == #players and 1 or idx + 1
    local prev_player = players[prev_idx]
    local next_player = players[next_idx]

    return target.id == prev_player.id or target.id == next_player.id
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_xiemeng.name })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local targets = data.tos or {}
    local original_target = targets[1]

    local players = room.alive_players
    local idx = -1
    for i, p in ipairs(players) do
      if p.id == player.id then
        idx = i
        break
      end
    end

    local prev_idx = idx == 1 and #players or idx - 1
    local next_idx = idx == #players and 1 or idx + 1
    local prev_player = players[prev_idx]
    local next_player = players[next_idx]

    local new_target = original_target.id == prev_player.id and next_player or prev_player
    data:addTarget(new_target)
  end,
})

return j_xiemeng