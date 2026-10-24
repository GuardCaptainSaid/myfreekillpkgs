-- 计杨修·谶（【识谶】授予的转化子技能）
--
-- ！！必须单独占一个文件！！
-- 引擎的技能加载器只注册「文件 return 的那个 skeleton」；同一文件里的第二个
-- fk.CreateSkill 不会进入 Fk.skills，于是 handleAddLoseSkills("j_shichen_conv")
-- 静默失败、技能根本授予不上（谋策 j_xiance_holder 当年就是这个毛病）。
local j_shichen_conv = fk.CreateSkill {
  name = "j_shichen_conv",
}

Fk:loadTranslationTable{
  ["j_shichen_conv"] = "谶",
  [":j_shichen_conv"] = "本轮内，你可以弃置一张与“谶”花色相同的手牌，视为使用该“谶”牌。",
  ["#j_shichen_conv"] = "谶：弃置一张与“谶”花色相同的手牌，视为使用“谶”牌",
}

-- 当前“谶”的牌名与花色（写在玩家标记上，客户端 viewas 也读这两个标记）
local function chenName(player)
  local name = player:getMark("j_shichen_chen_name")
  if type(name) ~= "string" or name == "" or Fk.all_card_types[name] == nil then return end
  return name
end

local function chenSuit(player)
  local suit = player:getMark("j_shichen_chen_suit")
  if type(suit) ~= "number" or suit < 1 then return end
  return suit
end

-- 手中与“谶”同花色的牌
local function sameSuitHandIds(player)
  local suit = chenSuit(player)
  if suit == nil then return {} end
  local ids = {}
  for _, cid in ipairs(player:getCardIds("h")) do
    local card = Fk:getCardById(cid)
    if card and card.suit == suit then table.insert(ids, cid) end
  end
  return ids
end

-- 本轮内：弃一张同花色手牌，视为使用“谶”牌
j_shichen_conv:addEffect("viewas", {
  prompt = "#j_shichen_conv",
  handly_pile = true,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    local suit = chenSuit(player)
    return suit ~= nil and Fk:getCardById(to_select).suit == suit
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local name = chenName(player)
    if not name then return nil end
    local card = Fk:cloneCard(name)
    if card == nil then return nil end
    card:addSubcards(cards)
    card.skillName = j_shichen_conv.name
    return card
  end,
  -- 技能只在“谶”存在时授予，故不再查标记/阶段（标记同步延迟会让按钮常灰）
  enabled_at_play = function(self, player)
    return true
  end,
  enabled_at_response = function(self, player)
    return chenName(player) ~= nil and #sameSuitHandIds(player) > 0
  end,
  before_use = function(self, player, use)
    -- 记录本回合已以此法转化（回合结束时若未转化则摸一张）
    player.room:setPlayerMark(player, "j_shichen_conv-turn", 1)
  end,
})

-- 测试：转化技能确实注册并授予（此前未单独成文件，授予会静默失败）
j_shichen_conv:addTest(function(room, me)
  local chen, same
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "j_shichen")
    me.phase = Player.Play
    room.current = me
    chen = room:printCard("slash", Card.Spade, 7)
    same = room:printCard("jink", Card.Spade, 9)
    room:obtainCard(me, { chen, same }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(chen, "@@j_shichen_chen", 1)
    room:setPlayerMark(me, "j_shichen_chen_id", chen.id)
    room:setPlayerMark(me, "j_shichen_chen_name", "slash")
    room:setPlayerMark(me, "j_shichen_chen_suit", Card.Spade)
    room:handleAddLoseSkills(me, "j_shichen_conv")
  end)
  FkTest.runInRoom(function()
    local vs = Fk.skills["j_shichen_conv"]
    lu.assertNotNil(vs, "【谶】必须注册进 Fk.skills（否则授予静默失败）")
    lu.assertTrue(me:hasSkill("j_shichen_conv"), "【谶】应能授予")
    lu.assertTrue(vs:enabledAtPlay(me), "出牌阶段按钮应可用")
    local card = vs:viewAs(me, { same.id })
    lu.assertNotNil(card, "同花色手牌应能转化为“谶”")
    lu.assertEquals(card.name, "slash", "转化后的牌名应为“谶”的牌名")
    lu.assertEquals(card.skillName, "j_shichen_conv", "虚拟牌应记【谶】技能名")
  end)
end)

return j_shichen_conv
