-- 计刘晔·破橹
-- ①你视为拥有攻击范围内所有角色武器栏武器的技能（获得技能，与攻击范围是否变化无关）。
-- ②当你攻击范围增加后，你可以视为使用任意张牌名字数之和等于本次攻击范围增加值的牌。
local j_polu = fk.CreateSkill {
  name = "j_polu",
}

Fk:loadTranslationTable{
  ["j_polu"] = "破橹",
  [":j_polu"] = "你视为拥有攻击范围内所有角色武器栏武器的技能。当你攻击范围增加后，你可以视为使用任意张牌名字数之和等于本次攻击范围增加值的牌。",

  ["#j_polu-use"] = "破橹：请选择牌名字数之和等于 %arg 的牌（可点取消结束）",
}

local function utf8len(s)
  local len, i = 0, 1
  while i <= #s do
    local b = string.byte(s, i)
    if b < 128 then i = i + 1
    elseif b < 224 then i = i + 2
    elseif b < 240 then i = i + 3
    else i = i + 4 end
    len = len + 1
  end
  return len
end

-- 仅取“已加入本局游戏的牌”的牌名（牌堆、弃牌堆、场上明置的装备/判定区），
-- 且排除装备牌（破橹不可使用装备牌），避免“印”出本局不存在的牌。
local function inGameCardNames(room)
  local names = {}
  local function add(ids)
    for _, id in ipairs(ids or {}) do
      local card = Fk:getCardById(id)
      if card and card.trueName and card.trueName ~= ""
        and card.type ~= Card.TypeSkill and card.type ~= Card.TypeEquip then
        table.insertIfNeed(names, card.trueName)
      end
    end
  end
  add(room.draw_pile)
  add(room.discard_pile)
  for _, p in ipairs(room.players) do
    add(p:getCardIds("ej"))
  end
  return names
end

-- 重新计算“视为拥有攻击范围内所有角色武器栏武器的技能”
local function recomputeGrants(room, player)
  local granted = player:getTableMark("j_polu_granted")
  local newSet = {}
  if not player.dead and player:hasSkill(j_polu.name) then
    for _, p in ipairs(room.alive_players) do
      if p ~= player and player:inMyAttackRange(p) then
        for _, wid in ipairs(p:getEquipments(Card.SubtypeWeapon)) do
          local wcard = p:getVirtualEquip(wid) or Fk:getCardById(wid)
          -- 装备技能存于 equip_skill(s)，需经 getEquipSkills 获取（Card.skill 仅虚拟牌才有）
          if wcard.getEquipSkills then
            for _, sk in ipairs(wcard:getEquipSkills(p)) do
              if sk and sk.name then
                table.insertIfNeed(newSet, sk.name)
              end
            end
          end
        end
      end
    end
  end
  for _, sname in ipairs(granted) do
    if not table.contains(newSet, sname) then
      room:handleAddLoseSkills(player, "-" .. sname, nil, false, true)
    end
  end
  for _, sname in ipairs(newSet) do
    if not table.contains(granted, sname) then
      room:handleAddLoseSkills(player, sname, nil, false, true)
    end
  end
  room:setPlayerMark(player, "j_polu_granted", newSet)
end

