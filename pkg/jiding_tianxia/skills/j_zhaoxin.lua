local j_zhaoxin = fk.CreateSkill {
  name = "j_zhaoxin",
}

Fk:loadTranslationTable{
  ["j_zhaoxin"] = "昭心",
  [":j_zhaoxin"] = "每轮开始时，你可以依次指定两种卡牌花色；每当连续两张被使用的牌的花色为你指定的这两种（不分先后）时，你可以从牌堆获得两张你选择的不同点数的牌。",

  -- 标记显示：名置空，只显示 how_to_show 拼出的花色符号（♠♥）
  ["@[j_zhaoxin_suit]"] = "",

  ["#j_zhaoxin-invoke"] = "昭心：是否指定两种花色？",
  ["#j_zhaoxin-suit1"] = "昭心：请选择第一个花色",
  ["#j_zhaoxin-suit2"] = "昭心：请选择第二个花色",
  ["#j_zhaoxin-gain"] = "昭心：请选择两个点数，你从牌堆获得这两个点数的牌各一张",

  ["spade"] = "黑桃",
  ["heart"] = "红桃",
  ["club"] = "梅花",
  ["diamond"] = "方块",

  ["$j_zhaoxin1"] = "司马氏之心，路人皆知。",
  ["$j_zhaoxin2"] = "三马同槽，岂偶然哉。",
}

local ALL_SUITS = { "spade", "heart", "club", "diamond" }

-- 花色符号：黑桃（♠）、红桃（♥）、梅花（♣）、方块（♦）
local SUIT_SYMBOLS = { spade = "♠", heart = "♥", club = "♣", diamond = "♦" }

-- 参照擎北：注册花色显示标记，只显示所选两个花色的符号（存于 @[j_zhaoxin_suit]）
Fk:addQmlMark{
  name = "j_zhaoxin_suit",
  how_to_show = function(name, value, player)
    if type(value) == "table" and #value >= 2 then
      return (SUIT_SYMBOLS[value[1]] or value[1]) .. (SUIT_SYMBOLS[value[2]] or value[2])
    end
  end,
}

-- 每轮开始：依次指定两种花色（可重复）
j_zhaoxin:addEffect(fk.RoundStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_zhaoxin.name)
  end,
  on_cost = function(self, event, target, player, data)
    if player.room:askToSkillInvoke(player, { skill_name = j_zhaoxin.name, prompt = "#j_zhaoxin-invoke" }) then
      return true
    end
    -- 拒绝发动时清除旧的花色显示，避免展示过期信息
    player.room:setPlayerMark(player, "@[j_zhaoxin_suit]", 0)
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local s1 = room:askToChoice(player, {
      choices = ALL_SUITS,
      skill_name = j_zhaoxin.name,
      prompt = "#j_zhaoxin-suit1",
    })
    local s2 = room:askToChoice(player, {
      choices = ALL_SUITS,
      skill_name = j_zhaoxin.name,
      prompt = "#j_zhaoxin-suit2",
    })
    room:setPlayerMark(player, "j_zhaoxin_suits-round", { s1, s2 })
    room:setPlayerMark(player, "j_zhaoxin_prev-round", 0)
    room:setPlayerMark(player, "@[j_zhaoxin_suit]", { s1, s2 })
  end,
})

-- 其他角色使用牌：静默记录花色推进匹配链（锁定技式 refresh：不询问、不发动、不计次数）
j_zhaoxin:addEffect(fk.CardUsing, {
  can_refresh = function(self, event, target, player, data)
    if not player:hasSkill(j_zhaoxin.name) then return false end
    if type(player:getMark("j_zhaoxin_suits-round")) ~= "table" then return false end
    return data.from ~= player
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_zhaoxin_prev-round", data.card:getSuitString())
  end,
})

-- 自己使用牌：花色顺序匹配时可获得两张指定点数的牌（不匹配仅推进记录）
j_zhaoxin:addEffect(fk.CardUsing, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_zhaoxin.name) then return false end
    if type(player:getMark("j_zhaoxin_suits-round")) ~= "table" then return false end
    return data.from == player
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cur = data.card:getSuitString()
    local prev = player:getMark("j_zhaoxin_prev-round")
    local suits = player:getMark("j_zhaoxin_suits-round")
    if prev and prev ~= 0 and prev ~= "" and
      ((prev == suits[1] and cur == suits[2]) or (prev == suits[2] and cur == suits[1])) then
      -- 摸牌机制照抄十周年宫图：一次选两个点数，按点数分组随机各取一张
      local choiceList = {}
      for i = 1, 13 do
        table.insert(choiceList, Card:getNumberStr(i))
      end
      local choices = room:askToChoices(player, {
        min_num = 2,
        max_num = 2,
        choices = choiceList,
        skill_name = j_zhaoxin.name,
        prompt = "#j_zhaoxin-gain",
      })
      if #choices == 2 then
        local idsPack = {
          [choices[1]] = {},
          [choices[2]] = {},
        }
        for _, id in ipairs(room.draw_pile) do
          local number = Fk:getCardById(id):getNumberStr()
          if number == choices[1] then
            table.insert(idsPack[choices[1]], id)
          elseif number == choices[2] then
            table.insert(idsPack[choices[2]], id)
          end
        end
        local toObtain = {}
        if #idsPack[choices[1]] > 0 then
          table.insert(toObtain, room:tableRandomPick(idsPack[choices[1]]))
        end
        if #idsPack[choices[2]] > 0 then
          table.insert(toObtain, room:tableRandomPick(idsPack[choices[2]]))
        end
        if #toObtain > 0 then
          room:obtainCard(player, toObtain, false, fk.ReasonPrey, player, j_zhaoxin.name)
          room:setPlayerMark(player, "j_zhaoxin_gain-round", 1)
          room:setPlayerMark(player, "j_zhaoxin_justgained-round", 1)
          local got = player:getMark("j_zhaoxin_gotids-round")
          if type(got) ~= "table" then got = {} end
          for _, id in ipairs(toObtain) do table.insert(got, id) end
          room:setPlayerMark(player, "j_zhaoxin_gotids-round", got)
        end
      end
    end
    room:setPlayerMark(player, "j_zhaoxin_prev-round", cur)
  end,
})

