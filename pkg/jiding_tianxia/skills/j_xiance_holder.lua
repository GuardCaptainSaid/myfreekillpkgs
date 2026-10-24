-- 计桓范·谋策（【献策】授予持有者的转化子技能）
--
-- ！！此类"子技能"必须单独占一个文件！！
-- 引擎的技能加载器（Package:loadSkillSkelsByPath）只把「文件 return 的那个 skeleton」
-- 注册进 Fk.skills；同一个文件里再 fk.CreateSkill 出来的第二个技能**不会被注册**。
-- 后果：handleAddLoseSkills(p, "j_xiance_holder") 里 Fk.skills[name] 为 nil，
-- 函数静默什么都不做 → 技能从来没授予过任何人 → 谋策永远印不出牌。
-- （这正是此前反复修不动的真正原因。识谶的 j_shichen_conv、显忌的 j_kuanggu 同病，已一并拆出。）
local j_xiance_holder = fk.CreateSkill {
  name = "j_xiance_holder",
}

Fk:loadTranslationTable{
  ["j_xiance_holder"] = "谋策",
  [":j_xiance_holder"] = "出牌阶段，你可以将一张“谋策”牌当作一张本局已加入游戏的普通锦囊牌使用。",
  ["#j_xiance_holder"] = "谋策：选择一张“谋策”牌，当作普通锦囊牌使用",
}

local MOULI_MARK = "@@j_xiance_mouli"   -- 牌标记：该牌是“谋策”
local IDS_MARK = "j_xiance_mouli_ids"   -- 玩家表标记：手中谋策牌 id（客户端选牌用）
local NAMES_MARK = "j_xiance_names"     -- 玩家表标记：可作为的普通锦囊原始牌名（客户端选牌名用）

-- 客户端与服务端都能读的判断：这张手牌是不是“谋策”
local function isMouliCard(player, cid)
  if not table.contains(player:getCardIds("h"), cid) then return false end
  if table.contains(player:getTableMark(IDS_MARK), cid) then return true end
  local card = Fk:getCardById(cid)
  return card ~= nil and card:getMark(MOULI_MARK) > 0
end

-- 候选牌名（服务端在授予技能时写入玩家表标记；客户端直接读该标记）
local function nameList(player)
  return player:getTableMark(NAMES_MARK)
end

j_xiance_holder:addEffect("viewas", {
  anim_type = "offensive",
  prompt = "#j_xiance_holder",
  -- 不要写 pattern = 牌类型：pattern 是「转化结果的牌名」，客户端 ReqPlayCard:skillButtonValidity
  -- 会对里面每个名字 Fk:cloneCard，写 "normal_trick" 之类会崩。牌名由 interaction 决定。
  interaction = function(self, player)
    local names = nameList(player)
    if #names == 0 then return nil end
    -- 传原始牌名：前端只负责翻译显示，回传的仍是原始牌名
    return UI.CardNameBox { choices = names, all_choices = names }
  end,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    return isMouliCard(player, to_select)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    if not isMouliCard(player, cards[1]) then return nil end
    local names = nameList(player)
    -- interaction.data 未取到时退回候选第一项，避免“确认键永远不亮”
    local name = self.interaction.data or names[1]
    if type(name) ~= "string" or name == "" then return nil end
    if not table.contains(names, name) then return nil end   -- 不印牌：仅限本局已加入游戏的普通锦囊
    local card = Fk:cloneCard(name)
    if card == nil then return nil end
    card:addSubcards(cards)
    card.skillName = j_xiance_holder.name
    return card
  end,
  -- 谋策技能只在真正手持谋策时授予，这里不必再查标记/阶段（标记或 phase 同步延迟
  -- 曾导致按钮常灰、点不动）。enabled_at_play 只在出牌请求里被查询，天然就是出牌阶段。
  enabled_at_play = function(self, player)
    return true
  end,
  enabled_at_response = Util.FalseFunc,
})

-- 测试：谋策牌能转化为普通锦囊（印牌核心）
j_xiance_holder:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiance_holder.name)
    me.phase = Player.Play
    room.current = me
    c1 = room:printCard("jink", Card.Heart, 3)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_xiance_mouli", 1)
    room:setPlayerMark(me, "j_xiance_mouli_ids", { c1.id })
    room:setPlayerMark(me, "j_xiance_names", { "ex_nihilo", "duel" })
  end)
  FkTest.runInRoom(function()
    lu.assertTrue(me:hasSkill("j_xiance_holder"), "谋策技能应能授予（此前因未注册而静默失败）")
    local vs = Fk.skills[j_xiance_holder.name]
    lu.assertNotNil(vs, "谋策技能应在 Fk.skills 中注册")
    lu.assertTrue(vs:enabledAtPlay(me), "出牌阶段应可用")

    local inter = vs.interaction(vs, me)
    lu.assertNotNil(inter, "应返回牌名选择框")
    lu.assertEquals(inter.type, "cardname", "牌名选择框类型应为 cardname")
    lu.assertEquals(#inter.choices, 2, "候选应为两张本局锦囊")

    local eff = vs
    lu.assertTrue(eff:cardFilter(me, c1.id, {}, {}), "谋策牌应可被选中")

    eff.interaction.data = "ex_nihilo"
    local card = eff:viewAs(me, { c1.id })
    lu.assertNotNil(card, "谋策牌应能转化为普通锦囊")
    lu.assertEquals(card.name, "ex_nihilo", "转化牌名应为所选锦囊")
    lu.assertEquals(#card.subcards, 1, "应以谋策牌为副牌")

    -- 不在候选列表里的牌名不允许印（不印牌约定）
    eff.interaction.data = "lightning"
    lu.assertNil(eff:viewAs(me, { c1.id }), "不可印出候选外的牌")
    -- interaction.data 丢失时退回候选第一项，保证仍能印牌
    eff.interaction.data = nil
    lu.assertNotNil(eff:viewAs(me, { c1.id }), "缺省时应退回候选首项")
  end)
end)

-- 测试：普通手牌不能被谋策技能选中
j_xiance_holder:addTest(function(room, me)
  local c1, c2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xiance_holder.name)
    me.phase = Player.Play
    room.current = me
    c1 = room:printCard("jink", Card.Heart, 3)
    c2 = room:printCard("slash", Card.Club, 9)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_xiance_mouli", 1)
    room:setPlayerMark(me, "j_xiance_mouli_ids", { c1.id })
    room:setPlayerMark(me, "j_xiance_names", { "ex_nihilo" })
  end)
  FkTest.runInRoom(function()
    local vs = Fk.skills[j_xiance_holder.name]
    lu.assertTrue(vs:cardFilter(me, c1.id, {}, {}), "带谋策标记的牌应可选")
    lu.assertFalse(vs:cardFilter(me, c2.id, {}, {}), "普通手牌不可选")
    vs.interaction.data = "ex_nihilo"
    lu.assertNil(vs:viewAs(me, { c2.id }), "普通手牌不能转化")
  end)
end)

return j_xiance_holder
