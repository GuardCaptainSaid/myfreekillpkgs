-- 鲍三娘一号·授武
-- 你选择场上一名有武器的角色或你自己，令其将武器暂时置于你的武将旁称为「传刀」；持有「传刀」期间，你与该角色使用【杀】均无视距离，且每回合首次出杀可多选择一名目标。回合结束时，若「传刀」仍在你旁，需归还武器；若你本回合以此法击杀角色，则永久获得该武器。
local s_shouwu = fk.CreateSkill {
  name = "s_shouwu",
}

Fk:loadTranslationTable{
  ["s_shouwu"] = "授武",
  [":s_shouwu"] = "出牌阶段限一次，你选择场上一名有武器的角色或你自己，令其将武器暂时置于你的武将旁称为「传刀」；持有「传刀」期间，你与该角色使用【杀】均无视距离，且每回合首次出杀可多选择一名目标。回合结束时，若「传刀」仍在你旁，需归还武器；若你本回合以此法击杀角色，则永久获得该武器。",

  ["#s_shouwu"] = "授武：选择一名有武器的角色或你自己",
  ["@@s_chuandao_target"] = "传刀对象",
  ["@@s_chuandao_first"] = "传刀首杀",
}

local function hasWeapon(p)
  for _, id in ipairs(p:getCardIds("e")) do
    local card = Fk:getCardById(id)
    if card and card.sub_type == Card.SubtypeWeapon then return true end
  end
  return false
end

local function getWeaponId(p)
  for _, id in ipairs(p:getCardIds("e")) do
    local card = Fk:getCardById(id)
    if card and card.sub_type == Card.SubtypeWeapon then return id end
  end
  return nil
end

s_shouwu:addEffect("active", {
  anim_type = "control",
  prompt = "#s_shouwu",
  max_phase_use_time = 1,
  target_num = 1,
  target_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    if to_select == player then return true end
    return not to_select.dead and hasWeapon(to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    local weaponId = getWeaponId(target)
    if weaponId then
      room:addToPile(player, "s_chuandao", { weaponId }, true, s_shouwu.name, target)
    end
    room:setPlayerMark(player, "@@s_chuandao_target", target.id)
    room:setPlayerMark(target, "@@s_chuandao_owner", player.id)
    -- 传刀目标获得派生技能：其使用【杀】对你无视距离
    if target ~= player and not target:hasSkill("s_chuandao_link") then
      room:handleAddLoseSkills(target, "s_chuandao_link", nil, false, true)
    end
  end,
})

-- 我使用【杀】：对传刀对象无视距离；本回合首次出杀额外一目标
s_shouwu:addEffect("targetmod", {
  bypass_distances = function(self, player, skill, card, to)
    if not player:hasSkill(s_shouwu.name) then return false end
    if not card or card.trueName ~= "slash" then return false end
    local tid = player:getMark("@@s_chuandao_target")
    if tid <= 0 or not to then return false end
    return to.id == tid
  end,
  extra_target_func = function(self, player, skill)
    if not player:hasSkill(s_shouwu.name) then return 0 end
    if skill and skill.trueName == "slash_skill" and player:getMark("@@s_chuandao_target") > 0 then
      if player:getMark("@@s_chuandao_first") == 0 then
        return 1
      end
    end
    return 0
  end,
})

-- 记录本回合已出杀（首次杀用后）
s_shouwu:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return player == data.from and player:hasSkill(s_shouwu.name) and data.card
      and data.card.trueName == "slash"
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@@s_chuandao_first", 1)
  end,
})

-- 回合开始重置首杀标记
s_shouwu:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and data.to == Player.Start and player:getMark("@@s_chuandao_first") > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@@s_chuandao_first", 0)
  end,
})

-- 回合结束：归还传刀（若仍在）
s_shouwu:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(s_shouwu.name) and #player:getPile("s_chuandao") > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local pile = player:getPile("s_chuandao")
    local tid = player:getMark("@@s_chuandao_target")
    local owner = room:getPlayerById(tid)
    if owner and #pile > 0 then
      room:moveCardTo(pile[1], Player.Equip, owner, fk.ReasonPut, s_shouwu.name)
    end
    room:setPlayerMark(player, "@@s_chuandao_target", 0)
    if owner then
      room:setPlayerMark(owner, "@@s_chuandao_owner", 0)
      if owner:hasSkill("s_chuandao_link") then
        room:handleAddLoseSkills(owner, "-s_chuandao_link", nil, false, true)
      end
    end
  end,
})