-- 更新攻击范围：重算武器技能；仅在攻击范围“增加”时询问视为使用
-- 破橹②只认“非装备来源”的攻击范围（排除自身装备区：基础1+技能加成）：
-- 自己装备武器或他人装备武器都不改变该值，故不会因装备变动误触发印牌；
-- 破橹①（视为拥有范围内角色武器技能）仍按真实攻击范围（含武器）实时同步。
local function updatePolu(room, player)
  if not player:hasSkill(j_polu.name) then return end
  local prev = player:getMark("j_polu_range")
  local excl = player:getCardIds("e")
  local cur = player:getAttackRange(excl)
  fk.qInfo("POLU_DEBUG prev=" .. prev .. " cur=" .. cur .. " excl=" .. #excl .. " real=" .. player:getAttackRange())
  room:setPlayerMark(player, "j_polu_range", cur)
  -- 同步武将牌上显示的攻击范围（真实范围，含武器）
  room:setPlayerMark(player, "@j_zhushi_range", player:getAttackRange())
  -- 前半段：视为拥有攻击范围内角色武器技能（与范围是否变化无关，始终同步）
  recomputeGrants(room, player)
  -- 防嵌套：视为使用牌引发的新变化只更新记录，不再递归询问
  if room:getTag("j_polu_lock") then return end
  -- 仅在“增加”时发动；范围减少（如轮次结束加成消失）不触发
  local delta = (prev ~= 0) and (cur - prev) or 0
  if delta <= 0 or player.dead then return end
  room:setTag("j_polu_lock", true)
  local remaining = delta
  -- 本次发动中已使用过的牌名（每个牌名限一次）
  local usedNames = {}
  while remaining > 0 and not player.dead do
    -- 候选：本局已有的牌名，字数不超过剩余值，且本次尚未使用过
    local candidates = {}
    for _, name in ipairs(inGameCardNames(room)) do
      if not table.contains(usedNames, name) then
        local n = utf8len(Fk:translate(name))
        if n > 0 and n <= remaining then
          table.insert(candidates, name)
        end
      end
    end
    if #candidates == 0 then break end
    local choice = room:askToChoice(player, {
      choices = candidates,
      skill_name = j_polu.name,
      prompt = "#j_polu-use:::" .. remaining,
      cancelable = true,
    })
    if not choice or choice == "" or choice == "Cancel" then break end
    local used = room:askToUseVirtualCard(player, {
      name = choice,
      skill_name = j_polu.name,
      cancelable = true,
    })
    if not used then break end
    table.insertIfNeed(usedNames, choice)
    remaining = remaining - utf8len(Fk:translate(choice))
  end
  room:setTag("j_polu_lock", false)
end

-- 攻击范围检测时机：回合开始 / 轮次开始 / 装备区变动 / 烛势发动后
j_polu:addEffect(fk.TurnStart, {
  global = true,
  -- 自动发动（内部再按需询问），避免默认的“是否发动”弹窗
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_polu.name) and not player.dead
  end,
  on_use = function(self, event, target, player, data)
    updatePolu(player.room, player)
  end,
})

j_polu:addEffect(fk.RoundStart, {
  global = true,
  -- 自动发动（内部再按需询问），避免默认的“是否发动”弹窗
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_polu.name) and not player.dead
  end,
  on_use = function(self, event, target, player, data)
    updatePolu(player.room, player)
  end,
})

j_polu:addEffect(fk.AfterCardsMove, {
  global = true,
  -- 自动发动（内部再按需询问），避免默认的“是否发动”弹窗
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_polu.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if move.fromArea == Card.PlayerEquip or move.toArea == Card.PlayerEquip then
        return true
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    updatePolu(player.room, player)
  end,
})

-- 注意：fk.SkillEffect 在技能效果执行“之前”触发，必须用 fk.AfterSkillEffect
-- 才能在烛势改完攻击范围（on_use 内写标记）之后再读取范围。
j_polu:addEffect(fk.AfterSkillEffect, {
  global = true,
  -- 自动发动（内部再按需询问），避免默认的“是否发动”弹窗
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_polu.name) or player.dead then return false end
    if not data or not data.skill then return false end
    -- data.skill 为效果子技能，需经 getSkeleton() 取骨架名
    local skname = data.skill.name
    if data.skill.getSkeleton then
      local skeleton = data.skill:getSkeleton()
      if skeleton then skname = skeleton.name end
    end
    return skname == "j_zhushi"
  end,
  on_use = function(self, event, target, player, data)
    updatePolu(player.room, player)
  end,
})

-- 测试：攻击范围内角色装备武器 → 视为拥有其武器技能；卸下后失去
j_polu:addTest(function(room, me)
  local comp2 = room.players[2]
  local bow
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_polu.name)
    bow = room:printCard("crossbow", Card.Diamond, 1)
  end)
  FkTest.runInRoom(function()
    room:moveCardTo(bow.id, Player.Equip, comp2, fk.ReasonPut, "test")
    lu.assertTrue(me:hasSkill("#crossbow_skill"), "应视为拥有攻击范围内角色的武器技能")
    room:moveCardTo(bow.id, Card.DrawPile, nil, fk.ReasonPut, "test")
    lu.assertFalse(me:hasSkill("#crossbow_skill"), "卸下后应失去武器技能")
  end)
end)

