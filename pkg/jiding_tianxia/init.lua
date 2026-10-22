local extension = Package:new("jiding_tianxia")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/jiding_tianxia/skills")

-- 晋势力（与 OL 文德武备一致：登记到神势力映射中）
Fk:appendKingdomMap("god", { "jin" })

Fk:loadTranslationTable{
  ["jiding_tianxia"] = "计定天下",
  ["jin"] = "晋",
}

General:new(extension, "jiwangyi", "wei", 4, 4, General.Female):addSkills { "j_zhenlie", "j_miji" }
Fk:loadTranslationTable{
  ["jiwangyi"] = "计王异",
  ["#jiwangyi"] = "计慧贞妇",
  ["designer:jiwangyi"] = "袁焉",
  ["illustrator:jiwangyi"] = "袁焉",
  ["cv:jiwangyi"] = "佚名",

  ["~jiwangyi"] = "七纵之恩……来世……再报了……",
}

local ji_jiangwei = General:new(extension, "ji_jiangwei", "shu", 3, 4)
ji_jiangwei:addSkills { "j_jizhi2", "j_huitian", "j_liebei" }
ji_jiangwei:addRelatedSkills { "j_huaxin" }
Fk:loadTranslationTable{
  ["ji_jiangwei"] = "计姜维",
  ["#ji_jiangwei"] = "残躯化薪",
  ["designer:ji_jiangwei"] = "袁焉",
  ["illustrator:ji_jiangwei"] = "袁焉",
  ["cv:ji_jiangwei"] = "佚名",

  ["~ji_jiangwei"] = "丞相……姜维……尽力了……",
}

General:new(extension, "ji_xunyu", "wei", 3, 3):addSkills { "j_junmou", "j_zhixin", "j_jiesheng" }
Fk:loadTranslationTable{
  ["ji_xunyu"] = "计荀彧",
  ["#ji_xunyu"] = "大烈忠佐",
  ["designer:ji_xunyu"] = "袁焉",
  ["illustrator:ji_xunyu"] = "豆包AI",
  ["cv:ji_xunyu"] = "佚名",

  ["~ji_xunyu"] = "汉室……终无复兴之日……",
}

General:new(extension, "ji_xunyou", "wei", 3, 4):addSkills { "j_qice", "j_zhiyu" }
Fk:loadTranslationTable{
  ["ji_xunyou"] = "计荀攸",
  ["#ji_xunyou"] = "妙策天成",
  ["designer:ji_xunyou"] = "袁焉",
  ["illustrator:ji_xunyou"] = "豆包AI",
  ["cv:ji_xunyou"] = "佚名",

  ["~ji_xunyou"] = "谋事在人……成事在天……",
}

General:new(extension, "ji_luxun", "wu", 3, 3):addSkills { "j_lianying", "j_jizhi", "j_qianxun", "j_zhanhuo" }
Fk:loadTranslationTable{
  ["ji_luxun"] = "计陆逊",
  ["#ji_luxun"] = "红莲烈火",
  ["designer:ji_luxun"] = "袁焉",
  ["illustrator:ji_luxun"] = "袁焉",
  ["cv:ji_luxun"] = "佚名",

  ["~ji_luxun"] = "火……火……烧起来了……",
}

General:new(extension, "ji_guojia", "wei", 3, 4):addSkills { "j_zhicai", "j_chenglun" }
Fk:loadTranslationTable{
  ["ji_guojia"] = "计郭嘉",
  ["#ji_guojia"] = "天妒英才",
  ["designer:ji_guojia"] = "袁焉",
  ["illustrator:ji_guojia"] = "袁焉",
  ["cv:ji_guojia"] = "佚名",

  ["~ji_guojia"] = "天妒英才……奉孝……去矣……",
}

General:new(extension, "ji_xizhicai", "wei", 3, 4):addSkills { "j_duying", "j_ximing", "j_xvlve", "j_yuji2" }
Fk:loadTranslationTable{
  ["ji_xizhicai"] = "计戏志才",
  ["#ji_xizhicai"] = "殒心夺智",
  ["designer:ji_xizhicai"] = "袁焉",
  ["illustrator:ji_xizhicai"] = "袁焉",
  ["cv:ji_xizhicai"] = "佚名",

  ["~ji_xizhicai"] = "殒身何惧……唯憾大业……未成……",
}

