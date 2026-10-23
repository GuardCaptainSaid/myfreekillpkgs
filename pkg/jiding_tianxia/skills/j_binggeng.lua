-- 计枣祗·兵耕
-- 出牌阶段限一次，你可以废除一个装备栏，然后摸Z张牌。（Z为你已废除的装备栏数）
local j_binggeng = fk.CreateSkill {
  name = "j_binggeng",
}

Fk:loadTranslationTable{
  ["j_binggeng"] = "兵耕",
  [":j_binggeng"] = "出牌阶段限一次，你可以废除一个装备栏，然后摸Z张牌（Z为你已废除的装备栏数）。",

  ["#j_binggeng"] = "兵耕：废除一个装备栏，然后摸Z张牌（Z为你已废除的装备栏数）",
  ["#j_binggeng-slot"] = "兵耕：选择要废除的装备栏",
}

-- 已废除的装备栏数（不含手牌区/判定区）
local function sealedEquipSlotNum(player)
  local n = 0
  for _, s in ipairs(player.sealedSlots or {}) do
    if s ~= Player.HandSlot and s ~= Player.JudgeSlot then
      n = n + 1
    end
  end
  return n
end

j_binggeng:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#j_binggeng",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    if player:usedSkillTimes(j_binggeng.name, Player.HistoryPhase) > 0 then return false end
    return #player:getAvailableEquipSlots() > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local slots = player:getAvailableEquipSlots()
    if #slots == 0 then return end
    local choice
    if #slots == 1 then
      choice = slots[1]
    else
      choice = room:askToChoice(player, {
        choices = slots,
        skill_name = j_binggeng.name,
        prompt = "#j_binggeng-slot",
      })
    end
    if not choice or choice == "" or choice == "Cancel" then return end

    room:abortPlayerArea(player, { choice })

    local z = sealedEquipSlotNum(player)
    if z > 0 then
      room:drawCards(player, z, j_binggeng.name)
    end
  end,
})

-- 测试：废除一个装备栏 → 摸已废除装备栏数张牌（首次为1）
j_binggeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_binggeng.name)
    room.current = me
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local sk = Fk.skills[j_binggeng.name]
    local skel = sk.getSkeleton and sk:getSkeleton() or sk
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 active 效果")
    lu.assertTrue(spec:can_use(me), "出牌阶段应可发动")

    local before = #me:getCardIds("h")
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      return params.choices[1]
    end
    spec:on_use(room, { from = me })
    room.askToChoice = origChoice

    lu.assertEquals(sealedEquipSlotNum(me), 1, "应废除1个装备栏")
    lu.assertEquals(#me:getCardIds("h"), before + 1, "首次废除后应摸1张牌")
  end)
end)

-- 测试：出牌阶段限一次
j_binggeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_binggeng.name)
    room.current = me
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local sk = Fk.skills[j_binggeng.name]
    local skel = sk.getSkeleton and sk:getSkeleton() or sk
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == "active" then spec = sp[3] break end
    end
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params) return params.choices[1] end
    spec:on_use(room, { from = me })
    room.askToChoice = origChoice
    lu.assertFalse(spec:can_use(me), "出牌阶段应只能发动一次")
  end)
end)

return j_binggeng
