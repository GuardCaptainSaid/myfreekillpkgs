-- 计庞统·火凤（限定技）
-- 出牌阶段，你可以弃置所有手牌，令至多等量名角色受到1点火焰伤害。
-- 当你累计造成7点非属性伤害时，此技能视为未发动过。
local j_pangtong_huofeng = fk.CreateSkill {
  name = "j_pangtong_huofeng",
  tags = { Skill.Limited },
}

local USED = "j_pangtong_huofeng_used"    -- 限定技已发动（纯内部标记）
local ACCUM = "j_pangtong_huofeng_accum"  -- 累计造成的非属性伤害点数
local NEED = 7

Fk:loadTranslationTable{
  ["j_pangtong_huofeng"] = "火凤",
  [":j_pangtong_huofeng"] = "限定技，出牌阶段，你可以弃置所有手牌，令至多等量名角色受到1点火焰伤害。" ..
    "当你累计造成7点非属性伤害时，此技能视为未发动过。",

  ["#j_pangtong_huofeng-prompt"] = "火凤：弃置所有手牌，令至多等量名角色受到1点火焰伤害",
  ["#j_pangtong_huofeng-target"] = "火凤：选择至多 %arg 名角色受到1点火焰伤害",
  ["#j_pangtong_huofeng-reborn"] = "火凤：已累计造成7点非属性伤害，此技能视为未发动过！",

  ["$j_pangtong_huofeng1"] = "凤鸣九天，烈焰焚天！",
  ["$j_pangtong_huofeng2"] = "浴火之凤，其翼若垂天之云！",
}

j_pangtong_huofeng:addEffect("active", {
  anim_type = "offensive",
  prompt = "#j_pangtong_huofeng-prompt",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    if player.room and player.phase ~= Player.Play then return false end
    return #player:getCardIds("h") > 0 and player:getMark(USED) == 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local cards = player:getCardIds("h")
    local n = #cards
    if n == 0 then return end
    room:setPlayerMark(player, USED, 1)
    room:throwCard(cards, j_pangtong_huofeng.name, player, player)
    if player.dead then return end

    local maxNum = math.min(n, #room.alive_players)
    if maxNum <= 0 then return end
    local tos = room:askToChoosePlayers(player, {
      targets = room.alive_players,
      min_num = 1,
      max_num = maxNum,
      skill_name = j_pangtong_huofeng.name,
      prompt = "#j_pangtong_huofeng-target:::" .. maxNum,
      cancelable = true,
    })
    for _, to in ipairs(tos) do
      if not player.dead and not to.dead then
        room:damage{
          from = player,
          to = to,
          damage = 1,
          damageType = fk.FireDamage,
          skillName = j_pangtong_huofeng.name,
        }
      end
    end
  end,
})

-- 累计造成7点非属性（普通）伤害 → 此技能视为未发动过
j_pangtong_huofeng:addEffect(fk.Damaged, {
  anim_type = "offensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_pangtong_huofeng.name) or player.dead then return false end
    if data.from ~= player then return false end
    if data.damageType ~= fk.NormalDamage then return false end
    return (data.damage or 0) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local acc = player:getMark(ACCUM) + data.damage
    if acc >= NEED then
      acc = acc - NEED
      if player:getMark(USED) > 0 then
        room:setPlayerMark(player, USED, 0)
        room:notifySkillInvoked(player, j_pangtong_huofeng.name, "offensive")
        player:broadcastSkillInvoke(j_pangtong_huofeng.name)
        room:sendLog{
          type = "#j_pangtong_huofeng-reborn",
          from = player.id,
        }
      end
    end
    room:setPlayerMark(player, ACCUM, acc)
  end,
})

-- 测试1：弃置所有手牌，令至多等量名角色各受到1点火焰伤害
j_pangtong_huofeng:addTest(function(room, me)
  local comp2, comp3 = room.players[2], room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_huofeng.name)
    me.phase = Player.Play
    room:setPlayerMark(me, USED, 0)
    room:moveCards{
      ids = me:getCardIds("h"),
      toArea = Card.DiscardPile,
      reason = fk.ReasonDiscard,
      from = me,
    }
    local c1 = room:printCard("slash", Card.Spade, 3)
    local c2 = room:printCard("jink", Card.Heart, 4)
    local c3 = room:printCard("peach", Card.Diamond, 5)
    room:obtainCard(me, { c1.id, c2.id, c3.id }, true, fk.ReasonDraw, me, "test")
    comp2.hp = comp2.maxHp
    comp3.hp = comp3.maxHp

    local realChoose = room.askToChoosePlayers
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_pangtong_huofeng.name then
        lu.assertEquals(params.max_num, 3, "上限应为弃置的手牌数")
        return { comp2, comp3 }
      end
      return realChoose(self, who, params)
    end

    local eff = j_pangtong_huofeng.effects[1]
    eff:onUse(room, { from = me, tos = {}, cards = {} })
    room.askToChoosePlayers = realChoose

    lu.assertEquals(#me:getCardIds("h"), 0, "应弃置所有手牌")
    lu.assertEquals(comp2.hp, comp2.maxHp - 1, "目标1应受到1点伤害")
    lu.assertEquals(comp3.hp, comp3.maxHp - 1, "目标2应受到1点伤害")
    lu.assertTrue(me:getMark(USED) > 0, "限定技应记录已发动")
  end)
end)

-- 测试2：累计造成7点非属性伤害后，限定技视为未发动过
j_pangtong_huofeng:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_huofeng.name)
    room:setPlayerMark(me, USED, 1)
    room:setPlayerMark(me, ACCUM, 0)
    comp.hp = comp.maxHp

    for i = 1, 6 do
      local dmg = DamageData:new{ from = me, to = comp, damage = 1, damageType = fk.NormalDamage }
      room.logic:trigger(fk.Damaged, comp, dmg)
    end
    lu.assertEquals(me:getMark(ACCUM), 6, "应累计6点")
    lu.assertTrue(me:getMark(USED) > 0, "未满7点时不可再次发动")

    local dmg = DamageData:new{ from = me, to = comp, damage = 1, damageType = fk.NormalDamage }
    room.logic:trigger(fk.Damaged, comp, dmg)
    lu.assertEquals(me:getMark(ACCUM), 0, "满7点后累计应清零")
    lu.assertEquals(me:getMark(USED), 0, "满7点后此技能视为未发动过")
  end)
end)

-- 测试3：火焰/雷电等属性伤害不计入累计
j_pangtong_huofeng:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_pangtong_huofeng.name)
    room:setPlayerMark(me, USED, 1)
    room:setPlayerMark(me, ACCUM, 0)
    comp.hp = comp.maxHp

    local dmg = DamageData:new{ from = me, to = comp, damage = 1, damageType = fk.FireDamage }
    room.logic:trigger(fk.Damaged, comp, dmg)
    lu.assertEquals(me:getMark(ACCUM), 0, "属性伤害不应计入非属性伤害累计")
  end)
end)

return j_pangtong_huofeng
