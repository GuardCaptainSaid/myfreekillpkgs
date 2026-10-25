-- 界狂骨（计杨修【显忌】授予的技能）
--
-- ！！必须单独占一个文件！！
-- 引擎的技能加载器只注册「文件 return 的那个 skeleton」；同一文件里的第二个
-- fk.CreateSkill 不会进入 Fk.skills，handleAddLoseSkills("j_jie_kuanggu") 会静默失败。
local j_jie_kuanggu = fk.CreateSkill {
  name = "j_jie_kuanggu",
}

Fk:loadTranslationTable{
  ["j_jie_kuanggu"] = "界狂骨",
  [":j_jie_kuanggu"] = "当你对距离1以内的角色造成1点伤害后，你可以选择摸一张牌或回复1点体力。",

  ["j_jie_kuanggu_draw"] = "摸一张牌",
  ["j_jie_kuanggu_recover"] = "回复1点体力",
}

-- 造成伤害后：每点伤害可各摸一张牌或回复1点体力
j_jie_kuanggu:addEffect(fk.Damage, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_jie_kuanggu.name) and not player.dead
      and (data.extra_data or {}).jie_kuanggu_check
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local choices = { "j_jie_kuanggu_draw", "Cancel" }
    if player:isWounded() then
      table.insert(choices, 2, "j_jie_kuanggu_recover")
    end
    local choice = room:askToChoice(player, {
      choices = choices,
      skill_name = j_jie_kuanggu.name,
    })
    if choice ~= "Cancel" then
      event:setCostData(self, { choice = choice })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = event:getCostData(self).choice
    for i = 1, math.max(data.damage, 1) do
      if player.dead then break end
      if i > 1 then
        -- 同一次伤害的后续点数再选一次（不给取消）
        local choices = { "j_jie_kuanggu_draw" }
        if player:isWounded() then
          table.insert(choices, "j_jie_kuanggu_recover")
        end
        choice = room:askToChoice(player, {
          choices = choices,
          skill_name = j_jie_kuanggu.name,
        })
      end
      if choice == "j_jie_kuanggu_recover" then
        room:recover{
          who = player,
          num = 1,
          recoverBy = player,
          skillName = j_jie_kuanggu.name,
        }
      else
        room:drawCards(player, 1, j_jie_kuanggu.name)
      end
    end
  end,
})

-- 记录「这次伤害确实让距离1以内的角色掉血了」（伤害被防止时不会触发）
j_jie_kuanggu:addEffect(fk.BeforeHpChanged, {
  can_refresh = function(self, event, target, player, data)
    return data.damageEvent and player == data.damageEvent.from and target ~= player
      and player:hasSkill(j_jie_kuanggu.name) and player:compareDistance(target, 2, "<")
  end,
  on_refresh = function(self, event, target, player, data)
    data.damageEvent.extra_data = data.damageEvent.extra_data or {}
    data.damageEvent.extra_data.jie_kuanggu_check = true
  end,
})

-- 测试辅助：只拦截界狂骨自己的选项框，其余（如"选择触发技能"）交回引擎
local function patchChoice(room, ret)
  local orig = room.askToChoice
  local asked = 0
  room.askToChoice = function(self, player, params)
    if params and params.skill_name == "j_jie_kuanggu" then
      asked = asked + 1
      return ret
    end
    return orig(self, player, params)
  end
  return function() return orig, asked end
end

-- 测试：对距离1以内角色造成伤害后，可选择摸一张牌或回复1点体力
j_jie_kuanggu:addTest(function(room, me)
  local target = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jie_kuanggu.name)
    room:loseHp(me, 2)
  end)

  FkTest.runInRoom(function()
    lu.assertTrue(me:hasSkill(j_jie_kuanggu.name), "界狂骨应能授予")
  end)

  -- 选「回复1点体力」
  FkTest.runInRoom(function()
    local restore = patchChoice(room, "j_jie_kuanggu_recover")
    local before = me.hp
    room:damage{ from = me, to = target, damage = 1 }
    local orig, n = restore()
    room.askToChoice = orig
    lu.assertEquals(n, 1, "应询问一次")
    lu.assertEquals(me.hp, before + 1, "选择回复时应回复1点体力")
  end)

  -- 选「摸一张牌」
  FkTest.runInRoom(function()
    local restore = patchChoice(room, "j_jie_kuanggu_draw")
    local before = #me:getCardIds("h")
    room:damage{ from = me, to = target, damage = 1 }
    local orig, n = restore()
    room.askToChoice = orig
    lu.assertEquals(#me:getCardIds("h"), before + 1, "选择摸牌时应摸一张牌")
  end)

  -- 一次 2 点伤害应结算两次
  FkTest.runInRoom(function()
    target.hp = target.maxHp -- 避免掉进濒死流程消耗手牌
    local restore = patchChoice(room, "j_jie_kuanggu_draw")
    local before = #me:getCardIds("h")
    room:damage{ from = me, to = target, damage = 2 }
    local orig, n = restore()
    room.askToChoice = orig
    lu.assertEquals(n, 2, "2 点伤害应询问两次")
    lu.assertEquals(#me:getCardIds("h"), before + 2, "每点伤害各结算一次")
  end)

  -- 不在距离1以内：不触发
  FkTest.runInRoom(function()
    local far
    for _, p in ipairs(room.players) do
      if p ~= me and me:distanceTo(p) > 1 then far = p break end
    end
    lu.assertNotNil(far, "房间里应存在距离2以上的角色")
    local restore = patchChoice(room, "j_jie_kuanggu_draw")
    room:damage{ from = me, to = far, damage = 1 }
    local orig, n = restore()
    room.askToChoice = orig
    lu.assertEquals(n, 0, "距离2以上不应触发界狂骨")
  end)
end)

return j_jie_kuanggu
