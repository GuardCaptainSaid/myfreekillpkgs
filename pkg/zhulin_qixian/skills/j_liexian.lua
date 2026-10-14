local j_liexian = fk.CreateSkill {
  name = "j_liexian",
}

Fk:loadTranslationTable{
  ["j_liexian"] = "烈弦",
  [":j_liexian"] = "当你回复体力后，若没有角色处于濒死状态，你可以令一名其他角色失去1点体力，随机使用一张装备牌。",

  ["#j_liexian-target"] = "烈弦：选择一名角色失去1点体力并随机使用一张装备牌",

  ["$j_liexian1"] = "烈弦如火，灼人心魄。",
  ["$j_liexian2"] = "弦声刚烈，不容置喙。",
}

local function noOneDying(room)
  for _, p in ipairs(room.alive_players) do
    if p.dying then return false end
  end
  return true
end

local function randomEquipUse(room, target, skillName)
  local equips = {}
  for _, id in ipairs(target:getCardIds("h")) do
    local card = Fk:getCardById(id)
    if card.type == Card.TypeEquip then
      table.insert(equips, id)
    end
  end
  if #equips == 0 then return nil end
  local cid = equips[room:random(1, #equips)]
  local card = Fk:getCardById(cid)
  room:useCard{ from = target, tos = { target }, card = card, skillName = skillName }
  return card
end

-- 回复体力后：令一名其他角色失去1点体力，随机使用一张装备牌
j_liexian:addEffect(fk.HpRecover, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_liexian.name) or player.dead then return false end
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
      skill_name = j_liexian.name,
      prompt = "#j_liexian-target",
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
    room:loseHp(t, 1, j_liexian.name, player)
    if not t.dead then
      randomEquipUse(room, t, j_liexian.name)
    end
  end,
})

-- 绝响授予的梅花免疫：直到其下回合开始，不能成为其他角色使用梅花牌的目标
j_liexian:addEffect(fk.TargetConfirming, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_liexian.name) then return false end
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
j_liexian:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_liexian.name) then return false end
    if player:getMark("j_juexiang_club") == 0 then return false end
    return data.to == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_juexiang_club", 0)
  end,
})

j_liexian:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_liexian.name,
  think = function(self, player)
    return false
  end,
})

-- 测试：回复体力后令一名其他角色失去1点体力并随机使用一张装备牌
j_liexian:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_liexian.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("guding_blade", Card.Heart, 6)
    room:obtainCard(comp2, { equip }, true, fk.ReasonDraw, comp2, "test")
    local hp_before = comp2.hp
    local eq_before = #comp2:getCardIds("e")

    -- 先扣掉 me 一点体力，保证后续回复有效
    room:changeHp(me, -1, fk.LoseHp, "test")
    FkTest.setNextReplies(me, { FkTest.ReplyChoosePlayer({ comp2 }) })
    room:recover{ who = me, num = 1, recoverBy = comp2, skillName = "test" }

    lu.assertEquals(comp2.hp, hp_before - 1, "烈弦：目标应失去1点体力")
    lu.assertEquals(#comp2:getCardIds("e"), eq_before + 1, "烈弦：目标应随机使用一张装备牌")
  end)
end)

return j_liexian