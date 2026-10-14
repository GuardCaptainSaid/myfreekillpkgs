local j_hexian = fk.CreateSkill {
  name = "j_hexian",
}

Fk:loadTranslationTable{
  ["j_hexian"] = "和弦",
  [":j_hexian"] = "当你回复体力后，若没有角色处于濒死状态，你可以令一名其他角色回复1点体力，弃置一张装备牌。",

  ["#j_hexian-target"] = "和弦：选择一名角色回复1点体力并弃置一张装备牌",

  ["$j_hexian1"] = "和弦相生，其乐融融。",
  ["$j_hexian2"] = "琴瑟和鸣，天下归心。",
}

local function noOneDying(room)
  for _, p in ipairs(room.alive_players) do
    if p.dying then return false end
  end
  return true
end

local function randomEquipDiscard(room, target, skillName)
  local ids = target:getCardIds("e")
  if #ids == 0 then return nil end
  local cid = ids[room:random(1, #ids)]
  local card = Fk:getCardById(cid)
  room:throwCard({ cid }, skillName, target, target)
  return card
end

-- 回复体力后：令一名其他角色回复1点体力，弃置一张装备牌
j_hexian:addEffect(fk.HpRecover, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_hexian.name) or player.dead then return false end
    if data.who ~= player then return false end
    if #player.room:getOtherPlayers(player) == 0 then return false end
    return noOneDying(player.room)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = room:askToChoosePlayers(player, {
      targets = room:getOtherPlayers(player),
      min_num = 1,
      max_num = 1,
      skill_name = j_hexian.name,
      prompt = "#j_hexian-target",
    })
    if #targets == 0 then return false end
    self.target = targets[1]
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local t = self.target
    self.target = nil
    if t == nil or t.dead then return end
    room:recover{ who = t, num = 1, recoverBy = player, skillName = j_hexian.name }
    if not t.dead then
      randomEquipDiscard(room, t, j_hexian.name)
    end
  end,
})

-- 绝响授予的梅花免疫：直到其下回合开始，不能成为其他角色使用梅花牌的目标
j_hexian:addEffect(fk.TargetConfirming, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_hexian.name) then return false end
    if player:getMark("j_juexiang_club") == 0 then return false end
    if not data.card or data.card.suit ~= Card.Club then return false end
    if data.from == player then return false end
    return data:hasTarget(player)
  end,
  on_use = function(self, event, target, player, data)
    data:removeTarget(player)
  end,
})

-- 其回合开始时清除梅花免疫标记
j_hexian:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_hexian.name) then return false end
    if player:getMark("j_juexiang_club") == 0 then return false end
    return data.to == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_juexiang_club", 0)
  end,
})

j_hexian:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_hexian.name,
  think = function(self, player)
    return false
  end,
})

-- 测试：回复体力后令一名其他角色回复1点体力并弃置一张装备牌
j_hexian:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_hexian.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("guding_blade", Card.Diamond, 8)
    room:useCard{ from = comp2, tos = { comp2 }, card = equip }

    -- 先扣掉 me 与 comp2 一点体力：保证回复事件有效且目标可回血
    room:changeHp(me, -1, fk.LoseHp, "test")
    room:changeHp(comp2, -1, fk.LoseHp, "test")
    local hp_before = comp2.hp
    local eq_before = #comp2:getCardIds("e")
    FkTest.setNextReplies(me, { FkTest.ReplyChoosePlayer({ comp2 }) })
    room:recover{ who = me, num = 1, recoverBy = comp2, skillName = "test" }

    lu.assertEquals(comp2.hp, hp_before + 1, "和弦：目标应回复1点体力")
    lu.assertEquals(#comp2:getCardIds("e"), eq_before - 1, "和弦：目标应弃置一张装备牌")
  end)
end)

return j_hexian