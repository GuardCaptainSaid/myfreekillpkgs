local j_chenglun = fk.CreateSkill {
  name = "j_chenglun",
}

Fk:loadTranslationTable{
  ["j_chenglun"] = "成论",
  [":j_chenglun"] = "出牌阶段限一次，你可以将一张牌交给一名角色并观看其手牌，然后你弃置其中的一张牌并记录类型，直到你的下回合开始，其不因重铸获得牌时需展示并重铸类型与记录相同的牌，否则其弃置获得的牌。",

  ["#j_chenglun-invoke"] = "成论：是否发动？",
  ["#j_chenglun-card"] = "成论：选择一张手牌交给目标",
  ["#j_chenglun-target"] = "成论：选择一名角色",
  ["#j_chenglun-discard"] = "成论：选择一张牌弃置",
  ["#j_chenglun-recast"] = "成论：选择一张%s类型的牌重铸，否则弃置获得的牌",

  ["$j_chenglun1"] = "论天下大势，成千秋功业！",
  ["$j_chenglun2"] = "言之成理，论之有据！",
}

j_chenglun:addEffect("active", {
  anim_type = "offensive",
  card_num = 1,
  target_num = 1,
  can_use = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0 and
      player:usedSkillTimes(j_chenglun.name, Player.HistoryPhase) == 0
  end,
  target_filter = function(self, player, to_select, selected, selected_cards, card, extra_data)
    if to_select == player then return false end
    return #selected < 1
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    local cards = effect.cards

    if cards and #cards > 0 then
      room:moveCardTo(cards, Card.PlayerHand, target, fk.ReasonGive, j_chenglun.name, nil, false, player)
    end

    room:showCards(target:getCardIds("h"), player, j_chenglun.name)

    local choice = room:askToChooseCard(player, {
      target = target,
      flag = "h",
      num = 1,
      skill_name = j_chenglun.name,
      prompt = "#j_chenglun-discard",
      card_filter = function(card_id, selected)
        return table.contains(target:getCardIds("h"), card_id)
      end,
    })

    if choice and choice > 0 then
      local discard_id = choice
      local card = Fk:getCardById(discard_id)
      room:throwCard(discard_id, j_chenglun.name, target, target)

      local card_type_name = ""
      if card.type == Card.TypeBasic then
        card_type_name = "基本"
      elseif card.type == Card.TypeTrick then
        card_type_name = "锦囊"
      elseif card.type == Card.TypeEquip then
        card_type_name = "装备"
      end

      room:setPlayerMark(target, "j_chenglun_type", card.type)
      room:setPlayerMark(target, "j_chenglun_type_name", card_type_name)
      room:setPlayerMark(target, "j_chenglun_caster", player.id)
    end
  end,
})

j_chenglun:addEffect(fk.AfterCardsMove, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if player:getMark("j_chenglun_caster") == 0 then return false end
    for _, move in ipairs(data) do
      if move.fromArea == Card.DrawPile or move.fromArea == Card.DiscardPile then
        if move.toArea == Card.PlayerHand and move.to == player then
          if move.moveReason ~= fk.ReasonRecast then
            return true
          end
        end
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local caster = room:getPlayerById(player:getMark("j_chenglun_caster"))
    if not caster or not caster:isAlive() then return end

    local gained_card_ids = {}
    for _, move in ipairs(data) do
      if move.fromArea == Card.DrawPile or move.fromArea == Card.DiscardPile then
        if move.toArea == Card.PlayerHand and move.to == player then
          if move.moveReason ~= fk.ReasonRecast then
            for _, info in ipairs(move.moveInfo) do
              table.insert(gained_card_ids, info.cardId)
            end
          end
        end
      end
    end

    if #gained_card_ids == 0 then return end
    room:showCards(gained_card_ids, player, j_chenglun.name)

    local recorded_type = player:getMark("j_chenglun_type")
    local type_name = player:getMark("j_chenglun_type_name")

    for _, gained_card_id in ipairs(gained_card_ids) do
      local same_type_cards = {}
      for _, cid in ipairs(player:getCardIds("h")) do
        local card = Fk:getCardById(cid)
        if card.type == recorded_type and cid ~= gained_card_id then
          table.insert(same_type_cards, cid)
        end
      end

      if #same_type_cards > 0 then
        local choice = room:askToChoice(player, {
          choices = table.map(same_type_cards, function(id) return tostring(id) end),
          skill_name = j_chenglun.name,
          prompt = string.format("#j_chenglun-recast", type_name),
          cancelable = true,
        })

        if choice then
          local recast_id = tonumber(choice)
          room:recastCard(recast_id, player, j_chenglun.name)
        else
          room:throwCard(gained_card_id, j_chenglun.name, player, player)
        end
      else
        room:throwCard(gained_card_id, j_chenglun.name, player, player)
      end
    end
  end,
})

j_chenglun:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_chenglun.name) and player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room:getAlivePlayers()) do
      if p:getMark("j_chenglun_caster") == player.id then
        room:setPlayerMark(p, "j_chenglun_type", 0)
        room:setPlayerMark(p, "j_chenglun_type_name", "")
        room:setPlayerMark(p, "j_chenglun_caster", 0)
      end
    end
  end,
})

-- 测试：成论主动技弃置目标一张牌并记录类型
j_chenglun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_chenglun.name)
  end)

  FkTest.runInRoom(function()
    -- 目标过滤：其他角色可选、自己不可选
    local sk = Fk.skills[j_chenglun.name]
    lu.assertTrue(sk:targetFilter(me, comp2, {}, {}, nil, nil), "其他角色应可作为成论目标")
    lu.assertFalse(sk:targetFilter(me, me, {}, {}, nil, nil), "成论不能以自己为目标")

    local card1 = room:printCard("slash")
    room:obtainCard(me, {card1}, true, fk.ReasonDraw, me, "test")
    local trick_id = nil
    for _, cid in ipairs(room.draw_pile) do
      local c = Fk:getCardById(cid)
      if c.type == Card.TypeTrick then trick_id = cid break end
    end
    room:obtainCard(comp2, {trick_id}, true, fk.ReasonDraw, comp2, "test")

    FkTest.setNextReplies(me, { trick_id })
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = { comp2 }, cards = { card1.id } })
    end, {})
    lu.assertEquals(comp2:getMark("j_chenglun_type"), Card.TypeTrick, "应记录被弃置牌的锦囊类型")
    lu.assertEquals(comp2:getMark("j_chenglun_caster"), me.id, "应记录施术者")
  end)
end)

return j_chenglun