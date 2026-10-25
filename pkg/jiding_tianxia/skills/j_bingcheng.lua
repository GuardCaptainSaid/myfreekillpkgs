-- 计娄圭·冰城（锁定技）
-- 当你受到伤害时，你回复等量体力；当你累计受到一点火焰伤害、一点雷属性伤害、一点无属性伤害后，此技能失效。
--
-- 【重要】必须监听 fk.HpChanged 而不是 fk.Damaged：
-- 引擎 Damage 流程是 changeHp（扣血 → fk.BeforeHpChanged → 改 hp → fk.HpChanged
--   → **若 hp<1 就地进入濒死/死亡流程**）之后才触发 fk.Damage / fk.Damaged。
-- 写在 fk.Damaged 里回复体力时，致死伤害的濒死（甚至死亡）已经结算完，
-- 表现为"被打死时冰城不救人"（且别人补桃后还会多回一点）。
-- fk.HpChanged 在扣血后、濒死判定前触发，在这里回复等量体力即可真正免于此次伤害。
local j_bingcheng = fk.CreateSkill {
  name = "j_bingcheng",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_bingcheng"] = "冰城",
  [":j_bingcheng"] = "锁定技，当你受到伤害时，你回复等量体力；当你累计受到一点火焰伤害、一点雷属性伤害、一点无属性伤害后，此技能失效。",

  -- `@@` 前缀：标记区只显示翻译文字、不显示数值（三种属性只需累计到 1 点）
  ["@@j_bingcheng_fire"] = "火",
  ["@@j_bingcheng_thunder"] = "雷",
  ["@@j_bingcheng_normal"] = "无",
  ["@@j_bingcheng_invalid"] = "冰城失效",
}

-- 火 / 雷 / 无 三种属性各累计一点即失效，故标记值只需 1（同时作为判定条件与显示标记）
local MARK_FIRE = "@@j_bingcheng_fire"
local MARK_THUNDER = "@@j_bingcheng_thunder"
local MARK_NORMAL = "@@j_bingcheng_normal"
local MARK_INVALID = "@@j_bingcheng_invalid"

local TYPE_MARK = {
  [fk.FireDamage] = MARK_FIRE,
  [fk.ThunderDamage] = MARK_THUNDER,
  [fk.NormalDamage] = MARK_NORMAL,
}

j_bingcheng:addEffect(fk.HpChanged, {
  anim_type = "defensive",
  -- 锁定技，自动执行
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_bingcheng.name) or player.dead then return false end
    if player:getMark(MARK_INVALID) > 0 then return false end
    -- 只响应"受到伤害"导致的体力变化：体力流失（loseHp）/回复（recover）不算受伤
    if data.reason ~= "damage" or not data.damageEvent then return false end
    -- 护甲挡完时 num 为 0，没有实际掉血，不触发
    if (data.num or 0) >= 0 then return false end
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local dmg = -data.num
    local dtype = data.damageEvent.damageType or fk.NormalDamage

    -- ① 回复等量体力（此处引擎尚未做濒死判定，故致死伤害也能被救下）
    if dmg > 0 then
      room:recover{
        who = player,
        num = dmg,
        recoverBy = player,
        skillName = j_bingcheng.name,
      }
    end

    -- ② 累计各属性受到的伤害（标记同时用于向所有玩家显示已累计的属性）
    local mark = TYPE_MARK[dtype]
    if mark and player:getMark(mark) < 1 then
      room:setPlayerMark(player, mark, 1)
    end

    -- ③ 火、雷、无属性各累计 ≥1 → 此技能失效
    if player:getMark(MARK_FIRE) >= 1
      and player:getMark(MARK_THUNDER) >= 1
      and player:getMark(MARK_NORMAL) >= 1 then
      -- 三种属性已齐、技能已失效，属性标记不再有意义，清掉只留「冰城失效」
      room:setPlayerMark(player, MARK_FIRE, 0)
      room:setPlayerMark(player, MARK_THUNDER, 0)
      room:setPlayerMark(player, MARK_NORMAL, 0)
      room:setPlayerMark(player, MARK_INVALID, 1)
    end
  end,
})

