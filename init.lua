-- SPDX-License-Identifier: GPL-3.0-or-later

local jiding_tianxia = require("packages.AAA new sanguo.pkg.jiding_tianxia")
local qunxing_cuican = require("packages.AAA new sanguo.pkg.qunxing_cuican")
local ceshi = require("packages.AAA new sanguo.pkg.ceshi")
local wumiao_qunxian = require("packages.AAA new sanguo.pkg.wumiao_qunxian")
local mouding_tianxia = require("packages.AAA new sanguo.pkg.mouding_tianxia")
local zhulin_qixian = require("packages.AAA new sanguo.pkg.zhulin_qixian")
local xinjun_celi = require("packages.AAA new sanguo.pkg.xinjun_celi")
local xinghan_canlan = require("packages.AAA new sanguo.pkg.xinghan_canlan")
local sheji_dasai = require("packages.AAA new sanguo.pkg.sheji_dasai")
local yansheng_pai = require("packages.AAA new sanguo.pkg.yansheng_pai")

Fk:loadTranslationTable{ ["AAA new sanguo"] = "AAA新三国" }

-- 为所有武将设置子包角标（prefix），使武将一览/详情页显示所属子包包名（如"计定天下"）
-- 与 chase2035 的 evol__ 前缀机制一致：prefix 有值时，GeneralCardItem 右下角显示 Lua.tr(prefix)
local subpackages = {
  jiding_tianxia,
  qunxing_cuican,
  ceshi,
  wumiao_qunxian,
  mouding_tianxia,
  zhulin_qixian,
  xinjun_celi,
  xinghan_canlan,
  sheji_dasai,
  yansheng_pai,
}
for _, pkg in ipairs(subpackages) do
  for _, g in ipairs(pkg.generals) do
    g.prefix = pkg.name
  end
end

return {
    jiding_tianxia,
    qunxing_cuican,
    ceshi,
    wumiao_qunxian,
    mouding_tianxia,
    zhulin_qixian,
    xinjun_celi,
    xinghan_canlan,
    sheji_dasai,
    yansheng_pai,
}
