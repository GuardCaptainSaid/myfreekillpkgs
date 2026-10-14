local j_shezeng = fk.CreateSkill {
  name = "j_shezeng",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_shezeng"] = "奢赠",
  [":j_shezeng"] = "锁定技，游戏开始时，若牌堆中不足四张【指仓相赠】，你将其补齐至四张（花色点数固定为方块A、梅花6、黑桃Q、红桃K）。",
}

-- 固定四张：方块A、梅花6、黑桃Q、红桃K
local fixed_specs = {
  { Card.Diamond, 1 }, -- 方块A
  { Card.Club, 6 },    -- 梅花6
  { Card.Spade, 12 },  -- 黑桃Q
  { Card.Heart, 13 },  -- 红桃K
}

j_shezeng:addEffect(fk.GameStart, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_shezeng.name, true)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local existing = 0
    for _, id in ipairs(room.draw_pile) do
      if Fk:getCardById(id).name == "j_zicangxiangzeng" then
        existing = existing + 1
      end
    end
    local to_add = math.max(0, 4 - existing)
    if to_add <= 0 then return end
    for i = 1, to_add do
      local spec = fixed_specs[i]
      local card = Fk:cloneCard("j_zicangxiangzeng", spec[1], spec[2])
      table.insert(room.draw_pile, card.id)
      room:setCardArea(card.id, Card.DrawPile)
    end
    table.shuffle(room.draw_pile)
  end,
})

-- 测试1：游戏开始时牌堆中有且仅有四张【指仓相赠】（与衍生牌包叠加不会变八张）
j_shezeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shezeng.name)
    lu.assertTrue(me:hasSkill(j_shezeng.name, true), "me 应拥有奢赠技能")
  end)

  FkTest.runInRoom(function()
    room.logic:trigger(fk.GameStart, me, {})
    local count = 0
    for _, id in ipairs(room.draw_pile) do
      if Fk:getCardById(id).name == "j_zicangxiangzeng" then
        count = count + 1
      end
    end
    lu.assertEquals(count, 4, "开局牌堆中应恰有4张指仓相赠")
  end)
end)

-- 测试2：牌堆已含四张指仓相赠时，触发奢赠不再重复加入
j_shezeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_shezeng.name)
    local count = 0
    for _, id in ipairs(room.draw_pile) do
      if Fk:getCardById(id).name == "j_zicangxiangzeng" then
        count = count + 1
      end
    end
    lu.assertEquals(count, 4, "预处理：牌堆应有4张指仓相赠")
  end)

  FkTest.runInRoom(function()
    local before = #room.draw_pile
    room.logic:trigger(fk.GameStart, me, {})
    lu.assertEquals(#room.draw_pile, before, "已有四张指仓相赠时不应重复加入")
  end)
end)

return j_shezeng