General:new(extension, "ji_simayi", "wei", 3, 4):addSkills { "j_youji", "j_weiji" }
Fk:loadTranslationTable{
  ["ji_simayi"] = "计司马懿",
  ["#ji_simayi"] = "诈病蛰伏",
  ["designer:ji_simayi"] = "袁焉",
  ["illustrator:ji_simayi"] = "袁焉",
  ["cv:ji_simayi"] = "佚名",

  ["~ji_simayi"] = "蛰伏已久……岂能死于……妇人之手……",
}

General:new(extension, "ji_dongzhao", "wei", 3, 4):addSkills { "j_dingji", "j_jiaoxie" }
Fk:loadTranslationTable{
  ["ji_dongzhao"] = "计董昭",
  ["#ji_dongzhao"] = "建策立魏",
  ["designer:ji_dongzhao"] = "袁焉",
  ["illustrator:ji_dongzhao"] = "袁焉",
  ["cv:ji_dongzhao"] = "佚名",

  ["~ji_dongzhao"] = "定都之策……终成大魏基石……",
}

General:new(extension, "ji_liuye", "wei", 3, 4):addSkills { "j_zhushi", "j_polu", "j_qixie" }
Fk:loadTranslationTable{
  ["ji_liuye"] = "计刘晔",
  ["#ji_liuye"] = "奇械定军",
  ["designer:ji_liuye"] = "袁焉",
  ["illustrator:ji_liuye"] = "袁焉",
  ["cv:ji_liuye"] = "佚名",

  ["~ji_liuye"] = "奇械既成……奈何天命……不在我魏……",
}

General:new(extension, "ji_jiangji", "wei", 3, 4):addSkills { "j_liaoxu", "j_quanjiang", "j_yijiu" }
Fk:loadTranslationTable{
  ["ji_jiangji"] = "计蒋济",
  ["#ji_jiangji"] = "策论万机",
  ["designer:ji_jiangji"] = "袁焉",
  ["illustrator:ji_jiangji"] = "袁焉",
  ["cv:ji_jiangji"] = "佚名",

  ["~ji_jiangji"] = "尺牍之间……皆成杀伐之器……",
}

General:new(extension, "ji_manchong", "wei", 3, 3):addSkills { "j_guwei", "j_suofeng", "j_junxing" }
Fk:loadTranslationTable{
  ["ji_manchong"] = "计满宠",
  ["#ji_manchong"] = "镇淮筹法",
  ["designer:ji_manchong"] = "袁焉",
  ["illustrator:ji_manchong"] = "袁焉",
  ["cv:ji_manchong"] = "佚名",

  ["~ji_manchong"] = "峻法之下……无人可免……",
}

General:new(extension, "ji_chenqun", "wei", 3, 4):addSkills { "j_dingpin", "j_caizhuang", "j_dianlv" }
Fk:loadTranslationTable{
  ["ji_chenqun"] = "计陈群",
  ["#ji_chenqun"] = "品第铨才",
  ["designer:ji_chenqun"] = "袁焉",
  ["illustrator:ji_chenqun"] = "袁焉",
  ["cv:ji_chenqun"] = "佚名",

  ["~ji_chenqun"] = "九品官人……终成门阀之阶……",
}

General:new(extension, "ji_huanfan", "wei", 3, 4):addSkills { "j_xiance", "j_jiaochu" }
Fk:loadTranslationTable{
  ["ji_huanfan"] = "计桓范",
  ["#ji_huanfan"] = "智尽难回",
  ["designer:ji_huanfan"] = "袁焉",
  ["illustrator:ji_huanfan"] = "袁焉",
  ["cv:ji_huanfan"] = "佚名",

  ["~ji_huanfan"] = "竖子不足与谋……智士之悲，莫过于此……",
}

General:new(extension, "ji_chengyu", "wei", 3, 4):addSkills { "j_hanji", "j_ejin", "j_gulei" }
Fk:loadTranslationTable{
  ["ji_chengyu"] = "计程昱",
  ["#ji_chengyu"] = "险计弃仁",
  ["designer:ji_chengyu"] = "袁焉",
  ["illustrator:ji_chengyu"] = "佚名",
  ["cv:ji_chengyu"] = "佚名",

  ["~ji_chengyu"] = "弃仁之计……终究……难逃人心……",
}

General:new(extension, "ji_jiaxu", "qun", 3, 3):addSkills { "j_lianpo", "j_mumou" }
Fk:loadTranslationTable{
  ["ji_jiaxu"] = "计贾诩",
  ["#ji_jiaxu"] = "极厄毒士",
  ["designer:ji_jiaxu"] = "袁焉",
  ["illustrator:ji_jiaxu"] = "豆包AI",
  ["cv:ji_jiaxu"] = "佚名",

  ["~ji_jiaxu"] = "算尽苍生……终算不过天命……",
}

