-- 舒邵六号·赈民
-- 当你回合外获得牌时，你可以将任意张手牌交给一名其他角色，然后令其中的基本牌（数值+1，无次数限制，无范围限制），非延时锦囊牌（可选目标+1且不能被无懈可击响应），装备牌（进入装备区后回复一点体力摸1张牌）
local s_zhenmin = fk.CreateSkill {
  name = "s_zhenmin",
}

Fk:loadTranslationTable{
  ["s_zhenmin"] = "赈民",
  [":s_zhenmin"] = "当你回合外获得牌时，你可以将任意张手牌交给一名其他角色，然后令其中的基本牌（数值+1，无次数限制，无范围限制），非延时锦囊牌（可选目标+1且不能被无懈可击响应），装备牌（进入装备区后回复一点体力摸1张牌）。",

  ["#s_zhenmin-invoke"] = "赈民：是否将任意张手牌交给一名其他角色？",
  ["#s_zhenmin-select"] = "赈民：选择要交给的角色牌",
  ["#s_zhenmin-target"] = "赈民：选择获得牌的角色",

  ["$s_zhenmin1"] = "仓廪之粟，散与饥民！",
  ["$s_zhenmin2"] = "赈济乡邻，吾之愿也！",
}

-- 回合外获得牌：交任意张手牌给一名其他角色，记录牌增益
s_zhenmin:addEffect(fk.AfterCardsMove, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_zhenmin.name) then return false end
    -- 仅回合外
    if player == player.room.current then return false end
    -- 是否有牌进入其手牌
    local got = false
    for _, move in ipairs(data) do
      if move.to == player and move.toArea == Card.PlayerHand then
        got = true
        break
      end
    end
    if not got then return false end
    return #player:getCardIds("h") > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    return room:askToSkillInvoke(player, { skill_name = s_zhenmin.name, prompt = "#s_zhenmin-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      min = 1,
      max = #player:getCardIds("h"),
      skill_name = s_zhenmin.name,
      prompt = "#s_zhenmin-select",
      cancelable = false,
      pattern = ".",
    })
    if #cards == 0 then return end
    -- 统一为实体id
    local ids = {}
    for _, c in ipairs(cards) do
      table.insert(ids, type(c) == "number" and c or Card:getIdList(c)[1])
    end
    local tos = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player),
      min_num = 1,
      max_num = 1,
      cancelable = false,
      skill_name = s_zhenmin.name,
      prompt = "#s_zhenmin-target",
    })
    local to = tos[1]
    if not to then return end
    -- 交牌
    room:moveCards{
      ids = ids,
      from = player,
      to = to,
      toArea = Card.PlayerHand,
      moveReason = fk.ReasonGive,
      skillName = s_zhenmin.name,
    }
    -- 记录增益：牌id -> 获得角色id
    local mark = player:getTableMark("@@s_zhenmin_cards")
    for _, id in ipairs(ids) do
      table.insert(mark, { id, to.id })
    end
    room:setPlayerMark(player, "@@s_zhenmin_cards", mark)
  end,
})

-- 查找某牌是否处于赈民增益中；返回获得该牌的角色id
local function zhenminOwnerId(room, cardId)
  for _, p in ipairs(room.alive_players) do
    local mark = p:getTableMark("@@s_zhenmin_cards")
    for _, rec in ipairs(mark) do
      if rec[1] == cardId then
        return rec[2]
      end
    end
  end
  return nil
end

-- 基本牌：数值+1（杀伤害+1）
s_zhenmin:addEffect(fk.DamageCaused, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_zhenmin.name) then return false end
    if not data.card then return false end
    if data.card.type ~= Card.TypeBasic then return false end
    if not data.from then return false end
    -- 造成伤害的角色必须是标记牌的获得者
    local ids = Card:getIdList(data.card)
    if #ids == 0 then return false end
    return zhenminOwnerId(player.room, ids[1]) == data.from.id
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data.damage = data.damage + 1
  end,
})

