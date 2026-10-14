local m_jingyu = fk.CreateSkill {
  name = "m_jingyu",
}

Fk:loadTranslationTable{
  ["m_jingyu"] = "静御",
  [":m_jingyu"] = "每回合限一次，当你受到伤害时，若你的武将牌正面朝上，你可以与伤害来源拼点，若你赢，防止该伤害，然后你和伤害来源将武将牌翻面，伤害来源获得你的拼点牌。",

  ["#m_jingyu-invoke"] = "静御：与 %dest 拼点，若赢则防止此伤害并双方翻面",
  ["$m_jingyu1"] = "静观其变，御敌于先。",
  ["$m_jingyu2"] = "以静制动，万军莫侵！",
}

m_jingyu:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(m_jingyu.name) then return false end
    if target ~= player or player.dead then return false end
    if not player.faceup then return false end
    if player.room:getTag("m_jingyu_turn_used") then return false end
    if not data.from or data.from.dead or data.from == player then return false end
    if #player:getCardIds("h") == 0 or #data.from:getCardIds("h") == 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, {
      skill_name = m_jingyu.name,
      prompt = "#m_jingyu-invoke::" .. data.from.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setTag("m_jingyu_turn_used", true)
    local pd = { from = player, tos = { data.from }, reason = m_jingyu.name, results = {} }
    room:pindian(pd)
    local fromCard = pd.fromCard
    local toResult = pd.results[data.from]
    if fromCard and toResult and toResult.toCard then
      if fromCard.number > toResult.toCard.number then
        data:preventDamage()
        player:turnOver()
        data.from:turnOver()
        local myCardId = fromCard:getEffectiveId()
        if myCardId then
          room:obtainCard(data.from, { myCardId }, false, fk.ReasonPrey, player, m_jingyu.name)
        end
      end
    end
  end,
})

-- 每回合限一次：回合开始时重置
m_jingyu:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(m_jingyu.name) and not player.dead
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setTag("m_jingyu_turn_used", nil)
  end,
})

m_jingyu:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = m_jingyu.name,
  think = Util.TrueFunc,
})

return m_jingyu
