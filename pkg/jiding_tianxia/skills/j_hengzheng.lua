local j_hengzheng = fk.CreateSkill {
  name = "j_hengzheng",
  tags = { Skill.Switch },
}

Fk:loadTranslationTable{
  ["j_hengzheng"] = "衡政",
  [":j_hengzheng"] = "转换技。阳（出牌阶段限一次）：你可将一张基本牌当【无中生有】或【过河拆桥】使用，然后令两名角色摸一张牌。阴：当一名角色使用非转化牌时，你可弃置一张颜色相同的手牌，令其选择一项：①视为你对其使用一张【杀】（不计入次数限制）；②此牌无效，令你摸一张牌。",
  [":j_hengzheng_yang"] = "转换技，<font color='#E0DB2F'>阳（出牌阶段限一次）：你可将一张基本牌当【无中生有】或【过河拆桥】使用，然后令两名角色摸一张牌；</font><font color='grey'>阴：当一名角色使用非转化牌时，你可弃置一张颜色相同的手牌，令其选择一项：①视为你对其使用一张【杀】（不计入次数限制）；②此牌无效，令你摸一张牌。</font>",
  [":j_hengzheng_yin"] = "转换技，<font color='grey'>阳（出牌阶段限一次）：你可将一张基本牌当【无中生有】或【过河拆桥】使用，然后令两名角色摸一张牌；</font><font color='#E0DB2F'>阴：当一名角色使用非转化牌时，你可弃置一张颜色相同的手牌，令其选择一项：①视为你对其使用一张【杀】（不计入次数限制）；②此牌无效，令你摸一张牌。</font>",

  ["#j_hengzheng-draw"] = "衡政：令两名角色各摸一张牌",
  ["#j_hengzheng-yin"] = "衡政：弃一张与 %src 所用牌颜色相同的手牌",
  ["#j_hengzheng-discard"] = "衡政：弃置一张颜色相同的手牌",
  ["#j_hengzheng-choice"] = "衡政：选择一项",
  ["j_hengzheng:slash"] = "视为其对汝使用一张【杀】",
  ["j_hengzheng:nullify"] = "此牌无效，令其摸一张牌",
  ["$j_hengzheng1"] = "权衡利弊，政通人和。",
  ["$j_hengzheng2"] = "阴阳相济，虚实难测！",
}

-- 阳形态：将一张基本牌当【无中生有】或【过河拆桥】使用
j_hengzheng:addEffect("viewas", {
  anim_type = "offensive",
  card_num = 1,
  card_filter = function(self, player, to_select, selected, selected_targets)
    if #selected >= 1 then return false end
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    if player:getSwitchSkillState(j_hengzheng.name) ~= fk.SwitchYang then return false end
    return Fk:getCardById(to_select).type == Card.TypeBasic
  end,
  interaction = function(self, player)
    if player:getSwitchSkillState(j_hengzheng.name) ~= fk.SwitchYang then return nil end
    return UI.CardNameBox { choices = { "ex_nihilo", "dismantlement" }, all_choices = { "ex_nihilo", "dismantlement" } }
  end,
  view_as = function(self, player, cards)
    if player:getMark("j_hengzheng_used") ~= 0 then return end
    if #cards ~= 1 or not self.interaction.data then return end
    local card = Fk:cloneCard(self.interaction.data)
    card.skillName = j_hengzheng.name
    card:addSubcard(cards[1])
    return card
  end,
  can_use = function(self, player)
    return player:getMark("j_hengzheng_used") == 0
      and player:getSwitchSkillState(j_hengzheng.name) == fk.SwitchYang
  end,
  enabled_at_play = function(self, player)
    return player:getMark("j_hengzheng_used") == 0
      and player:getSwitchSkillState(j_hengzheng.name) == fk.SwitchYang
  end,
  after_use = function(self, player, use)
    local room = player.room
    room:setPlayerMark(player, "j_hengzheng_used", 1)
    local targets = room:askToChoosePlayers(player, {
      targets = room.alive_players,
      min_num = 2,
      max_num = 2,
      skill_name = j_hengzheng.name,
      prompt = "#j_hengzheng-draw",
    })
    for _, t in ipairs(targets) do
      if t:isAlive() then
        t:drawCards(1, j_hengzheng.name)
      end
    end
  end,
})

-- 回合开始：重置出牌阶段限次
j_hengzheng:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_hengzheng.name) and player.phase == Player.Start
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_hengzheng_used", 0)
  end,
})

