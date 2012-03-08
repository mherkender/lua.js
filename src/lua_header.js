/**
   @license Copyright 2011 Maximilian Herkender

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

var lua_print = function () {
  try {
    console.log.apply(console, arguments);
  } catch (e) {
    // do nothing
  }
  return [];
};

function lua_load(chunk, chunkname) {
  if (!lua_parser) {
    throw new Error("Lua parser not available, perhaps you're not using the lua+parser.js version of the library?");
  }

  var fn;
  eval(
    "fn = function " + (chunkname || "load") + "() {\n" +
    lua_parser.parse(chunk) + "\n" +
    "  return G;\n" +
    "};");
  return fn;
}

