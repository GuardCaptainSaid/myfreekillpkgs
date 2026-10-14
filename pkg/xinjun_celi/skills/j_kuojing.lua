-- 君孙权·拓境
-- 出牌阶段限一次，你可选择你装备区的任意张【长江天堑】，令所有其他角色各选择一项：1.弃置一张与你弃置的牌同花色的牌；2.让你获得其一张手牌。若你获得的手牌小于你的体力值，你失去一点体力并摸一张牌；若你获得的手牌大于你的体力值，你加一点体力上限。
local j_kuojing = fk.CreateSkill {
  name = "j_kuojing",
}

Fk:loadTranslationTable{
  ["j_kuojing"] = "拓境",
  [":j_kuojing"] = "出牌阶段限一次，你可选择你装备区的任意张【长江天堑】，令所有其他角色各选择一项：1.弃置一张与你弃置的牌同花色的牌；2.让你获得其一张手牌。若你获得的手牌小于你的体力值，你失去一点体力并摸一张牌；若你获得的手牌大于你的体力值，你加一点体力上限。",

  ["#j_kuojing-select"] = "拓境：选择装备区的任意张【长江天堑】弃置",
  ["#j_kuojing-choice"] = "拓境：请选择一项（1.弃置一张与孙权弃牌同花色的牌 2.让孙权获得你一张手牌）",
  ["#j_kuojing-discard"] = "拓境：弃置一张同花色的牌",
  ["#j_kuojing-get"] = "拓境：选择获得其一张手牌",

  ["$j_kuojing1"] = "跨江拓土，威震江东！",
  ["$j_kuojing2"] = "以江为池，开疆立境！",
}

local function isChangjiang(player, id)
  local ve = player:getVirtualEquip(id)
  if ve then return ve.name == "j_changjiang" end
  return Fk:getCardById(id).name == "j_changjiang"
end

j_kuojing:addEffect("active", {
  anim_type = "control",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:usedSkillTimes(j_kuojing.name, Player.HistoryPhase) > 0 then return false end
    for _, id in ipairs(player:getCardIds(Player.Equip)) do
      if isChangjiang(player, id) then return true end
    end
    return false
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    -- 选择装备区任意张长江天堑
    local cjs = {}
    for _, id in ipairs(player:getCardIds(Player.Equip)) do
      if isChangjiang(player, id) then table.insert(cjs, id) end
    end
    local chosen = {}
    if #cjs > 0 then
      local allEquips = player:getCardIds(Player.Equip)
      while #chosen == 0 do
        local c = room:askToChooseCards(player, {
          target = player,
          flag = "e",
          min = 1,
          max = #allEquips,
          cancelable = false,
          pattern = ".",
          skill_name = j_kuojing.name,
          prompt = "#j_kuojing-select",
        })
        local ok = true
        for _, id in ipairs(c) do
          if not isChangjiang(player, id) then ok = false break end
        end
        if ok then chosen = c break end
      end
    end
    if #chosen == 0 then return end
    room:throwCard(chosen, j_kuojing.name, player, player)
    -- 弃置牌的花色集合
    local suits = {}
    for _, id in ipairs(chosen) do
      local s = Fk:getCardById(id).suit
      if not table.contains(suits, s) then table.insert(suits, s) end
    end
    -- 所有其他角色各选择一项
    local gained = 0
    for _, p in ipairs(room:getOtherPlayers(player)) do
      if not p.dead then
        local choice = room:askToChoice(p, { choices = { "1", "2" }, skill_name = j_kuojing.name, prompt = "#j_kuojing-choice" })
        if choice == "1" then
          local c1 = room:askToChooseCards(p, {
            target = p,
            flag = "hej",
            min = 0,
            max = 1,
            cancelable = true,
            pattern = ".",
            skill_name = j_kuojing.name,
            prompt = "#j_kuojing-discard",
          })
          if c1 and #c1 > 0 and table.contains(suits, Fk:getCardById(c1[1]).suit) then
            room:throwCard(c1, j_kuojing.name, p, p)
          end
        else
          if #p:getCardIds("h") > 0 then
            local c2 = room:askToChooseCards(player, {
              target = p,
              flag = "h",
              min = 1,
              max = 1,
              cancelable = false,
              pattern = ".",
              skill_name = j_kuojing.name,
              prompt = "#j_kuojing-get",
            })
            if c2 and #c2 > 0 then
              room:obtainCard(player, c2, true, fk.ReasonGive, p, j_kuojing.name)
              gained = gained + 1
            end
          end
        end
      end
    end
    -- 结算得失
    if gained < player.hp then
      if not player.dead then
        room:loseHp(player, 1, j_kuojing.name)
        if not player.dead then
          player:drawCards(1, j_kuojing.name)
        end
      end
    elseif gained > player.hp then
      room:changeMaxHp(player, 1)
    end
  end,
})

-- 测试：拓境弃牌结算（获得多→加上限）
j_kuojing:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_kuojing.name)
    me.maxHp = 4
    me.hp = 4
    room.current = me
    me.phase = Player.Play
    -- me 装备两张长江天堑
    local cj1 = room:printCard("j_changjiang", Card.Spade, 7)
    local cj2 = room:printCard("j_changjiang", Card.Diamond, 8)
    room:moveCardTo(cj1, Player.Equip, me, fk.ReasonPut, j_kuojing.name)
    room:moveCardTo(cj2, Player.Equip, me, fk.ReasonPut, j_kuojing.name)
    -- 所有其他角色各一张手牌（都选2让 me 获得）
    for i = 2, #room.players do
      local p = room.players[i]
      local c = room:printCard("slash", Card.Heart, i)
      room:obtainCard(p, { c }, true, fk.ReasonDraw, p, "test")
    end
  end)

  FkTest.runInRoom(function()
    room.current = me
    me.phase = Player.Play
    local eff
    for _, spec in ipairs(j_kuojing.effect_spec_list) do
      if spec[1] == "active" then eff = spec[3] break end
    end
    local cjs = {}
    for _, id in ipairs(me:getCardIds(Player.Equip)) do
      cjs[#cjs + 1] = id
    end
    -- 每名其他角色回复：选 2（让孙权获得一张手牌）——AskForChoices 回复为数组包裹
    for i = 2, #room.players do
      FkTest.setNextReplies(room.players[i], { { "2" } })
    end
    -- me 回复：先选长江天堑，随后依次从每人手牌各选一张
    local meReplies = { cjs }
    for i = 2, #room.players do
      local p = room.players[i]
      table.insert(meReplies, { p:getCardIds("h")[1] })
    end
    FkTest.setNextReplies(me, meReplies)
    local hpBefore = me.hp
    local maxBefore = me.maxHp
    local handBefore = #me:getCardIds("h")
    eff.on_use(eff, room, { from = me, tos = {}, cards = {} })
    lu.assertEquals(#me:getCardIds("h"), handBefore + 7, "拓境：应获得7名角色的手牌各一张")
    -- 7 名其他角色都让 me 获得 1 张 → gained=7 > hp=4 → 加上限
    lu.assertEquals(me.maxHp, maxBefore + 1, "拓境：获得手牌大于体力值应加一点体力上限")
    lu.assertEquals(me.hp, hpBefore, "拓境：加上限分支不失血")
  end)
end)

return j_kuojing