-- 测试：受到1点伤害回复1点；累计三种属性后失效
j_bingcheng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_bingcheng.name)
    me.maxHp = 4
    me.hp = 2
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_bingcheng.name]:getSkeleton()
    local spec
    for _, sp in ipairs(skel.effect_spec_list) do
      if sp[1] == fk.HpChanged then spec = sp[3] break end
    end
    lu.assertNotNil(spec, "应存在 HpChanged 效果")
    -- 注意 can_trigger 形参顺序为 (self, event, target, player, data)
    lu.assertTrue(spec.can_trigger(nil, nil, me, me, {
      num = -1, reason = "damage", damageEvent = { damageType = fk.NormalDamage },
    }), "受到伤害应可发动")
    lu.assertFalse(spec.can_trigger(nil, nil, me, me, {
      num = -1, reason = "loseHp",
    }), "体力流失不应发动")
    lu.assertFalse(spec.can_trigger(nil, nil, me, me, {
      num = 0, reason = "damage", damageEvent = { damageType = fk.NormalDamage },
    }), "被护甲挡完（num=0）不应发动")

    -- 普通伤害：回复等量 → 体力不变
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me.hp, 2, "冰城：受到1点普通伤害应回复1点，体力不变")
    lu.assertEquals(me:getMark("@@j_bingcheng_normal"), 1, "应累计1点无属性伤害并显示「无」标记")
    lu.assertEquals(me:getMark("@@j_bingcheng_invalid"), 0, "尚未集齐三种属性")

    -- 再受一次普通伤害：显示标记值固定为 1（不累计点数，也不需要重复显示）
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me:getMark("@@j_bingcheng_normal"), 1, "「无」标记只需显示一次")

    -- 火焰伤害
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.FireDamage }
    lu.assertEquals(me:getMark("@@j_bingcheng_fire"), 1, "应累计1点火焰伤害并显示「火」标记")

    -- 雷属性伤害 → 三类齐全，技能失效
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.ThunderDamage }
    lu.assertEquals(me:getMark("@@j_bingcheng_invalid"), 1, "集齐三种属性后冰城应失效")
    lu.assertEquals(me:getMark("@@j_bingcheng_fire"), 0, "失效后应清掉「火」标记")
    lu.assertEquals(me:getMark("@@j_bingcheng_thunder"), 0, "失效后应清掉「雷」标记")
    lu.assertEquals(me:getMark("@@j_bingcheng_normal"), 0, "失效后应清掉「无」标记")

    -- 失效后不再回复
    local hp = me.hp
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(me.hp, hp - 1, "冰城失效后受到伤害不再回复")
  end)
end)

-- 测试：致死伤害（1血吃1点伤害）必须被冰城救下——旧实现写在 fk.Damaged 里，
-- 引擎先结算濒死/死亡再触发 Damaged，导致直接死亡（回归用例）
j_bingcheng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_bingcheng.name)
    me.maxHp = 4
    me.hp = 1
  end)
  FkTest.runInRoom(function()
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    lu.assertFalse(me.dead, "冰城：受到致死伤害不应死亡")
    lu.assertFalse(me.dying, "冰城：受到致死伤害不应进入濒死")
    lu.assertEquals(me.hp, 1, "冰城：受到1点伤害应回复1点，体力仍为1")
  end)
end)

-- 测试：过量伤害（1血吃3点）也应被救下（-2 回复 3 点 → 1）
j_bingcheng:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_bingcheng.name)
    me.maxHp = 4
    me.hp = 1
  end)
  FkTest.runInRoom(function()
    room:damage{ from = comp2, to = me, damage = 3, damageType = fk.NormalDamage }
    lu.assertFalse(me.dead, "冰城：受到过量伤害不应死亡")
    lu.assertEquals(me.hp, 1, "冰城：1血受3点伤害→-2，回复3点→1")
  end)
end)

return j_bingcheng
