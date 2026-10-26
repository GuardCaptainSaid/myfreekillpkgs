-- 计许攸·倨功
-- 每名角色的回合限一次，当其他角色于其回合内首次造成伤害或获得牌时，
-- 你可以发动一次"狂言"，然后其下次使用牌的目标必须包含你，且该牌无距离和次数限制。
local j_xuyou_jugong = fk.CreateSkill {
  name = "j_xuyou_jugong",
}

-- `@@` 前缀：标记区只显示文字（不显示数值）
local MUST = "@@j_xuyou_jugong_must"        -- 该角色下次使用牌必须包含许攸为目标
-- 无距离 / 无次数限制：直接用引擎内置标记（引擎的 hasMark 支持前缀 + "-turn" 后缀匹配）
local FREE_DIST = MarkEnum.BypassDistancesLimit .. "-turn"
local FREE_TIMES = MarkEnum.BypassTimesLimit .. "-turn"
local USED = "j_xuyou_jugong_used"          -- 本回合已发动（回合结束清 0）
local FIRST_DMG = "j_xuyou_jugong_first_dmg"   -- 该角色本回合已首次造成伤害
local FIRST_GAIN = "j_xuyou_jugong_first_gain" -- 该角色本回合已首次获得牌

local KUANGYAN = "j_xuyou_kuangyan"

Fk:loadTranslationTable{
  ["j_xuyou_jugong"] = "倨功",
  [":j_xuyou_jugong"] = "每名角色的回合限一次，当其他角色于其回合内首次造成伤害或获得牌时，" ..
    "你可以发动一次“狂言”，然后其下次使用牌的目标必须包含你，且该牌无距离和次数限制。",

  [MUST] = "倨功",
  ["#j_xuyou_jugong-invoke"] = "倨功：是否发动一次“狂言”，并令 %src 下次使用牌必须包含你？",
  ["#j_xuyou_jugong-dmg"] = "倨功：%src 首次造成伤害",

  ["$j_xuyou_jugong1"] = "功在社稷，何须尔等置喙？",
  ["$j_xuyou_jugong2"] = "此功，唯我许子远可成！",
}

-- 取【狂言】的骨架（其中挂了 do_yin / do_yang 复用入口）
local function kuangyanSkeleton()
  local s = Fk.skills[KUANGYAN]
  if s == nil then return nil end
  if s.getSkeleton then
    local skel = s:getSkeleton()
    return skel or s
  end
  return s
end

-- 发动一次"狂言"（按当前形态执行，并按转换技规则翻转形态）
local function invokeKuangyan(room, player)
  local ky = kuangyanSkeleton()
  if not ky or not player:hasSkill(KUANGYAN) then return end
  if player:getSwitchSkillState(KUANGYAN) == fk.SwitchYang then
    if ky.do_yang then ky.do_yang(room, player) end
  else
    if ky.do_yin then ky.do_yin(room, player) end
  end
  -- 手动翻转形态（等同于"发动一次"转换技）
  room:setPlayerMark(player, MarkEnum.SwithSkillPreName .. KUANGYAN,
    player:getSwitchSkillState(KUANGYAN, true))
end

-- 共同的效果：发动狂言 + 给目标角色挂"必须包含你 / 无限制"
local function doJugong(room, player, from)
  room:setPlayerMark(player, USED, 1)
  invokeKuangyan(room, player)
  if from and not from.dead then
    room:setPlayerMark(from, MUST, 1)
    room:setPlayerMark(from, FREE_DIST, 1)
    room:setPlayerMark(from, FREE_TIMES, 1)
  end
end

-- 触发①：其他角色造成伤害
j_xuyou_jugong:addEffect(fk.Damaged, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xuyou_jugong.name) or player.dead then return false end
    if player:getMark(USED) > 0 then return false end
    local from = data and data.from
    if not from or from == player or from.dead then return false end
    -- 每回合首次造成伤害
    return from:getMark(FIRST_DMG) == 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    room:setPlayerMark(from, FIRST_DMG, 1)
    return room:askToSkillInvoke(player, {
      skill_name = j_xuyou_jugong.name,
      prompt = "#j_xuyou_jugong-invoke::" .. from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    doJugong(player.room, player, data.from)
  end,
})

-- 触发②：其他角色获得牌
local function findGainFrom(player, data)
  for _, move in ipairs(data) do
    local to = move.to
    if to and to ~= player and not to.dead
      and move.toArea == Card.PlayerHand
      and move.from ~= to then
      return to
    end
  end
  return nil
end

j_xuyou_jugong:addEffect(fk.AfterCardsMove, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xuyou_jugong.name) or player.dead then return false end
    if player:getMark(USED) > 0 then return false end
    local from = findGainFrom(player, data)
    if not from then return false end
    return from:getMark(FIRST_GAIN) == 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local from = findGainFrom(player, data)
    if not from then return false end
    room:setPlayerMark(from, FIRST_GAIN, 1)
    return room:askToSkillInvoke(player, {
      skill_name = j_xuyou_jugong.name,
      prompt = "#j_xuyou_jugong-invoke::" .. from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    doJugong(player.room, player, findGainFrom(player, data))
  end,
})

