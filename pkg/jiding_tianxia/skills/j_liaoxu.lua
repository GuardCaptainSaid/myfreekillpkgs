-- 计蒋济·料虚
-- 每回合限一次，当一名角色造成伤害时，你可以弃置两张牌并声明一个牌名，
-- 然后你依次观看造成伤害与受到伤害的角色的手牌，你获得其中你声明的牌；
-- 若你未以此法获得牌，则你视为使用此牌。
local j_liaoxu = fk.CreateSkill {
  name = "j_liaoxu",
}

Fk:loadTranslationTable{
  ["j_liaoxu"] = "料虚",
  [":j_liaoxu"] = "每回合限一次，当一名角色造成伤害时，你可以弃置两张牌并声明一个牌名，然后你依次观看造成伤害与受到伤害的角色的手牌，你获得其中你声明的牌；若你未以此法获得牌，则你视为使用此牌。",

  ["#j_liaoxu-discard"] = "料虚：弃置两张牌并声明一个牌名",
  ["#j_liaoxu-declare"] = "料虚：声明一个牌名",
  ["#j_liaoxu-view"] = "料虚：观看其手牌",
  ["#j_liaoxu-use"] = "料虚：未获得所声明的牌，视为使用",
}

-- 已加入游戏的牌名：仅收集本局实际存在的实体牌（牌堆/弃牌堆/各角色区域），
-- 不允许声明本局未加入的牌（防止“印牌”使用）
local function inGameCardNames(room)
  local names = {}
  local seen = {}
  local function addNames(ids)
    for _, id in ipairs(ids) do
      if not seen[id] then
        seen[id] = true
        local card = Fk:getCardById(id)
        if card.trueName and card.trueName ~= "" and card.type ~= Card.TypeSkill then
          table.insertIfNeed(names, card.trueName)
        end
      end
    end
  end
  addNames(room.draw_pile)
  addNames(room.discard_pile)
  for _, p in ipairs(room.players) do
    addNames(p:getCardIds("he")) -- 手牌 + 装备区
    addNames(p:getCardIds("j"))  -- 判定区
    addNames(p:getCardIds("s"))  -- 武将牌上各特殊区（如“囷”）
  end
  return names
end

j_liaoxu:addEffect(fk.Damage, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_liaoxu.name) or player.dead then return false end
    -- 每回合限一次
    if player:usedSkillTimes(j_liaoxu.name, Player.HistoryTurn) > 0 then return false end
    local from, to = data.from, data.to
    if not from or not to or from.dead or to.dead then return false end
    return #player:getCardIds("he") >= 2
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local discard = room:askToDiscard(player, {
      min_num = 2,
      max_num = 2,
      include_equip = true,
      skill_name = j_liaoxu.name,
      prompt = "#j_liaoxu-discard",
      cancelable = true,
    })
    if not discard or #discard < 2 then return false end
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 声明一个牌名（仅限本局已加入游戏的牌）
    local declared = room:askToChoice(player, {
      choices = inGameCardNames(room),
      skill_name = j_liaoxu.name,
      prompt = "#j_liaoxu-declare",
      cancelable = false,
    })
    if not declared or declared == "" then return end
    -- 依次观看造成伤害与受到伤害角色的手牌，获得其中所声明的牌
    local gainedAny = false
    local order = (data.from ~= data.to) and { data.from, data.to } or { data.from }
    for _, p in ipairs(order) do
      if p:isAlive() then
        local hand = p:getCardIds("h")
        if #hand > 0 then
          room:viewCards(player, {
            cards = hand,
            skill_name = j_liaoxu.name,
            prompt = "#j_liaoxu-view",
          })
          local matched = table.filter(hand, function(id)
            return Fk:getCardById(id).trueName == declared
          end)
          if #matched > 0 then
            room:obtainCard(player, matched, true, fk.ReasonPrey, p, j_liaoxu.name)
            gainedAny = true
          end
        end
      end
    end
    -- 未以此法获得牌 → 视为使用此牌
    if not gainedAny then
      room:askToUseVirtualCard(player, {
        name = declared,
        skill_name = j_liaoxu.name,
        cancelable = false,
      })
    end
  end,
})

