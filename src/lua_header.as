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
  trace(slice(arguments).join("\t"));
  return [];
};

function lua_load() {
  throw new Error("Flash does not support runtime compilation, so you can only use precompiled Lua code in Flash");
}

// so metatable accesses in lua don't anger Flash
String.prototype.metatable = Number.prototype.metatable = Boolean.prototype.metatable = null;

