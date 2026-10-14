local j_zishi = fk.CreateSkill {
  name = "j_zishi",
}

Fk:loadTranslationTable{
  ["j_zishi"] = "谘势",
  [":j_zishi"] = "当有角色使用转化牌时，你可以选择一项：令其额外指定一个目标（若为伤害牌则伤害+1）；你弃置一张牌，令其本回合无法使用与你弃牌同类型牌。",

  ["#j_zishi-invoke"] = "谘势：%src 使用了转化牌",
  ["#j_zishi-choice"] = "谘势：选择一项",
  ["#j_zishi-extra"] = "谘势：令 %src 额外指定一个目标",
  ["#j_zishi-discard"] = "谘势：弃置一张牌，令其本回合无法使用同类型牌",
  ["j_zishi:extra"] = "令其额外指定一个目标（伤害牌则伤害+1）",
  ["j_zishi:forbid"] = "弃一张牌，令其本回合无法使用同类型牌",
  ["$j_zishi1"] = "咨诹善道，察纳雅言。",
  ["$j_zishi2"] = "博采众议，以定大计！",
}

-- 伤害牌名单
local damage_cards = {
  slash = true,
  duel = true,
  fire_attack = true,
  archery_attack = true,
  savage_assault = true,
}

local function isDamageCard(card)
  return damage_cards[card.trueName] == true
end

j_zishi:addEffect(fk.CardUsing, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return false end
    if not player:hasSkill(j_zishi.name) then return false end
    if not data or not data.card or not data.from then return false end
    if data.from == player or data.from.dead then return false end
    -- 转化牌：虚拟牌或带技能名
    if data.card:isVirtual() then return true end
    return data.card.skillName ~= nil and data.card.skillName ~= ""
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, {
      skill_name = j_zishi.name,
      prompt = "#j_zishi-invoke::" .. data.from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 选项①：令其额外指定一个目标（需该牌已有目标且存在可指定角色）
    local extraTargets = {}
    if data.tos and #data.tos > 0 then
      extraTargets = table.filter(room.alive_players, function(p)
        if table.contains(data.tos, p) then return false end
        return data.from:canUseTo(data.card, p)
      end)
    end
    local choices = {}
    if #extraTargets > 0 then table.insert(choices, "j_zishi:extra") end
    table.insert(choices, "j_zishi:forbid")
    local choice = room:askToChoice(player, {
      choices = choices,
      skill_name = j_zishi.name,
      prompt = "#j_zishi-choice::" .. data.from.id,
    })
    if choice == "j_zishi:extra" then
      local t = room:askToChoosePlayers(data.from, {
        targets = extraTargets,
        min_num = 1,
        max_num = 1,
        skill_name = j_zishi.name,
        prompt = "#j_zishi-extra",
      })
      if t and #t > 0 then
        table.insert(data.tos, t[1])
        if isDamageCard(data.card) then
          local dmg = room:getTag("j_zishi_dmg") or {}
          dmg[data.card.id] = true
          room:setTag("j_zishi_dmg", dmg)
        end
      end
    else
      local cards = room:askToDiscard(player, {
        min_num = 1,
        max_num = 1,
        include_equip = true,
        skill_name = j_zishi.name,
        prompt = "#j_zishi-discard",
        cancelable = true,
      })
      if #cards == 1 then
        local ctype = Fk:getCardById(cards[1]).type
        -- 用 mark 记录禁用类型（客户端 isProhibited 需要读到，tag 不同步到客户端）
        room:setPlayerMark(data.from, "@@j_zishi_forbid", ctype)
        room:throwCard(cards, j_zishi.name, player, player)
      end
    end
  end,
})

-- 谘势标记的伤害牌造成伤害时 +1
j_zishi:addEffect(fk.DamageCaused, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_zishi.name) then return false end
    if not data or not data.card then return false end
    local dmg = player.room:getTag("j_zishi_dmg") or {}
    return dmg[data.card.id] == true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data:changeDamage(1)
  end,
})

-- 禁同类型牌：该角色使用同类型牌时无法指定目标
j_zishi:addEffect("prohibit", {
  global = true,
  is_prohibited = function(self, from, to, card)
    if not card or not from then return false end
    -- mark 会同步到客户端；tag 不会（客户端 currentRoom 无 getTag）
    local ctype = from:getMark("@@j_zishi_forbid")
    return ctype ~= 0 and card.type == ctype
  end,
})

-- 回合结束时清除禁同类标记
j_zishi:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(j_zishi.name)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(room.alive_players) do
      if p:getMark("@@j_zishi_forbid") ~= 0 then
        room:setPlayerMark(p, "@@j_zishi_forbid", 0)
      end
    end
    room:setTag("j_zishi_dmg", nil)
  end,
})

j_zishi:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_zishi.name,
  think = Util.TrueFunc,
})

return j_zishi