-- 测试：声明“闪”，受伤角色手牌中有闪 → 获得之
j_liaoxu:addTest(function(room, me)
  local comp2, comp3 = room.players[2], room.players[3]
  local d1, d2, jk
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_liaoxu.name)
    d1 = room:printCard("slash", Card.Spade, 5)
    d2 = room:printCard("slash", Card.Heart, 6)
    room:obtainCard(me, { d1, d2 }, true, fk.ReasonDraw, me, "test")
    jk = room:printCard("jink", Card.Heart, 7)
    room:obtainCard(comp3, { jk }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local origDiscard = room.askToDiscard
    local origChoice = room.askToChoice
    local origView = room.viewCards
    room.askToDiscard = function(self, who, params)
      if who == me then return { d1.id, d2.id } end
      return origDiscard(self, who, params)
    end
    room.askToChoice = function(self, who, params)
      if who == me and params.skill_name == j_liaoxu.name and params.prompt == "#j_liaoxu-declare" then
        return "jink"
      end
      return origChoice(self, who, params)
    end
    room.viewCards = function(self, who, params) end

    room.logic:trigger(fk.Damage, comp2, { from = comp2, to = comp3, damage = 1 })

    room.askToDiscard = origDiscard
    room.askToChoice = origChoice
    room.viewCards = origView
    lu.assertTrue(table.contains(me:getCardIds("h"), jk.id), "应获得声明的闪")
    lu.assertTrue(not table.contains(me:getCardIds("h"), d1.id), "成本牌1应弃置")
    lu.assertTrue(not table.contains(me:getCardIds("h"), d2.id), "成本牌2应弃置")
  end)
end)

-- 测试：声明牌名无人持有（但该牌已加入本局游戏） → 视为使用该牌
j_liaoxu:addTest(function(room, me)
  local comp2, comp3 = room.players[2], room.players[3]
  local d1, d2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_liaoxu.name)
    d1 = room:printCard("slash", Card.Spade, 5)
    d2 = room:printCard("slash", Card.Heart, 6)
    room:obtainCard(me, { d1, d2 }, true, fk.ReasonDraw, me, "test")
    -- 清空双方手牌，确保观看对象无人持有“杀”（“杀”已加入本局游戏：me 手牌即存在）
    for _, id in ipairs(room.players[2]:getCardIds("h")) do
      room:moveCardTo(id, Card.DrawPile, nil, fk.ReasonPut, "test")
    end
    for _, id in ipairs(room.players[3]:getCardIds("h")) do
      room:moveCardTo(id, Card.DrawPile, nil, fk.ReasonPut, "test")
    end
  end)
  FkTest.runInRoom(function()
    local origDiscard = room.askToDiscard
    local origChoice = room.askToChoice
    local origView = room.viewCards
    local usedName = nil
    room.askToDiscard = function(self, who, params)
      if who == me then return { d1.id, d2.id } end
      return origDiscard(self, who, params)
    end
    room.askToChoice = function(self, who, params)
      if who == me and params.skill_name == j_liaoxu.name and params.prompt == "#j_liaoxu-declare" then
        return "slash"
      end
      return origChoice(self, who, params)
    end
    room.viewCards = function(self, who, params) end
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then
        usedName = params.name
        return true
      end
    end

    room.logic:trigger(fk.Damage, comp2, { from = comp2, to = comp3, damage = 1 })

    room.askToDiscard = origDiscard
    room.askToChoice = origChoice
    room.viewCards = origView
    lu.assertEquals(usedName, "slash", "未获得声明牌应视为使用该牌")
  end)
end)

-- 测试：声明范围仅限本局已加入游戏的牌，未加入游戏的牌不可声明
j_liaoxu:addTest(function(room, me)
  local names
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_liaoxu.name)
    local d1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { d1.id }, true, fk.ReasonDraw, me, "test")
    names = inGameCardNames(room)
  end)
  lu.assertTrue(table.contains(names, "slash"), "本局已加入的杀应可声明")
  lu.assertTrue(not table.contains(names, "j_zicangxiangzeng"), "本局未加入的指仓相赠不可声明")
end)

return j_liaoxu