-- 测试：自身装备武器不触发破橹印牌（非装备来源范围不变），真实范围与武器技能照常同步
j_polu:addTest(function(room, me)
  local blade
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_polu.name)
    room:setPlayerMark(me, "j_polu_range", 1)
    blade = room:printCard("blade", Card.Spade, 1)
  end)
  FkTest.runInRoom(function()
    local usedNames = {}
    local promptCount = 0
    local origChoice = room.askToChoice
    local origUse = room.askToUseVirtualCard
    room.askToChoice = function(self, who, params)
      if who == me then promptCount = promptCount + 1 end
      return origChoice(self, who, params)
    end
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then
        table.insert(usedNames, params.name)
        return true
      end
      return origUse(self, who, params)
    end
    room:moveCardTo(blade.id, Player.Equip, me, fk.ReasonPut, "test")
    room.askToChoice = origChoice
    room.askToUseVirtualCard = origUse
    lu.assertEquals(promptCount, 0, "自身装备武器不应触发破橹印牌")
    lu.assertEquals(#usedNames, 0, "自身装备武器不应视为使用牌")
    lu.assertEquals(me:getMark("j_polu_range"), 1, "非装备来源范围应保持不变")
    lu.assertEquals(me:getAttackRange(), 3, "真实攻击范围应为武器范围3")
    lu.assertEquals(me:getMark("@j_zhushi_range"), 3, "武将牌应显示真实攻击范围")

    -- 卸下武器（真实范围减少）同样不触发印牌
    local promptCount2 = 0
    local origChoice2 = room.askToChoice
    room.askToChoice = function(self, who, params)
      if who == me then promptCount2 = promptCount2 + 1 end
      return origChoice2(self, who, params)
    end
    room:moveCardTo(blade.id, Card.DrawPile, nil, fk.ReasonPut, "test")
    room.askToChoice = origChoice2
    lu.assertEquals(promptCount2, 0, "卸下武器不应触发破橹印牌")
    lu.assertEquals(me:getMark("j_polu_range"), 1, "非装备来源范围仍为1")
    lu.assertEquals(me:getAttackRange(), 1, "真实攻击范围应回到1")
  end)
end)

-- 测试：其他角色装备武器不触发 me 的破橹印牌（me 非装备来源范围不变）
j_polu:addTest(function(room, me)
  local comp2 = room.players[2]
  local bow
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_polu.name)
    room:setPlayerMark(me, "j_polu_range", 1)
    bow = room:printCard("crossbow", Card.Diamond, 1)
  end)
  FkTest.runInRoom(function()
    local promptCount = 0
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      if who == me then promptCount = promptCount + 1 end
      return origChoice(self, who, params)
    end
    room:moveCardTo(bow.id, Player.Equip, comp2, fk.ReasonPut, "test")
    room.askToChoice = origChoice
    lu.assertEquals(promptCount, 0, "其他角色装备武器不应触发me破橹印牌")
    lu.assertEquals(me:getMark("j_polu_range"), 1, "me非装备来源范围应不变")
  end)
end)

-- 测试：烛势增加范围后（AfterSkillEffect）应触发破橹
j_polu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "j_polu|j_zhushi", nil, false, true)
    room:setPlayerMark(me, "j_polu_range", 1)
    -- 模拟烛势重铸 2 张：本轮范围 +2，实际范围 1→3
    room:setPlayerMark(me, "j_zhushi_range-round", 2)
  end)
  FkTest.runInRoom(function()
    local used = 0
    local origChoice = room.askToChoice
    local origUse = room.askToUseVirtualCard
    room.askToChoice = function(self, who, params)
      if who == me then
        -- 优先取单字牌名，便于凑出恰好 2 字
        for _, c in ipairs(params.choices) do
          if #Fk:translate(c) <= 3 then return c end
        end
        return params.choices[1]
      end
      return origChoice(self, who, params)
    end
    room.askToUseVirtualCard = function(self, who, params)
      if who == me then
        used = used + 1
        return true
      end
      return origUse(self, who, params)
    end
    room.logic:trigger(fk.AfterSkillEffect, me, { skill = Fk.skills["j_zhushi"] })
    room.askToChoice = origChoice
    room.askToUseVirtualCard = origUse
    lu.assertEquals(used, 2, "烛势增加范围后应触发破橹使用两张单字牌")
    lu.assertEquals(me:getMark("j_polu_range"), 3, "范围记录应为3")
  end)
end)

return j_polu
