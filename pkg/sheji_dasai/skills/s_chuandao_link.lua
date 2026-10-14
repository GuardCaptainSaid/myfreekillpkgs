-- 授武·传刀派生：传刀目标使用【杀】对传刀主人无视距离
local s_chuandao_link = fk.CreateSkill {
  name = "s_chuandao_link",
}

s_chuandao_link:addEffect("targetmod", {
  bypass_distances = function(self, player, skill, card, to)
    if not player:hasSkill(s_chuandao_link.name) then return false end
    if not card or card.trueName ~= "slash" then return false end
    local oid = player:getMark("@@s_chuandao_owner")
    if oid <= 0 or not to then return false end
    return to.id == oid
  end,
})

return s_chuandao_link