var fs = require("fs");
var Generator = require("jison").Generator;
var generator = new Generator(fs.readFileSync('src/lua.jison', 'utf8'), {type: "slr"})
fs.writeFileSync("src/lua_parser.js", generator.generate({
  moduleType: "js",
  moduleName: "lua_parser",
}));