-- 其下次使用的牌：目标必须包含许攸
j_xuyou_jugong:addEffect(fk.CardUsing, {
  global = true,
  on_cost = Util.TrueFunc,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xuyou_jugong.name) then return false end
    local from = data and data.from
    if not from or from == player or from.dead then return false end
    return from:getMark(MUST) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    room:setPlayerMark(from, MUST, 0)
    room:setPlayerMark(from, FREE_DIST, 0)
    room:setPlayerMark(from, FREE_TIMES, 0)
    if not player:isAlive() or not data.card then return end
    if table.contains(data.tos or {}, player) then return end

    -- 只有该牌本就可以指许攸时才强制加入目标（【桃】【无中生有】这类不能强加）
    local ok = pcall(function()
      local cs = data.card:getSkill(from)
      if not cs then return end
      if from:isProhibited(player, data.card) then return end
      if not Util.CardTargetFilter(cs, from, player, {}, data.card.subcards or {}, data.card, Util.DummyTable) then
        return
      end
      data.tos = data.tos or {}
      table.insert(data.tos, player)
    end)
    if not ok then return end
  end,
})

-- 回合结束：清理本回合的一次性状态
j_xuyou_jugong:addEffect(fk.TurnEnd, {
  global = true,
  on_cost = Util.TrueFunc,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_xuyou_jugong.name)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, USED, 0)
    for _, p in ipairs(room.players) do
      if p:getMark(FIRST_DMG) > 0 or p:getMark(FIRST_GAIN) > 0
        or p:getMark(MUST) > 0 or p:getMark(FREE_DIST) > 0 or p:getMark(FREE_TIMES) > 0 then
        room:setPlayerMark(p, FIRST_DMG, 0)
        room:setPlayerMark(p, FIRST_GAIN, 0)
        room:setPlayerMark(p, MUST, 0)
        room:setPlayerMark(p, FREE_DIST, 0)
        room:setPlayerMark(p, FREE_TIMES, 0)
      end
    end
  end,
})

-- 测试1：其他角色首次造成伤害 → 可选发动一次狂言 + 挂"必须包含你"标记
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    room:handleAddLoseSkills(comp2, "j_xuyou_kuangyan")
    me.hp = me.maxHp
    comp3.hp = comp3.maxHp
  end)
  FkTest.runInRoom(function()
    -- 让狂言处于阳形态；狂言技能挂在许攸身上（测试用）
    room:handleAddLoseSkills(me, KUANGYAN)
    table.shuffle(room.draw_pile)
    FkTest.setNextReplies(me, { "1" })
    local hp = me.hp
    room:damage{ from = comp2, to = comp3, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me:getMark("j_xuyou_jugong_used"), 1, "倨功应记录本回合已发动")
    lu.assertTrue(comp2:getMark(MUST) > 0, "造成伤害的角色应被标记")
    lu.assertTrue(comp2:getMark(FREE_DIST) > 0, "应获得无距离限制")
    lu.assertTrue(comp2:getMark(FREE_TIMES) > 0, "应获得无次数限制")
  end)
end)

-- 测试2：其下次使用牌时，目标被强制加入许攸
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, { j_xuyou_jugong.name, KUANGYAN })
    me.hp = me.maxHp
    comp3.hp = comp3.maxHp
    room:setPlayerMark(comp2, MUST, 1)
    room:setPlayerMark(comp2, FREE_DIST, 1)
    room:setPlayerMark(comp2, FREE_TIMES, 1)
  end)
  FkTest.runInRoom(function()
    local card = room:printCard("slash", Card.Spade, 7)
    local use = { from = comp2, tos = { comp3 }, card = card }
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertTrue(table.contains(use.tos, me), "许攸应被强制加入目标")
    lu.assertEquals(comp2:getMark(MUST), 0, "标记应在下次使用牌后清除")
    lu.assertEquals(comp2:getMark(FREE_DIST), 0, "无距离限制应清除")
  end)
end)

-- 测试3：回合结束清理一次性状态
j_xuyou_jugong:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xuyou_jugong.name)
    room:setPlayerMark(me, "j_xuyou_jugong_used", 1)
    room:setPlayerMark(comp2, MUST, 1)
  end)
  FkTest.runInRoom(function()
    room.logic:trigger(fk.TurnEnd, comp2, {})
    lu.assertEquals(me:getMark("j_xuyou_jugong_used"), 0, "回合结束应清空本回合发动记录")
    lu.assertEquals(comp2:getMark(MUST), 0, "回合结束应清空标记")
  end)
end)

return j_xuyou_jugong