-- 测试：轮开始时指定花色；当连续两张使用牌花色匹配时可获得牌堆牌
j_zhaoxin:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhaoxin.name)
    room:setPlayerMark(me, "j_zhaoxin_suits-round", { "spade", "heart" })
    room:setPlayerMark(me, "j_zhaoxin_prev-round", "spade")
    -- 额外塞入红桃5、黑桃6到牌堆，便于按点数获得
    local c = room:printCard("slash", Card.Heart, 5)
    table.insert(room.draw_pile, 1, c.id)
    local c2 = room:printCard("jink", Card.Spade, 6)
    table.insert(room.draw_pile, 1, c2.id)
  end)

  FkTest.runInRoom(function()
    local origChoices = room.askToChoices
    room.askToChoices = function(self, who, params)
      lu.assertEquals(who, me, "应由自己选择点数")
      return { "5", "6" }
    end
    local before = #me:getCardIds("h")
    -- 模拟自己使用一张红桃牌（spade 在前，heart 在后 → 匹配）
    local card = room:printCard("slash", Card.Heart, 7)
    room.logic:trigger(fk.CardUsing, me, { card = card, from = me })
    room.askToChoices = origChoices
    lu.assertEquals(me:getMark("j_zhaoxin_gain-round"), 1, "连续两张花色匹配应标记获得")
    lu.assertEquals(#me:getCardIds("h"), before + 2, "应获得两张牌")
  end)
end)

-- 测试：花色不分先后——反向顺序（红桃→黑桃）也触发获得
j_zhaoxin:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhaoxin.name)
    room:setPlayerMark(me, "j_zhaoxin_suits-round", { "spade", "heart" })
    room:setPlayerMark(me, "j_zhaoxin_prev-round", "heart")
    local c = room:printCard("slash", Card.Heart, 5)
    table.insert(room.draw_pile, 1, c.id)
    local c2 = room:printCard("jink", Card.Spade, 6)
    table.insert(room.draw_pile, 1, c2.id)
  end)

  FkTest.runInRoom(function()
    local origChoices = room.askToChoices
    room.askToChoices = function(self, who, params)
      return { "5", "6" }
    end
    local before = #me:getCardIds("h")
    -- 使用黑桃牌：heart 在前，spade 在后，与指定顺序相反也匹配
    local card = room:printCard("slash", Card.Spade, 7)
    room.logic:trigger(fk.CardUsing, me, { card = card, from = me })
    room.askToChoices = origChoices
    lu.assertEquals(me:getMark("j_zhaoxin_gain-round"), 1, "花色不分先后，反向也应触发")
    lu.assertEquals(#me:getCardIds("h"), before + 2, "反向匹配应获得两张牌")
  end)
end)

-- 测试：其他角色使用牌时仅记录花色，不询问、不获得
j_zhaoxin:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhaoxin.name)
    room:setPlayerMark(me, "j_zhaoxin_suits-round", { "spade", "heart" })
    room:setPlayerMark(me, "j_zhaoxin_prev-round", "spade")
  end)

  FkTest.runInRoom(function()
    local asked = false
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params)
      asked = true
      return true
    end
    -- 模拟其他角色使用一张红桃牌（spade→heart 本应匹配，但不询问）
    local card = room:printCard("slash", Card.Heart, 7)
    room.logic:trigger(fk.CardUsing, comp2, { card = card, from = comp2 })
    room.askToSkillInvoke = origInvoke
    lu.assertFalse(asked, "其他角色使用牌时不应询问是否获得")
    lu.assertEquals(me:getMark("j_zhaoxin_prev-round"), "heart", "其他角色使用牌后应记录花色")
    lu.assertEquals(me:getMark("j_zhaoxin_gain-round"), 0, "其他角色使用牌不应触发获得")
  end)
end)

-- 测试：花色显示标记已注册且只显示两个花色的符号
j_zhaoxin:addTest(function(room, me)
  local spec = Fk.qml_marks["j_zhaoxin_suit"]
  lu.assertNotIsNil(spec, "应注册花色显示标记")
  lu.assertEquals(spec.how_to_show("@[j_zhaoxin_suit]", { "spade", "heart" }, me), "♠♥",
    "应只显示两个所选花色的符号")
  lu.assertIsNil(spec.how_to_show("@[j_zhaoxin_suit]", 0, me), "非表值不应渲染")
  lu.assertEquals(Fk:translate("@[j_zhaoxin_suit]"), "", "标记名前缀应翻译为空，只留符号")
end)

-- 测试：轮开始时允许选择相同花色
j_zhaoxin:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhaoxin.name)
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return true end
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params) return "spade" end
    room.logic:trigger(fk.RoundStart, me, {})
    room.askToChoice = origChoice
    room.askToSkillInvoke = origInvoke
    local suits = me:getMark("j_zhaoxin_suits-round")
    lu.assertEquals(suits[1], "spade", "第一花色应为黑桃")
    lu.assertEquals(suits[2], "spade", "第二个花色可重复选择黑桃")
    lu.assertEquals(me:getMark("@[j_zhaoxin_suit]")[2], "spade", "显示标记应同步记录")
  end)
end)

return j_zhaoxin
