-- 计枣祗·军屯
-- 回合开始时，你可以将武将牌上的牌交给一名角色，然后将至多X张花色不同的牌置于武将牌上视为"军屯"
-- （X为你已损失的体力值）。本轮有与"军屯"花色相同的牌进入弃牌堆时，你摸一张牌。
local j_juntun = fk.CreateSkill {
  name = "j_juntun",
  derived_piles = "j_juntun",
}

local PILE = "j_juntun"
-- 本轮是否已发动（供“本轮”摸牌判定使用，-round 后缀由引擎在轮次开始时自动清零）
local ACTIVE = "j_juntun_round-round"

Fk:loadTranslationTable{
  ["j_juntun"] = "军屯",
  [":j_juntun"] = "回合开始时，你可以将武将牌上的牌交给一名角色，然后将至多X张花色不同的牌置于你的武将牌上视为“军屯”（X为你已损失的体力值）。本轮有与“军屯”花色相同的牌进入弃牌堆时，你摸一张牌。",

  ["#j_juntun-invoke"] = "军屯：是否发动【军屯】？",
  ["#j_juntun-give"] = "军屯：选择一名角色，将武将牌上的牌交给其（可点取消不交）",
  ["#j_juntun-put"] = "军屯：选择一张花色不同的手牌置于武将牌上（还可放%arg张，可点取消结束）",
}

-- 武将牌上“军屯”牌的花色集合
local function pileSuits(player)
  local suits = {}
  for _, id in ipairs(player:getPile(PILE)) do
    local c = Fk:getCardById(id)
    if c then
      table.insertIfNeed(suits, c:getSuitString())
    end
  end
  return suits
end

-- 回合开始时：①交出武将牌上的牌 ②将至多X张花色不同手牌置于武将牌上
j_juntun:addEffect(fk.TurnStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    return player:hasSkill(j_juntun.name) and not player.dead
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = j_juntun.name,
      prompt = "#j_juntun-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room

    -- ① 将武将牌上的牌交给一名角色（可拒绝）
    local pile = player:getPile(PILE)
    if #pile > 0 then
      local tos = room:askToChoosePlayers(player, {
        targets = room.alive_players,
        min_num = 1,
        max_num = 1,
        cancelable = true,
        skill_name = j_juntun.name,
        prompt = "#j_juntun-give",
      })
      local to = tos and tos[1]
      if to and not to.dead then
        local ids = table.simpleClone(player:getPile(PILE))
        if #ids > 0 then
          if to == player then
            -- 交给自己：直接收回手牌
            room:moveCards{
              ids = ids,
              to = player,
              toArea = Card.PlayerHand,
              moveReason = fk.ReasonJustMove,
              skillName = j_juntun.name,
              proposer = player,
            }
          else
            for _, id in ipairs(ids) do
              room:moveCardTo(id, Card.PlayerHand, to, fk.ReasonGive, j_juntun.name, nil, true, player)
            end
          end
        end
      end
    end

    -- ② 将至多X张花色不同的手牌置于武将牌上
    local x = player.maxHp - player.hp
    local chosen, suits = {}, {}
    for _ = 1, x do
      local cand = {}
      for _, id in ipairs(player:getCardIds("h")) do
        if not table.contains(chosen, id) then
          local c = Fk:getCardById(id)
          if c and not table.contains(suits, c:getSuitString()) then
            table.insert(cand, id)
          end
        end
      end
      if #cand == 0 then break end
      local res = room:askToChooseCards(player, {
        target = player,
        flag = { card_data = { { "$Hand", cand } } },
        min = 1,
        max = 1,
        cancelable = true,
        skill_name = j_juntun.name,
        prompt = "#j_juntun-put:::" .. (x - #chosen),
      })
      if not res or #res == 0 then break end
      local id = res[1]
      local c = Fk:getCardById(id)
      table.insert(chosen, id)
      if c then table.insert(suits, c:getSuitString()) end
    end

    if #chosen > 0 then
      room:moveCards{
        ids = chosen,
        to = player,
        toArea = Card.PlayerSpecial,
        specialName = PILE,
        moveReason = fk.ReasonPut,
        skillName = j_juntun.name,
        proposer = player,
      }
    end

    -- 标记本轮已发动，供“本轮”摸牌判定
    room:setPlayerMark(player, ACTIVE, 1)
  end,
})

-- 本轮：有与“军屯”花色相同的牌进入弃牌堆 → 摸一张牌
j_juntun:addEffect(fk.AfterCardsMove, {
  global = true,
  -- 自动发动，不弹“是否发动”
  on_cost = function() return true end,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_juntun.name) or player.dead then return false end
    if player:getMark(ACTIVE) == 0 then return false end
    local suits = pileSuits(player)
    if #suits == 0 then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local c = Fk:getCardById(info.cardId)
          if c and table.contains(suits, c:getSuitString()) then
            return true
          end
        end
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    player.room:drawCards(player, 1, j_juntun.name)
  end,
})

-- 测试：回合开始 → 将领到的手牌置于武将牌上，花色互不相同
j_juntun:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_juntun.name)
    room.current = me
    me.maxHp = 4
    me.hp = 2 -- 已损失体力值 = 2 → 至多放2张
    room:obtainCard(me, {
      room:printCard("slash", Card.Spade, 5),
      room:printCard("jink", Card.Heart, 6),
      room:printCard("peach", Card.Spade, 7),
    }, true, fk.ReasonDraw, me, "test")
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return true end
    -- 每次都选第一张候选（已按花色去重），连放2张
    local picks = 0
    local origChoose = room.askToChooseCards
    room.askToChooseCards = function(self, who, params)
      picks = picks + 1
      local ids = params.flag and params.flag.card_data and params.flag.card_data[1][2]
      if picks <= 2 and ids and #ids > 0 then return { ids[1] } end
      return {}
    end
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToSkillInvoke = origInvoke
    room.askToChooseCards = origChoose

    lu.assertEquals(#me:getPile(PILE), 2, "至多放置X=2张牌")
    local suits = pileSuits(me)
    lu.assertEquals(#suits, 2, "武将牌上的牌花色应互不相同")
  end)
end)

-- 测试：本轮与军屯花色相同的牌进入弃牌堆 → 摸一张牌
j_juntun:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_juntun.name)
    room.current = me
    me.maxHp = 4
    me.hp = 3
    c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    -- 手动放一张黑桃牌上武将牌
    room:moveCards{
      ids = { c1.id }, to = me, toArea = Card.PlayerSpecial, specialName = PILE,
      moveReason = fk.ReasonPut, skillName = j_juntun.name, proposer = me,
    }
    room:setPlayerMark(me, ACTIVE, 1)
  end)

  FkTest.runInRoom(function()
    local before = #me:getCardIds("h")
    local c2 = room:printCard("jink", Card.Spade, 9)
    room:moveCards{ ids = { c2.id }, toArea = Card.DiscardPile, moveReason = fk.ReasonDiscard }
    lu.assertEquals(#me:getCardIds("h"), before + 1, "同花色牌进入弃牌堆应摸一张")
    -- 不同花色不应摸牌
    local before2 = #me:getCardIds("h")
    local c3 = room:printCard("jink", Card.Club, 9)
    room:moveCards{ ids = { c3.id }, toArea = Card.DiscardPile, moveReason = fk.ReasonDiscard }
    lu.assertEquals(#me:getCardIds("h"), before2, "不同花色牌进入弃牌堆不应摸牌")
  end)
end)

return j_juntun