-- 阴形态：当一名角色使用非转化牌时，弃置一张颜色相同的手牌，令其选择一项
j_hengzheng:addEffect(fk.CardUsing, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(j_hengzheng.name) then return false end
    if player:getSwitchSkillState(j_hengzheng.name) ~= fk.SwitchYin then return false end
    if not data or not data.card or not data.from then return false end
    if data.from == player or data.from.dead then return false end
    -- 非转化牌：实体牌直接使用
    if data.card:isVirtual() then return false end
    if data.card.skillName ~= nil and data.card.skillName ~= "" then return false end
    -- 手牌中有与其颜色相同的牌
    for _, id in ipairs(player:getCardIds("h")) do
      if Fk:getCardById(id).color == data.card.color then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, {
      skill_name = j_hengzheng.name,
      prompt = "#j_hengzheng-yin::" .. data.from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 弃一张颜色相同的手牌
    local sameIds = table.filter(player:getCardIds("h"), function(id)
      return Fk:getCardById(id).color == data.card.color
    end)
    if #sameIds == 0 then return end
    local cards = room:askToChooseCards(player, {
      target = player,
      flag = "h",
      min = 1,
      max = 1,
      cancelable = false,
      skill_name = j_hengzheng.name,
      prompt = "#j_hengzheng-discard",
    })
    if not cards or #cards ~= 1 then return end
    room:throwCard(cards, j_hengzheng.name, player, player)
    -- 令使用者选择一项
    local choice = room:askToChoice(data.from, {
      choices = { "j_hengzheng:slash", "j_hengzheng:nullify" },
      skill_name = j_hengzheng.name,
      prompt = "#j_hengzheng-choice",
    })
    if choice == "j_hengzheng:slash" then
      -- 视为你对其使用一张【杀】（不计入次数限制）
      local slash = Fk:cloneCard("slash")
      slash.skillName = j_hengzheng.name
      room:useCard{ from = player, tos = { data.from }, card = slash, extraUse = true }
    else
      -- 此牌无效，令你摸一张牌
      data.nullified = true
      player:drawCards(1, j_hengzheng.name)
    end
    -- 阴发动后翻回阳
    room:setPlayerMark(player, MarkEnum.SwithSkillPreName .. j_hengzheng.name, 0)
  end,
})

j_hengzheng:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_hengzheng.name,
  think = Util.TrueFunc,
})

-- 测试：阳形态可将一张基本牌当无中生有/过河拆桥使用
j_hengzheng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_hengzheng.name)
    local c1 = room:printCard("slash", Card.Spade, 3)
    local c2 = room:printCard("dismantlement", Card.Heart, 4)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    local skel = Fk.skills[j_hengzheng.name]:getSkeleton()
    local eff = skel.effects[1]

    -- 初始为阳形态：基本牌可转锦囊
    lu.assertEquals(me:getSwitchSkillState(j_hengzheng.name), fk.SwitchYang, "初始应为阳形态")
    eff.interaction.data = "ex_nihilo"
    local card1 = eff:viewAs(me, { c1.id })
    lu.assertNotNil(card1, "阳形态基本牌应能转化为无中生有")
    lu.assertEquals(card1.name, "ex_nihilo")
    eff.interaction.data = "dismantlement"
    local card2 = eff:viewAs(me, { c2.id })
    lu.assertNil(card2, "非基本牌不能转化")
  end)
end)

-- 测试：阴形态使用非转化牌时，弃同色牌，使用者选"此牌无效"则牌无效且我摸一张
j_hengzheng:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_hengzheng.name)
    -- 翻到阴形态
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_hengzheng.name, 1)
    c1 = room:printCard("slash", Card.Spade, 5)
    c2 = room:printCard("peach", Card.Heart, 6)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test") -- 黑
    room:obtainCard(comp2, { c2 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    lu.assertEquals(me:getSwitchSkillState(j_hengzheng.name), fk.SwitchYin, "应为阴形态")
    -- comp2 使用一张黑色实体杀 → 我弃同色黑牌 → comp2 选"此牌无效"
    local blackSlash = Fk:getCardById(comp2:getCardIds("h")[1]) -- 桃（红）不匹配，改用手动构造
    -- 直接构造一个黑色实体杀的使用
    local realSlash = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(comp2, { realSlash }, true, fk.ReasonDraw, comp2, "test")
    FkTest.setNextReplies(me, { "1", FkTest.ReplyChooseCards({ c1.id }) })
    FkTest.setNextReplies(comp2, { "j_hengzheng:nullify" })
    local use = UseCardData:new{ from = comp2, card = Fk:getCardById(realSlash.id), tos = {} }
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertTrue(use.nullified, "此牌应被无效")
    lu.assertEquals(#me:getCardIds("h"), 1, "我应摸一张牌（弃1摸1，手牌数不变为1）")
    lu.assertEquals(me:getSwitchSkillState(j_hengzheng.name), fk.SwitchYang, "阴发动后应翻回阳")
  end)
end)

-- 测试：使用者选"视为杀"则我对其使用一张杀
j_hengzheng:addTest(function(room, me)
  local comp2 = room.players[2]
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_hengzheng.name)
    room:setPlayerMark(me, MarkEnum.SwithSkillPreName .. j_hengzheng.name, 1)
    c1 = room:printCard("slash", Card.Spade, 5)
    c2 = room:printCard("peach", Card.Heart, 6)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(comp2, { c2 }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    local realSlash = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(comp2, { realSlash }, true, fk.ReasonDraw, comp2, "test")
    FkTest.setNextReplies(me, { "1", FkTest.ReplyChooseCards({ c1.id }) })
    FkTest.setNextReplies(comp2, { "j_hengzheng:slash", "" }) -- 选视为杀；comp2 无闪（桃）→ 中杀
    local use = UseCardData:new{ from = comp2, card = Fk:getCardById(realSlash.id), tos = {} }
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertFalse(use.nullified, "选杀则牌不无效")
    lu.assertEquals(comp2.hp, 3, "comp2 应受我的一张杀伤害")
  end)
end)

return j_hengzheng