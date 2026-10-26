-- 计国渊·籍田
-- 结束阶段，你可以选择一名角色，令其展示所有手牌。若其中包含装备牌，你可以获得之；
-- 若其中包含锦囊牌，你摸一张牌；若没有基本牌，你可以对其造成一点伤害。
local j_guoyuan_jitian = fk.CreateSkill {
  name = "j_guoyuan_jitian",
}

Fk:loadTranslationTable{
  ["j_guoyuan_jitian"] = "籍田",
  [":j_guoyuan_jitian"] = "结束阶段，你可以选择一名角色，令其展示所有手牌。若其中包含装备牌，你可以获得之；" ..
    "若其中包含锦囊牌，你摸一张牌；若没有基本牌，你可以对其造成一点伤害。",

  ["#j_guoyuan_jitian-invoke"] = "籍田：是否选择一名角色，令其展示所有手牌？",
  ["#j_guoyuan_jitian-choose"] = "籍田：选择一名角色，令其展示所有手牌",
  ["#j_guoyuan_jitian-equip"] = "籍田：是否获得 %src 展示的装备牌？",
  ["#j_guoyuan_jitian-damage"] = "籍田：%src 展示的牌中没有基本牌，是否对其造成1点伤害？",

  ["$j_guoyuan_jitian1"] = "民以食为天，仓廪实而知礼节。",
  ["$j_guoyuan_jitian2"] = "劝课农桑，广开田亩。",
}

j_guoyuan_jitian:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_guoyuan_jitian.name)
      and player.phase == Player.Finish
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_guoyuan_jitian.name,
      prompt = "#j_guoyuan_jitian-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local tos = room:askToChoosePlayers(player, {
      targets = room.alive_players,
      min_num = 1,
      max_num = 1,
      skill_name = j_guoyuan_jitian.name,
      prompt = "#j_guoyuan_jitian-choose",
    })
    if #tos == 0 then return end
    local to = tos[1]
    if to.dead then return end

    local ids = to:getCardIds("h")
    if #ids > 0 then
      room:showCards(ids, to, player)
    end

    -- 以展示时的手牌快照判定三种分支
    local equips, tricks, basics = {}, {}, {}
    for _, id in ipairs(ids) do
      local c = Fk:getCardById(id)
      if c.type == Card.TypeEquip then
        table.insert(equips, id)
      elseif c.type == Card.TypeTrick then
        table.insert(tricks, id)
      elseif c.type == Card.TypeBasic then
        table.insert(basics, id)
      end
    end

    -- 含装备牌：你可以获得之（目标是自己的话，牌本来就在自己手里，跳过）
    if #equips > 0 and to ~= player and not player.dead and not to.dead then
      local ok = room:askToSkillInvoke(player, {
        skill_name = j_guoyuan_jitian.name,
        prompt = "#j_guoyuan_jitian-equip::" .. to.id,
      })
      if ok and not to.dead then
        equips = table.filter(equips, function(id)
          return table.contains(to:getCardIds("he"), id)
        end)
        if #equips > 0 then
          room:obtainCard(player, equips, true, fk.ReasonPrey, to, j_guoyuan_jitian.name)
        end
      end
    end

    -- 含锦囊牌：你摸一张牌（强制）
    if #tricks > 0 and not player.dead then
      room:drawCards(player, 1, j_guoyuan_jitian.name)
    end

    -- 没有基本牌：你可以对其造成一点伤害
    if #basics == 0 and not player.dead and not to.dead then
      local ok = room:askToSkillInvoke(player, {
        skill_name = j_guoyuan_jitian.name,
        prompt = "#j_guoyuan_jitian-damage::" .. to.id,
      })
      if ok and not to.dead then
        room:damage{
          from = player,
          to = to,
          damage = 1,
          damageType = fk.NormalDamage,
          skillName = j_guoyuan_jitian.name,
        }
      end
    end
  end,
})

