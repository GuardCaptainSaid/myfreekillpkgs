-- 舒邵四号·宁己
-- 当你成为【杀】或非延时类锦囊牌的目标时，若你的手牌数小于等于你的体力值，你可以弃置一张“粮”并摸一张牌，然后令此牌对你无效；此牌结算结束后，你可以将其交给任意一名其他角色。
local s_ningji = fk.CreateSkill {
  name = "s_ningji",
}

Fk:loadTranslationTable{
  ["s_ningji"] = "宁己",
  [":s_ningji"] = "当你成为【杀】或非延时类锦囊牌的目标时，若你的手牌数小于等于你的体力值，你可以弃置一张“粮”并摸一张牌，然后令此牌对你无效；此牌结算结束后，你可以将其交给任意一名其他角色。",

  ["#s_ningji-invoke"] = "宁己：是否弃置一张“粮”并摸一张牌，令此牌对你无效？",
  ["#s_ningji-give"] = "宁己：是否将此牌交给一名其他角色？",
  ["#s_ningji-give-target"] = "宁己：选择获得此牌的角色",

  ["$s_ningji1"] = "宁己以静，观其变也！",
  ["$s_ningji2"] = "此牌与我无干，且赠他人！",
}

-- 成为杀/非延时锦囊目标时：弃1粮摸1，令此牌无效
s_ningji:addEffect(fk.TargetConfirmed, {
  anim_type = "defensive",
  can_trigger = function(self, target, player, data)
    if target ~= player then return false end
    if player.dead then return false end
    if not player:hasSkill(s_ningji.name) then return false end
    local card = data.card
    if not card then return false end
    -- 延时锦囊不触发
    if card.type == Card.TypeTrick and card.sub_type == Card.SubtypeDelayedTrick then return false end
    -- 仅【杀】或非延时锦囊触发
    if card.type == Card.TypeBasic and card.trueName ~= "slash" then return false end
    if card.type == Card.TypeEquip then return false end
    -- 手牌数 ≤ 体力值
    if #player:getCardIds("h") > player.hp then return false end
    return player:getMark("@s_sanliang4_liang") > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, { skill_name = s_ningji.name, prompt = "#s_ningji-invoke" }) then
      return false
    end
    -- 弃一张粮
    room:setPlayerMark(player, "@s_sanliang4_liang", player:getMark("@s_sanliang4_liang") - 1)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:drawCards(1, s_ningji.name)
    -- 令此牌对玩家无效
    data:cancelTarget(player)
    -- 记录此牌的实体id，供结算结束后交付
    local cards = player:getTableMark("@@s_ningji_cards")
    for _, id in ipairs(Card:getIdList(data.card)) do
      table.insert(cards, id)
    end
    room:setPlayerMark(player, "@@s_ningji_cards", cards)
  end,
})

-- 牌结算结束（入弃牌堆）：可交给任意一名其他角色
s_ningji:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_ningji.name) then return false end
    local cards = player:getTableMark("@@s_ningji_cards")
    if #cards == 0 then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo) do
          if table.contains(cards, info.cardId) then return true end
        end
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local cards = player:getTableMark("@@s_ningji_cards")
    local cardId = nil
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo) do
          if table.contains(cards, info.cardId) then cardId = info.cardId break end
        end
      end
    end
    if not cardId then return false end
    if not room:askToSkillInvoke(player, { skill_name = s_ningji.name, prompt = "#s_ningji-give" }) then
      table.remove(cards, table.indexOf(cards, cardId))
      room:setPlayerMark(player, "@@s_ningji_cards", cards)
      return false
    end
    local tos = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player),
      min_num = 1,
      max_num = 1,
      cancelable = false,
      skill_name = s_ningji.name,
      prompt = "#s_ningji-give-target",
    })
    if not tos[1] then
      table.remove(cards, table.indexOf(cards, cardId))
      room:setPlayerMark(player, "@@s_ningji_cards", cards)
      return false
    end
    self.costData = { cardId = cardId, to = tos[1] }
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cd = self.costData
    self.costData = nil
    if not cd then return end
    room:obtainCard(cd.to, { cd.cardId }, true, fk.ReasonGive, player, s_ningji.name)
    local cards = player:getTableMark("@@s_ningji_cards")
    table.remove(cards, table.indexOf(cards, cd.cardId))
    room:setPlayerMark(player, "@@s_ningji_cards", cards)
  end,
})

-- 测试1：成为杀目标时发动，取消目标并结算后交给其他角色
s_ningji:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  local sl
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_ningji.name)
    me.maxHp = 3
    me.hp = 3
    comp2.maxHp = 3
    comp2.hp = 3
    comp3.maxHp = 3
    comp3.hp = 3
    room.current = comp2
    comp2.phase = Player.Play
    -- me 有2张手牌（≤体力3），1枚粮；comp2 有一张杀
    local h1 = room:printCard("slash", Card.Spade, 3)
    local h2 = room:printCard("jink", Card.Heart, 4)
    room:obtainCard(me, { h1, h2 }, true, fk.ReasonDraw, me, "test")
    room:setPlayerMark(me, "@s_sanliang4_liang", 1)
    sl = room:printCard("slash", Card.Diamond, 9)
    room:obtainCard(comp2, { sl }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    local hBefore = #me:getCardIds("h")
    -- me：发动宁己“1”；结算后交付“1”并选目标 comp3
    FkTest.setNextReplies(me, { "1", "1", { card = { subcards = {} }, targets = { comp3.id } } })
    room:useCard{ from = comp2, tos = { me }, card = Fk:getCardById(sl), extraUse = true }
    lu.assertEquals(me:getMark("@s_sanliang4_liang"), 0, "宁己：应弃1枚粮")
    lu.assertEquals(#me:getCardIds("h"), hBefore + 1, "宁己：应摸1张牌")
    lu.assertEquals(me.hp, 3, "宁己：目标被取消不应受伤")
    lu.assertEquals(#me:getTableMark("@@s_ningji_cards"), 0, "宁己：交付后记录应清空")
  end)
end)

-- 测试2：手牌数大于体力值时不触发，正常成为目标并受伤
s_ningji:addTest(function(room, me)
  local comp2 = room.players[2]
  local sl
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_ningji.name)
    me.maxHp = 3
    me.hp = 2
    comp2.maxHp = 3
    comp2.hp = 3
    room.current = comp2
    comp2.phase = Player.Play
    -- me 有4张手牌（>体力2），1枚粮；comp2 有杀
    local h1 = room:printCard("slash", Card.Spade, 3)
    local h2 = room:printCard("jink", Card.Heart, 4)
    local h3 = room:printCard("peach", Card.Club, 5)
    local h4 = room:printCard("duel", Card.Spade, 6)
    room:obtainCard(me, { h1, h2, h3, h4 }, true, fk.ReasonDraw, me, "test")
    room:setPlayerMark(me, "@s_sanliang4_liang", 1)
    sl = room:printCard("slash", Card.Diamond, 9)
    room:obtainCard(comp2, { sl }, true, fk.ReasonDraw, comp2, "test")
  end)
  FkTest.runInRoom(function()
    -- me：不出闪 → 受1点伤害
    FkTest.setNextReplies(me, { "0" })
    room:useCard{ from = comp2, tos = { me }, card = Fk:cloneCard("slash"), extraUse = true }
    lu.assertEquals(me.hp, 1, "宁己：不触发时应正常受伤")
    lu.assertEquals(me:getMark("@s_sanliang4_liang"), 1, "宁己：不触发时不应弃粮")
  end)
end)

return s_ningji