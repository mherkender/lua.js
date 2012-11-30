var assert = require("assert")
var fs = require("fs")

var testFiles = fs.readdirSync("tests")

function test(path) {
   describe(path, function(){
    it('should pass', function(){
      require("./tests/" + path)
    })
  })
}

for (var i = 0; i < testFiles.length; i++) {

  var filename = testFiles[i];

  if (filename.indexOf(".js") < 0) {
    continue;
  }

  test(filename);
}
