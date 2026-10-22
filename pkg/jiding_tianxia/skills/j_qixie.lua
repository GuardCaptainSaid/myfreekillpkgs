-- 计刘晔·奇械
-- 当你获得/失去装备区里的牌时，你可以摸一张牌；若此牌为武器牌，你额外摸一张牌。
local j_qixie = fk.CreateSkill {
  name = "j_qixie",
}

Fk:loadTranslationTable{
  ["j_qixie"] = "奇械",
  [":j_qixie"] = "当你获得/失去装备区里的牌时，你可以摸一张牌；若此牌为武器牌，你额外摸一张牌。",

  ["#j_qixie-invoke"] = "奇械：是否摸一张牌？",
}

j_qixie:addEffect(fk.AfterCardsMove, {
  global = true,
  -- 自动发动，逐张询问是否摸牌
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_qixie.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if (move.from == player and move.fromArea == Card.PlayerEquip)
        or (move.to == player and move.toArea == Card.PlayerEquip) then
        return true
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, move in ipairs(data) do
      local ids = {}
      if move.from == player and move.fromArea == Card.PlayerEquip then
        for _, info in ipairs(move.moveInfo) do
          table.insert(ids, info.cardId)
        end
      elseif move.to == player and move.toArea == Card.PlayerEquip then
        for _, info in ipairs(move.moveInfo) do
          table.insert(ids, info.cardId)
        end
      end
      for _, cid in ipairs(ids) do
        if player.dead then return end
        if room:askToSkillInvoke(player, { skill_name = j_qixie.name, prompt = "#j_qixie-invoke" }) then
          room:drawCards(player, 1, j_qixie.name)
          if Fk:getCardById(cid).sub_type == Card.SubtypeWeapon then
            room:drawCards(player, 1, j_qixie.name)
          end
        end
      end
    end
  end,
})

-- 测试：装备武器牌 → 摸两张牌
j_qixie:addTest(function(room, me)
  local w
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qixie.name)
    w = room:printCard("crossbow", Card.Spade, 1)
  end)
  FkTest.runInRoom(function()
    local before = #me:getCardIds("h")
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params)
      if who == me then return true end
      return origInvoke(self, who, params)
    end
    room:moveCardTo(w.id, Player.Equip, me, fk.ReasonPut, "test")
    room.askToSkillInvoke = origInvoke
    lu.assertTrue(table.contains(me:getCardIds("e"), w.id), "武器应在装备区")
    lu.assertEquals(#me:getCardIds("h"), before + 2, "装备武器应摸两张牌")
  end)
end)

return j_qixie