General:new(extension, "ji_simashi", "jin", 3, 4):addSkills { "j_sulv", "j_janmo", "j_xieling" }
Fk:loadTranslationTable{
  ["ji_simashi"] = "计司马师",
  ["#ji_simashi"] = "景宪独裁",
  ["designer:ji_simashi"] = "袁焉",
  ["illustrator:ji_simashi"] = "袁焉",
  ["cv:ji_simashi"] = "佚名",

  ["~ji_simashi"] = "鹰视狼顾之局……终是我一手促成……",
}

General:new(extension, "ji_simazhao", "jin", 3, 4):addSkills { "j_zhaoxin", "j_goumou", "j_cuanli" }
Fk:loadTranslationTable{
  ["ji_simazhao"] = "计司马昭",
  ["#ji_simazhao"] = "昭心篡魏",
  ["designer:ji_simazhao"] = "袁焉",
  ["illustrator:ji_simazhao"] = "袁焉",
  ["cv:ji_simazhao"] = "佚名",

  ["~ji_simazhao"] = "兄长……这基业……终是我来守了……",
}

General:new(extension, "ji_wangyun", "qun", 3, 4):addSkills { "j_jianji", "j_jianmou", "j_jianzhi" }
Fk:loadTranslationTable{
  ["ji_wangyun"] = "计王允",
  ["#ji_wangyun"] = "妙计连环",
  ["designer:ji_wangyun"] = "袁焉",
  ["illustrator:ji_wangyun"] = "豆包AI",
  ["cv:ji_wangyun"] = "佚名",

  ["~ji_wangyun"] = "连环之策……终是算漏了一着……",
}

local ji_lusu = General:new(extension, "ji_lusu", "wu", 3, 4)
ji_lusu:addSkills { "j_shezeng", "j_dizhi", "j_xiemeng" }
ji_lusu:addRelatedSkills { "j_qun" }
Fk:loadTranslationTable{
  ["ji_lusu"] = "计鲁肃（有bug，别用）",
  ["#ji_lusu"] = "慷慨解囊",
  ["designer:ji_lusu"] = "袁焉",
  ["illustrator:ji_lusu"] = "袁焉",
  ["cv:ji_lusu"] = "佚名",

  ["~ji_lusu"] = "君子之交……淡如水……",
}

General:new(extension, "ji_sunce", "wu", 3, 4):addSkills { "j_zhixi", "j_bazheng" }
Fk:loadTranslationTable{
  ["ji_sunce"] = "计孙策",
  ["#ji_sunce"] = "坐断东南",
  ["designer:ji_sunce"] = "袁焉",
  ["illustrator:ji_sunce"] = "袁焉",
  ["cv:ji_sunce"] = "佚名",

  ["~ji_sunce"] = "此恨未雪……江东基业……交与仲谋了……",
}

General:new(extension, "ji_chenzhi", "shu", 3, 3):addSkills { "j_hengzheng", "j_zishi" }
Fk:loadTranslationTable{
  ["ji_chenzhi"] = "计陈祗",
  ["#ji_chenzhi"] = "权枢斡旋",
  ["designer:ji_chenzhi"] = "袁焉",
  ["illustrator:ji_chenzhi"] = "豆包AI",
  ["cv:ji_chenzhi"] = "佚名",

  ["~ji_chenzhi"] = "陈祗死不足惜……只恨国事难回……",
}

General:new(extension, "ji_zhugeliang", "qun", 3, 3):addSkills { "j_yanshi", "j_zaoshi", "j_yinju", "j_sangu", "j_zhiji" }
Fk:loadTranslationTable{
  ["ji_zhugeliang"] = "计诸葛亮",
  ["#ji_zhugeliang"] = "龙卧于野",
  ["designer:ji_zhugeliang"] = "袁焉",
  ["illustrator:ji_zhugeliang"] = "豆包AI",
  ["cv:ji_zhugeliang"] = "佚名",

  ["~ji_zhugeliang"] = "出师未捷身先死，长使英雄泪满襟……",
}

-- 计司马昭 皮肤
extension:addSkinPackage{
  content = {
    { enabled_generals = { "ji_simazhao" }, skins = { "ji_simazhao_skin1" } },
  },
}
Fk:loadTranslationTable{
  ["$ji_simazhao_skin1"] = "昭心·魏祚将移",
}

return extension
