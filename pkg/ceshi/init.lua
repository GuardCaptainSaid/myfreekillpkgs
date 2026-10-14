local extension = Package:new("ceshi")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/ceshi/skills")

Fk:loadTranslationTable{
  ["ceshi"] = "测试包",
}

General:new(extension, "test_ji_jiangwei", "shu", 3, 4):addSkills { "guanxing", "kongcheng", "huoji", "kanpo", "bazhen", "j_cangzhuo", "j_jifeng" }
Fk:loadTranslationTable{
  ["test_ji_jiangwei"] = "测试计姜维",
  ["#test_ji_jiangwei"] = "测试用",
  ["designer:test_ji_jiangwei"] = "袁焉",
  ["illustrator:test_ji_jiangwei"] = "袁焉",
  ["cv:test_ji_jiangwei"] = "佚名",

  ["~test_ji_jiangwei"] = "测试结束……",
}

return extension