-- 击杀角色：永久获得传刀武器
s_shouwu:addEffect(fk.Death, {
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(s_shouwu.name) then return false end
    if #player:getPile("s_chuandao") == 0 then return false end
    return data and data.damage and data.damage.from == player
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local pile = player:getPile("s_chuandao")
    local tid = player:getMark("@@s_chuandao_target")
    local owner = room:getPlayerById(tid)
    if #pile > 0 then
      room:moveCardTo(pile[1], Player.Equip, player, fk.ReasonPut, s_shouwu.name)
    end
    room:setPlayerMark(player, "@@s_chuandao_target", 0)
    if owner then
      room:setPlayerMark(owner, "@@s_chuandao_owner", 0)
      if owner:hasSkill("s_chuandao_link") then
        room:handleAddLoseSkills(owner, "-s_chuandao_link", nil, false, true)
      end
    end
  end,
})

-- 测试1：选目标传刀 → 我方杀对传刀对象无视距离、首杀额外目标；回合结束归还
s_shouwu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_shouwu.name)
    local sword = room:printCard("sword", Card.Spade, 6)
    room:moveCardTo(sword, Player.Equip, comp2, fk.ReasonPut, "test")
  end)
  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    s_shouwu:onUse(room, { from = me, tos = { comp2 }, cards = {}, cost_data = {} })
    lu.assertEquals(#me:getPile("s_chuandao"), 1, "授武：武器应置于传刀区")
    lu.assertEquals(me:getMark("@@s_chuandao_target"), comp2.id, "授武：应记录传刀对象")
    lu.assertTrue(comp2:hasSkill("s_chuandao_link"), "授武：传刀对象应获得派生技能")
    -- targetmod 检查：对传刀对象杀无视距离
    local tm = nil
    for k, v in pairs(Fk.skills) do
      if string.startsWith(k, "#s_shouwu_") and string.find(k, "targetmod", 1, true) then
        tm = v
        break
      end
    end
    lu.assertNotNil(tm, "授武：targetmod 应已生成")
    if tm then
      local fakeCard = { trueName = "slash" }
      local fakeSkill = { trueName = "slash_skill" }
      lu.assertTrue(tm:bypassDistancesCheck(me, fakeSkill, fakeCard, comp2), "授武：对传刀对象应无视距离")
      lu.assertEquals(tm:getExtraTargetNum(me, fakeSkill), 1, "授武：本回合首次出杀应额外一目标")
    end
  end)
  FkTest.runInRoom(function()
    -- 回合结束归还
    room.logic:trigger(fk.TurnEnd, me, {})
    lu.assertEquals(#me:getPile("s_chuandao"), 0, "授武：回合结束应归还传刀")
    lu.assertEquals(#comp2:getCardIds("e"), 1, "授武：武器应归还目标装备区")
    lu.assertFalse(comp2:hasSkill("s_chuandao_link"), "授武：归还后应移除派生技能")
  end)
end)

-- 测试2：击杀角色 → 永久获得传刀武器
s_shouwu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, s_shouwu.name)
    local sword = room:printCard("sword", Card.Spade, 6)
    room:moveCardTo(sword, Player.Equip, comp2, fk.ReasonPut, "test")
    s_shouwu:onUse(room, { from = me, tos = { comp2 }, cards = {}, cost_data = {} })
  end)
  FkTest.runInRoom(function()
    -- 击杀（damage.from=me）
    room.logic:trigger(fk.Death, comp2, { damage = { from = me, to = comp2, damage = 1 } })
    lu.assertEquals(#me:getPile("s_chuandao"), 0, "授武：击杀后传刀应清空")
    lu.assertEquals(#me:getCardIds("e"), 1, "授武：击杀后应永久获得该武器")
  end)
end)

return s_shouwu