-- 测试1：目标手牌含装备牌 → 国渊可以获得该装备牌
j_guoyuan_jitian:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guoyuan_jitian.name)
    me.phase = Player.Finish
    comp.hp = comp.maxHp
    local equip = room:printCard("qinggang_sword", Card.Spade, 3)
    local basic = room:printCard("slash", Card.Club, 4)
    room:obtainCard(comp, { equip.id, basic.id }, true, fk.ReasonDraw, comp, "test")

    local realChoose = room.askToChoosePlayers
    local realInvoke = room.askToSkillInvoke
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_guoyuan_jitian.name then return { comp } end
      return realChoose(self, who, params)
    end
    room.askToSkillInvoke = function(self, who, params)
      if params.skill_name == j_guoyuan_jitian.name then return true end
      return realInvoke(self, who, params)
    end
    local eff = j_guoyuan_jitian.effects[1]
    eff:use(nil, me, me, {})
    room.askToChoosePlayers = realChoose
    room.askToSkillInvoke = realInvoke

    lu.assertTrue(table.contains(me:getCardIds("he"), equip.id), "国渊应获得目标展示的装备牌")
    lu.assertFalse(table.contains(comp:getCardIds("h"), equip.id), "装备牌应离开目标手牌")
  end)
end)

-- 测试2：目标手牌无基本牌 → 可以对目标造成1点伤害；且含锦囊时国渊摸一张
j_guoyuan_jitian:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guoyuan_jitian.name)
    me.phase = Player.Finish
    comp.hp = comp.maxHp
    -- 清空目标手牌，改成两张锦囊（无基本牌）
    room:moveCards{
      ids = comp:getCardIds("h"),
      toArea = Card.DiscardPile,
      reason = fk.ReasonDiscard,
      from = comp,
    }
    local t1 = room:printCard("dismantlement", Card.Spade, 3)
    local t2 = room:printCard("ex_nihilo", Card.Heart, 4)
    room:obtainCard(comp, { t1.id, t2.id }, true, fk.ReasonDraw, comp, "test")

    local realChoose = room.askToChoosePlayers
    local realInvoke = room.askToSkillInvoke
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_guoyuan_jitian.name then return { comp } end
      return realChoose(self, who, params)
    end
    room.askToSkillInvoke = function(self, who, params)
      if params.skill_name == j_guoyuan_jitian.name then return true end
      return realInvoke(self, who, params)
    end
    local before = #me:getCardIds("h")
    local hp_before = comp.hp
    local eff = j_guoyuan_jitian.effects[1]
    eff:use(nil, me, me, {})
    room.askToChoosePlayers = realChoose
    room.askToSkillInvoke = realInvoke

    lu.assertEquals(comp.hp, hp_before - 1, "无基本牌时应对目标造成1点伤害")
    lu.assertTrue(#me:getCardIds("h") > before, "含锦囊牌时国渊应摸一张牌")
  end)
end)

-- 测试3：目标有基本牌时不造成伤害
j_guoyuan_jitian:addTest(function(room, me)
  local comp = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guoyuan_jitian.name)
    me.phase = Player.Finish
    comp.hp = comp.maxHp
    room:moveCards{
      ids = comp:getCardIds("h"),
      toArea = Card.DiscardPile,
      reason = fk.ReasonDiscard,
      from = comp,
    }
    local b1 = room:printCard("jink", Card.Spade, 3)
    room:obtainCard(comp, { b1.id }, true, fk.ReasonDraw, comp, "test")

    local realChoose = room.askToChoosePlayers
    local realInvoke = room.askToSkillInvoke
    room.askToChoosePlayers = function(self, who, params)
      if params.skill_name == j_guoyuan_jitian.name then return { comp } end
      return realChoose(self, who, params)
    end
    room.askToSkillInvoke = function(self, who, params)
      if params.skill_name == j_guoyuan_jitian.name then return true end
      return realInvoke(self, who, params)
    end
    local hp_before = comp.hp
    local eff = j_guoyuan_jitian.effects[1]
    eff:use(nil, me, me, {})
    room.askToChoosePlayers = realChoose
    room.askToSkillInvoke = realInvoke

    lu.assertEquals(comp.hp, hp_before, "目标有基本牌时不应造成伤害")
  end)
end)

return j_guoyuan_jitian
