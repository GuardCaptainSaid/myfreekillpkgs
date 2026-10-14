local extension = Package:new("wumiao_qunxian")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/wumiao_qunxian/skills")

Fk:loadTranslationTable{
  ["wumiao_qunxian"] = "武庙群贤",
}

local wu_zhangfei = General:new(extension, "wu_zhangfei", "shu", 3, 6)
wu_zhangfei:addSkills { "w_yimeng", "w_jingwu", "w_wuxian" }
Fk:loadTranslationTable{
  ["wu_zhangfei"] = "武张飞",
  ["#wu_zhangfei"] = "勇武神威",
  ["designer:wu_zhangfei"] = "袁焉",
  ["illustrator:wu_zhangfei"] = "豆包AI",
  ["cv:wu_zhangfei"] = "佚名",

  ["~wu_zhangfei"] = "三军尽服，唯愿安民……",
}

return extension