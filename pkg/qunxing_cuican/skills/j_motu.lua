local j_motu = fk.CreateSkill {
  name = "j_motu",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_motu"] = "末途",
  [":j_motu"] = "锁定技，当你死亡时，你选择一名与你势力相同的角色（若没有则改为所有角色），弃置其所有装备牌并令其失去1点体力。",

  ["#j_motu-choose"] = "末途：选择一名与你势力相同的角色",
}

j_motu:addEffect(fk.GameOverJudge, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    -- 此处 target/player 都是死者本人（death.lua:133 以 victim 为 target 触发 GameOverJudge），
    -- 但 Death:main 在触发前已置 victim.dead = true（death.lua:93），
    -- 而 Player:hasSkill 在 dead 时默认返回 false（player.lua:1040）。
    -- 因此必须显式传 ignoreAlive = true，否则本技能永远不发动。
    return target == player and player:hasSkill(j_motu.name, false, true)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room

    local same_kingdom = table.filter(room.alive_players, function(p)
      return p ~= player and p.kingdom == player.kingdom
    end)

    local targets
    if #same_kingdom > 0 then
      local chosen = room:askToChoosePlayers(player, {
        targets = same_kingdom,
        min_num = 1,
        max_num = 1,
        skill_name = j_motu.name,
        prompt = "#j_motu-choose",
        cancelable = false,
      })
      targets = chosen
    else
      -- 没有同势力角色：改为所有角色
      targets = table.simpleClone(room.alive_players)
    end

    for _, p in ipairs(targets) do
      if p:isAlive() then
        local equips = p:getEquipments()
        if #equips > 0 then
          room:throwCard(equips, j_motu.name, p, player)
        end
        if p:isAlive() then
          room:loseHp(p, 1, j_motu.name, player)
        end
      end
    end
  end,
})

-- 测试：无同势力角色时，所有存活角色被弃置装备并失去1点体力
j_motu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_motu.name)
  end)

  FkTest.runInRoom(function()
    local equip = room:printCard("guding_blade")
    room:moveCardTo(equip, Card.PlayerEquip, comp2, fk.ReasonUse, "test")
    -- me 设为独特势力，其余角色统一改为 shu，确保"无同势力角色"分支成立
    room:changeKingdom(me, "qun", false)
    for _, p in ipairs(room.alive_players) do
      if p ~= me then room:changeKingdom(p, "shu", false) end
    end

    local sk = Fk.skills[j_motu.name]:getSkeleton()
    local eff
    for _, spec in ipairs(sk.effect_spec_list) do
      if spec[1] == fk.GameOverJudge then eff = spec[3] break end
    end

    local hp_before = comp2.hp
    eff:on_use({ room = room }, me, me, {})

    lu.assertEquals(#comp2:getEquipments(), 0, "末途：应弃置目标所有装备牌")
    lu.assertEquals(comp2.hp, hp_before - 1, "末途：目标应失去1点体力")
  end)
end)

-- 回归测试：直接验证 can_trigger。
-- 本技能在 fk.GameOverJudge 触发，而 Death:main 在触发之前就已把 victim.dead 置为 true
-- （death.lua:93），Player:hasSkill 默认因 ignoreAlive=false 而返回 false（player.lua:1040），
-- 导致技能永不发动。上面那个测试直接调用 eff:on_use，绕过了 can_trigger，无法发现该 bug。
j_motu:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_motu.name)
  end)

  FkTest.runInRoom(function()
    local skel = Fk.skills[j_motu.name]:getSkeleton()
    local eff
    for _, spec in ipairs(skel.effect_spec_list) do
      if spec[1] == fk.GameOverJudge then eff = spec[3] break end
    end
    lu.assertNotIsNil(eff, "末途：应能定位到 GameOverJudge 效果")

    -- 模拟死亡结算时的状态：此时 victim.dead 已经为 true
    local was_dead = me.dead
    me.dead = true
    local ok = eff:can_trigger({ room = room }, me, me, {})
    me.dead = was_dead

    lu.assertIsTrue(ok, "末途：角色已死亡时 can_trigger 仍须为 true，否则技能永不发动")
  end)
end)

return j_motu