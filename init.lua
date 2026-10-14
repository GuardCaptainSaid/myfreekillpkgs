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

Fk:loadTranslationTable{ ["AAA new sanguo"] = "AAA新三国" }

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
}