-- 装备牌：进入装备区后回复一点体力并摸1张牌
s_zhenmin:addEffect(fk.CardUseFinished, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(s_zhenmin.name) then return false end
    local card = data.card
    if not card or card.type ~= Card.TypeEquip then return false end
    if not data.from then return false end
    -- 使用装备的角色必须是标记牌的获得者
    local ids = Card:getIdList(card)
    if #ids == 0 then return false end
    return zhenminOwnerId(player.room, ids[1]) == data.from.id
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:recover{ who = player, num = 1, recoverBy = player, skillName = s_zhenmin.name }
    player:drawCards(1, s_zhenmin.name)
  end,
})

-- 测试1：回合外获得牌时交牌给其他角色，标记记录；标记杀造成伤害+1
s_zhenmin:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  local sl
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_zhenmin.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 4
    comp3.maxHp = 4
    comp3.hp = 4
    room.current = comp2
    -- me 手牌2张；回合外（room.current=comp2）
    local h1 = room:printCard("slash", Card.Spade, 3)
    local h2 = room:printCard("jink", Card.Heart, 4)
    room:obtainCard(me, { h1, h2 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    -- me：发动“1”，选牌 h1，目标 comp2
    FkTest.setNextReplies(me, { "1", { me:getCardIds("h")[1] }, { card = { subcards = {} }, targets = { comp2.id } } })
    -- 模拟回合外获得牌：comp2 回合中 me 获得一张牌
    local newCard = room:printCard("peach", Card.Club, 7)
    room:obtainCard(me, { newCard }, true, fk.ReasonDraw, me, "test")
    lu.assertEquals(#me:getTableMark("@@s_zhenmin_cards"), 1, "赈民：应记录1张增益牌")
    lu.assertEquals(#me:getCardIds("h"), 2, "赈民：交出1张手牌后手牌应减少")
    -- 记录增益牌id
    local rec = me:getTableMark("@@s_zhenmin_cards")[1]
    local markedCard = rec[1]
    sl = Fk:getCardById(markedCard)
    -- comp2 用标记杀打 comp3
    FkTest.setNextReplies(comp2, { { card = { subcards = {} }, targets = { comp3.id } } })
    FkTest.setNextReplies(comp3, { "0" })
    room:useCard{ from = comp2, tos = { comp3 }, card = sl, extraUse = true }
    lu.assertEquals(comp3.hp, 2, "赈民：标记杀伤害应+1（造成2点伤害）")
  end)
end)

-- 测试2：标记装备进入装备区后回复1摸1
s_zhenmin:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_zhenmin.name)
    me.maxHp = 4
    me.hp = 4
    comp2.maxHp = 4
    comp2.hp = 3
    room.current = comp2
    local e1 = room:printCard("eight_diagram", Card.Heart, 8)
    room:obtainCard(me, { e1 }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    -- 回合外获得牌触发赈民：选八卦阵交给 comp2
    FkTest.setNextReplies(me, { "1", { me:getCardIds("h")[1] }, { card = { subcards = {} }, targets = { comp2.id } } })
    local newCard = room:printCard("peach", Card.Club, 7)
    room:obtainCard(me, { newCard }, true, fk.ReasonDraw, me, "test")
    local rec = me:getTableMark("@@s_zhenmin_cards")[1]
    lu.assertNotNil(rec, "赈民：应记录装备增益")
    local armId = rec[1]
    -- comp2 使用标记八卦阵（装备自己）
    local hBefore = #comp2:getCardIds("h")
    FkTest.setNextReplies(comp2, { { card = { subcards = {} }, targets = { comp2.id } } })
    room:useCard{ from = comp2, tos = { comp2 }, card = Fk:getCardById(armId), extraUse = true }
    lu.assertEquals(comp2.hp, 4, "赈民：标记装备入装备区应回复1点体力")
    lu.assertEquals(#comp2:getCardIds("h"), hBefore + 1, "赈民：标记装备入装备区应摸1张牌")
  end)
end)

return s_zhenmin