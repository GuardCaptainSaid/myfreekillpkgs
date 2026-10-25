-- 计娄圭·水战
-- 当你的体力值变化时，你可以将一张手牌当作【过河拆桥】使用。
local j_shuizhan = fk.CreateSkill {
  name = "j_shuizhan",
}

Fk:loadTranslationTable{
  ["j_shuizhan"] = "水战",
  [":j_shuizhan"] = "当你的体力值变化时，你可以将一张手牌当作【过河拆桥】使用。",

  ["#j_shuizhan-invoke"] = "水战：是否将一张手牌当作【过河拆桥】使用？",
}

-- 是否有可拆牌的其他角色
local function hasDismantleTarget(room, player)
  for _, p in ipairs(room.alive_players) do
    if p ~= player and #p:getCardIds("hej") > 0 then
      return true
    end
  end
  return false
end

j_shuizhan:addEffect(fk.HpChanged, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_shuizhan.name) or player.dead then return false end
    if data.num == 0 then return false end
    if #player:getCardIds("h") == 0 then return false end
    return hasDismantleTarget(player.room, player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_shuizhan.name,
      prompt = "#j_shuizhan-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 将一张手牌当作【过河拆桥】使用（选牌由 card_filter 限定为手牌）
    room:askToUseVirtualCard(player, {
      name = "dismantlement",
      skill_name = j_shuizhan.name,
      cancelable = true,
      card_filter = { n = { 1, 1 }, pattern = ".", cards = player:getCardIds("h") },
    })
  end,
})

-- 测试：体力变化 → 可发动；体力无变化（num=0）→ 不发动
j_shuizhan:addTest(function(room, me)
  local comp2 = room.players[2]
  local h1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shuizhan.name)
    h1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { h1 }, true, fk.ReasonDraw, me, "test")
    comp2 = room.players[2]
    -- 给对手一张牌，否则没有可拆目标，can_trigger 直接 false
    local c2card = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(comp2, { c2card }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_shuizhan.name].getSkeleton and Fk.skills[j_shuizhan.name]:getSkeleton()
      or Fk.skills[j_shuizhan.name]
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == fk.HpChanged then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 HpChanged 效果")
    -- 注意 can_trigger/on_use 形参顺序为 (self, event, target, player, data)
    lu.assertTrue(spec.can_trigger(nil, nil, me, me, { num = -1 }), "体力变化应可发动")
    lu.assertFalse(spec.can_trigger(nil, nil, me, me, { num = 0 }), "体力未变化不应发动")

    local asked = false
    local origUse = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then
        asked = true
        lu.assertEquals(params.name, "dismantlement", "应视为使用过河拆桥")
        lu.assertEquals(params.card_filter.n[1], 1, "应选择一张手牌")
        return true
      end
      return origUse(self, who, params)
    end
    spec.on_use(nil, nil, me, me, { num = -1 })
    room.askToUseVirtualCard = origUse
    lu.assertTrue(asked, "应发起视为使用【过河拆桥】")
  end)
end)

-- 测试（真实流程）：体力变化 → 弹窗发动 → 真的视为使用【过河拆桥】拆掉目标一张牌
-- 用 setNextReplies 驱动真实交互：回复1=发动；回复2=选子牌+选目标
j_shuizhan:addTest(function(room, me)
  local comp2 = room.players[2]
  local h1, target_card
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shuizhan.name)
    h1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { h1 }, true, fk.ReasonDraw, me, "test")
    target_card = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(comp2, { target_card }, true, fk.ReasonDraw, me, "test")
  end)
  FkTest.runInRoom(function()
    local comp2_cards_before = #comp2:getCardIds("h")
    lu.assertEquals(comp2_cards_before, 1, "目标初始应有1张手牌")
    FkTest.setNextReplies(me, {
      "1",
      { card = { name = "dismantlement", subcards = { h1.id } }, targets = { comp2.id } },
    })
    room:loseHp(me, 1) -- 体力值变化 → 触发水战
    lu.assertFalse(table.contains(me:getCardIds("h"), h1.id), "水战：手牌应被当作过河拆桥用掉")
    lu.assertEquals(#comp2:getCardIds("h"), 0, "水战：应真的拆掉目标一张手牌")
  end)
end)

-- 测试（真实流程）：没有可拆目标时不应弹窗
j_shuizhan:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shuizhan.name)
    local h1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { h1 }, true, fk.ReasonDraw, me, "test")
    -- 清空其他所有角色的牌
    for _, p in ipairs(room.players) do
      if p ~= me then
        local ids = p:getCardIds("hej")
        if #ids > 0 then room:throwCard(ids, "test", p) end
      end
    end
  end)
  FkTest.runInRoom(function()
    local asked = false
    local orig = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params)
      if who == me and params.skill_name == j_shuizhan.name then asked = true end
      return orig(self, who, params)
    end
    room:loseHp(me, 1)
    room.askToSkillInvoke = orig
    lu.assertFalse(asked, "没有可拆目标时不应弹窗")
  end)
end)

return j_shuizhan
