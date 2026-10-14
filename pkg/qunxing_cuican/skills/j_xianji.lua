local j_xianji = fk.CreateSkill {
  name = "j_xianji",
  tags = { Skill.AttachedKingdom },
  attached_kingdom = { "wu" },
}

Fk:loadTranslationTable{
  ["j_xianji"] = "献戟",
  [":j_xianji"] = "吴势力技，出牌阶段限一次，你可以将手牌中的一张装备牌置于其他角色的装备区里，令其选择一项：1、令你摸X张牌（X为其装备区空位数）；2、其弃置Y张牌（Y为其体力值）并令你回复1点体力。",

  ["#j_xianji-choice"] = "献戟：选择一项",
  ["j_xianji_opt1"] = "令其摸X张牌（X为你的装备区空位数）",
  ["j_xianji_opt2"] = "弃置Y张牌（Y为你的体力值），其回复1点体力",
  ["#j_xianji-discard"] = "献戟：弃置 %arg 张牌",
}

j_xianji:addEffect("active", {
  anim_type = "control",
  card_num = 1,
  target_num = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:usedSkillTimes(j_xianji.name, Player.HistoryPhase) > 0 then return false end
    local has_equip = table.find(player:getCardIds("h"), function(id)
      return Fk:getCardById(id).type == Card.TypeEquip
    end)
    if not has_equip then return false end
    -- getOtherPlayers 仅服务端 Room 有，客户端渲染技能按钮时会调用 can_use，必须用通用字段
    return table.find(Fk:currentRoom().players, function(p)
      return p ~= player and p:isAlive()
    end) ~= nil
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).type == Card.TypeEquip
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    if #selected > 0 or to_select == player then return false end
    if #selected_cards == 0 then return false end
    local sub_type = Fk:getCardById(selected_cards[1]).sub_type
    return to_select:hasEmptyEquipSlot(sub_type)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos[1]
    local id = effect.cards[1]

    -- 置于目标装备区
    room:moveCardTo(id, Card.PlayerEquip, to, fk.ReasonPut, j_xianji.name, nil, true, player)

    local choice = room:askToChoice(to, {
      choices = { "j_xianji_opt1", "j_xianji_opt2" },
      skill_name = j_xianji.name,
      prompt = "#j_xianji-choice",
    })

    if choice == "j_xianji_opt1" then
      -- X 为其装备区空位数
      local x = #to:getAvailableEquipSlots() - #to:getEquipments()
      if x > 0 then
        room:drawCards(player, x, j_xianji.name)
      end
    else
      -- 弃置 Y 张牌（Y 为其体力值）
      local y = math.min(to.hp, #to:getCardIds("he"))
      if y > 0 then
        room:askToDiscard(to, {
          min_num = y,
          max_num = y,
          include_equip = true,
          skill_name = j_xianji.name,
          prompt = "#j_xianji-discard:::" .. y,
          cancelable = false,
        })
      end
      -- 令你回复1点体力
      if player:isWounded() then
        room:recover{
          who = player,
          num = 1,
          recoverBy = to,
          skillName = j_xianji.name,
        }
      end
    end
  end,
})

-- 测试：装备入目标装备区后选择选项1，按剩余装备栏空位数摸牌
j_xianji:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_xianji.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("guding_blade")
    room:obtainCard(me, { equip }, true, fk.ReasonDraw, me, "test")

    -- 放置前目标装备栏空位数 - 1（被新装备占用一个）
    local expect_draw = #comp2:getAvailableEquipSlots() - 1

    FkTest.setNextReplies(comp2, { { "j_xianji_opt1" } })
    local sk = Fk.skills[j_xianji.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = { comp2 }, cards = { equip.id } })
    end, {})

    lu.assertNotIsNil(comp2:getEquipment(equip.sub_type), "献戟：装备牌应进入目标装备区")
    lu.assertEquals(#me:getCardIds("h"), expect_draw, "献戟：选项1应按装备区空位数摸牌")
  end)
end)

return j_xianji