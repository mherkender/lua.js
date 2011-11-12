/*
   Copyright 2011 Maximilian Herkender

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

// get past a type issue in as3 in some situations
var parseFloat2 = parseFloat;

var print = window.console ? function () {
  try {
    console.log.apply(console, arguments);
  } catch (e) {
    // do nothing
  }
} : (trace ? trace : function () {});

// slice that works in as3 and js on arguments
function slice(arr, start) {
  if (arr.slice) {
    return arr.slice(start);
  } else {
    return Array.prototype.slice.call(arr, start);
  }
}

// not supported call
function not_supported() {
  throw new Error("Not supported");
}

function ensure_arraymode(table) {
  if (!table.arraymode) {
    var newints = [];
    for (var i in table.ints) {
      if (table.ints[i] != null) {
        newints[i] = table.ints[i];
      }
    }
    table.ints = newints;
    table.arraymode = true;
  }
}
function ensure_notarraymode(table) {
  if (table.arraymode) {
    var newints = {};
    for (var i in table.ints) {
      if (table.ints[i] != null) {
        newints[i] = table.ints[i];
      }
    }
    table.ints = newints;
    delete table.arraymode;
  }
}

// methods used by generated lua code
function lua_true(op) {
  return op != null && op !== false;
}
function lua_not(op) {
  return op == null || op === false;
}
function lua_and(op1, op2) {
  return op1 == null || op1 === false ? op1 : op2();
}
function lua_or(op1, op2) {
  return op1 != null && op1 !== false ? op1 : op2();
}
function lua_assertfloat(n) {
  var result = parseFloat(n);
  if (isNaN(result)) {
    throw new Error("Invalid number: " + n);
  }
  return result;
}
function lua_newtable(autoIndexList) {
  var result = {str: {}, ints: {}, bool: {}};
  for (var i = 1; i < arguments.length - 1; i += 2) {
    switch (typeof arguments[i]) {
      case "string":
        result.str[arguments[i]] = arguments[i + 1];
        break;
      case "number":
        result.ints[arguments[i]] = arguments[i + 1];
        break;
      case "boolean":
        result.bool[arguments[i]] = arguments[i + 1];
        break;
      default:
        throw new Error("Unsupported type for table: " + (typeof arguments[i]));
    }
  }
  if (autoIndexList) {
    ensure_arraymode(result);
    if (result.ints.length == 0) {
      result.ints = autoIndexList;
    } else {
      i = autoIndexList.length;
      while (i-- > 0) {
        result.ints[i] = autoIndexList[i];
      }
    }
  }
  return result;
}
function lua_len(op) {
  if (typeof op == "string") {
    return [op.length];
  } else if (typeof op == "object" && op != null) {
    if (op.length == null) {
      var index = 0;
      if (op.arraymode) {
        while (op.ints[index++] != null) {};
        return [op.length = index - 1];
      } else {
        while (op.ints[++index] != null) {};
        return [op.length = index - 1];
      }
    } else {
      return [op.length];
    }
  } else {
    var h = op.metatable && op.metatable.str["__len"];
    if (h) {
      return h(op)[0];
    } else {
      throw new Error("Length of <" + op + "> not supported");
    }
  }
}
function lua_call(func, args) {
  if (typeof func == "function") {
    return func.apply(null, args);
  } else {
    var h = func.metatable && func.metatable.str["__call"];
    if (h != null) {
      return h.apply(null, [func].concat(args))[0];
    } else {
      throw new Error("Could not call " + func + " as function");
    }
  }
}
function lua_mcall(obj, methodname, args) {
  return lua_call(lua_tableget(obj, methodname), [obj].concat(args));
}
function lua_eq(op1, op2) {
  if (typeof op1 != typeof op2) {
    if (op1 == null && op2 == null) {
      return true;
    }
    return false;
  }
  if (op1 == op2) {
    return true;
  }
  if (op1 == null || op2 == null) {
    return false;
  }
  var h = (op1.metatable && op1.metatable.str["__eq"]) || (op2.metatable && op2.metatable.str["__eq"]);
  if (h) {
    return h(op1, op2)[0];
  } else {
    return false;
  }
}
function lua_lt(op1, op2) {
  if (typeof op1 == "number" && typeof op2 == "number") {
    return op1 < op2;
  } else if (typeof op1 == "string" && typeof op2 == "string") {
    // TODO: not sure how similar lua/javascript string comparison is
    return op1 < op2;
  } else {
    var h = (op1.metatable && op1.metatable.str["__lt"]) || (op2.metatable && op2.metatable.str["__lt"]);
    if (h) {
      return h(op1, op2)[0];
    } else {
      throw new Error("Unable to compare " + op1 + " and " + op2);
    }
  }
}
function lua_lte(op1, op2) {
  if (typeof op1 == "number" && typeof op2 == "number") {
    return op1 <= op2;
  } else if (typeof op1 == "string" && typeof op2 == "string") {
    // TODO: not sure how similar lua/javascript string comparison is
    return op1 <= op2;
  } else {
    var h = (op1.metatable && op1.metatable.str["__le"]) || (op2.metatable && op2.metatable.str["__le"]);
    if (h) {
      return h(op1, op2)[0];
    } else {
      var h = (op1.metatable && op1.metatable.str["__lt"]) || (op2.metatable && op2.metatable.str["__lt"]);
      if (h) {
        return !h(op2, op1)[0];
      } else {
        throw new Error("Unable to compare " + op1 + " and " + op2);
      }
    }
  }
}
function lua_unm(op) {
  var o = parseFloat(op);
  if (o != null) {
    return -o;
  } else {
    var h = op.metatable && op.metatable.str["__unm"];
    if (h) {
      return h(op)[0];
    } else {
      throw new Error("Inverting <" + op + "> not supported");
    }
  }
}
function lua_add(op1, op2) {
  var o1 = parseFloat(op1), o2 = parseFloat(op2);
  if (o1 == null || o2 == null) {
    var h = (op1.metatable && op1.metatable.str["__add"]) || (op2.metatable && op2.metatable.str["__add"]);
    if (h) {
      return h(op1, op2)[0];
    } else {
      throw new Error("Adding <" + op1 + "> and <" + op2 + "> not supported");
    }
  } else {
    return o1 + o2;
  }
}
function lua_subtract(op1, op2) {
  var o1 = parseFloat(op1), o2 = parseFloat(op2);
  if (o1 == null || o2 == null) {
    var h = (op1.metatable && op1.metatable.str["__sub"]) || (op2.metatable && op2.metatable.str["__sub"]);
    if (h) {
      return h(op1, op2)[0];
    } else {
      throw new Error("Subtracting <" + op1 + "> and <" + op2 + "> not supported");
    }
  } else {
    return o1 - o2;
  }
}
function lua_divide(op1, op2) {
  var o1 = parseFloat(op1), o2 = parseFloat(op2);
  if (o1 == null || o2 == null) {
    var h = (op1.metatable && op1.metatable.str["__div"]) || (op2.metatable && op2.metatable.str["__div"]);
    if (h) {
      return h(op1, op2)[0];
    } else {
      throw new Error("Dividing <" + op1 + "> and <" + op2 + "> not supported");
    }
  } else {
    return o1 / o2;
  }
}
function lua_multiply(op1, op2) {
  var o1 = parseFloat(op1), o2 = parseFloat(op2);
  if (o1 == null || o2 == null) {
    var h = (op1.metatable && op1.metatable.str["__mul"]) || (op2.metatable && op2.metatable.str["__mul"]);
    if (h) {
      return h(op1, op2)[0];
    } else {
      throw new Error("Multiplying <" + op1 + "> and <" + op2 + "> not supported");
    }
  } else {
    return o1 * o2;
  }
}
function lua_power(op1, op2) {
  var o1 = parseFloat(op1), o2 = parseFloat(op2);
  if (o1 == null || o2 == null) {
    var h = (op1.metatable && op1.metatable.str["__pow"]) || (op2.metatable && op2.metatable.str["__pow"]);
    if (h) {
      return h(op1, op2)[0];
    } else {
      throw new Error("<" + op1 + "> to the power of <" + op2 + "> not supported");
    }
  } else {
    return Math.pow(o1, o2);
  }
}
function lua_mod(op1, op2) {
  var o1 = parseFloat(op1), o2 = parseFloat(op2);
  if (o1 == null || o2 == null) {
    var h = (op1.metatable && op1.metatable.str["__mod"]) || (op2.metatable && op2.metatable.str["__mod"]);
    if (h) {
      return h(op1, op2)[0];
    } else {
      throw new Error("Modulo <" + op1 + "> and <" + op2 + "> not supported");
    }
  } else {
    if (o1 >= 0) {
      if (o2 >= 0) {
        return o1 % o2;
      } else {
        return (o2 + (o1 % o2)) % o2;
      }
    } else {
      if (o2 >= 0) {
        return (o2 + (o1 % o2)) % o2;
      } else {
        return o1 % o2;
      }
    }
  }
}
function lua_rawget(table, key) {
  switch (typeof key) {
    case "string":
      return table.str[key];
    case "number":
      if (table.arraymode) {
        return table.ints[key - 1];
      } else {
        return table.ints[key];
      }
    case "boolean":
      return table.bool[key];
    default:
      throw new Error("Unsupported key for table: " + (typeof key));
  }
}
function lua_rawset(table, key, value) {
  delete table.length;
  switch (typeof key) {
    case "string":
      if (value == null) {
        delete table.str[key];
      } else {
        table.str[key] = value;
      }
      break;
    case "number":
      ensure_notarraymode(table);
      if (value == null) {
        delete table.ints[key];
      } else {
        table.ints[key] = value;
      }
      break;
    case "boolean":
      if (value == null) {
        delete table.bool[key];
      } else {
        table.bool[key] = value;
      }
      break;
    default:
      throw new Error("Unsupported key for table: " + (typeof key));
  }
}
function lua_tableget(table, key) {
  if (typeof table == "object" && table != null) {
    var v = lua_rawget(table, key);
    if (v != null) {
      return v;
    }
    var h = table.metatable && table.metatable.str["__index"];
    if (h == null) {
      return null;
    }
  } else {
    var h = table.metatable && table.metatable.str["__index"];
    if (h == null) {
      throw new Error("Unable to index key " + key + " from " + table);
    }
  }
  if (typeof h == "function") {
    return h(table, key)[0];
  } else {
    return lua_rawget(h, key);
  }
}
function lua_tableset(table, key, value) {
  if (typeof table == "object" && table != null) {
    if (key == null || (typeof key == "number" && isNaN(key))) {
      throw new Error("Key cannot be NaN or null");
    }
    var v = lua_rawget(table, key);
    if (v != null) {
      lua_rawset(table, key, value);
      return;
    }
    var h = table.metatable && table.metatable.str["__newindex"];
    if (h == null) {
      lua_rawset(table, key, value);
      return;
    }
  } else {
    var h = table.metatable && table.metatable.str["__newindex"];
    if (h == null) {
      throw new Error("Unable to set key " + key + " in table " + table);
    }
  }
  if (typeof h == "function") {
    h(table, key, value);
  } else {
    lua_rawset(h, key, value);
  }
}
function lua_concat(op1, op2) {
  if (typeof op1 == "number" && typeof op2 == "number") {
    throw new Error("number concat not supported yet");
  } else if ((typeof op1 == "string" || typeof op1 == "number") && (typeof op2 == "string" || typeof op2 == "number")) {
    return op1 + op2;
  } else {
    var h = (op1.metatable && op1.metatable.str["__concat"]) || (op2.metatable && op2.metatable.str["__concat"]);
    if (h) {
      return h(op1, op2)[0];
    } else {
      throw new Error("Unable to concat " + op1 + " and " + op2);
    }
  }
}

// core lua functions
var lua_core = {};
lua_core["assert"] = function (value, message) {
  if (arguments.length < 1) {
    message = "assertion failed!";
  }
  if (value != null && value !== false) {
    return value;
  } else {
    throw new Error(message);
  }
};
lua_core["collectgarbage"] = function () {};// no-op
lua_core["dofile"] = function () {
  not_supported();
};
lua_core["error"] = function (message, level) {
  // TODO: "level" is currently ignored
  throw new Error(message);
};
lua_core["getfenv"] = function (func, table) {
  not_supported();
};
lua_core["getmetatable"] = function () {
  not_supported();
};
function _ipairs_next(table, index) {
  var entry;
  if (table.arraymode) {
    entry = table.ints[index];
  } else {
    entry = table.ints[index + 1];
  }
  if (entry == null) {
    return [null, null];
  }
  return [index + 1, entry];
}
lua_core["ipairs"] = function (table) {
  return [_ipairs_next, table, 0];
};
lua_core["load"] = function () {
  not_supported();
};
lua_core["loadfile"] = function () {
  not_supported();
};
lua_core["next"] = function () {
  not_supported();
};
lua_core["pairs"] = function (table) {
  var props = [], i;
  for (i in table.str) {
    props.push(i);
  }
  if (table.arraymode) {
    var j = table.ints.length;
    while (j-- > 0) {
      props.push(j + 1);
    }
  } else {
    for (i in table.ints) {
      props.push(parseFloat(i));
    }
  }
  for (i in table.bools) {
    props.push(i === "true" ? true : false);
  }

  // okay, so I'm faking it here
  // regardless of what key is given, this function will return the next value
  // not sure how to do it the "right way" right now
  i = 0;
  return [function (table, key) {
    var entry;
    do {
      if (i >= props.length) {
        return [null, null];
      }
      key = props[i++];
      entry = lua_rawget(table, key);
    } while (!entry);
    return [key, entry];
  }, table, null];
};
lua_core["pcall"] = function (func) {
  try {
    return [true].concat(func.apply(null, slice(arguments, 1)));
  } catch (e) {
    return [false, e.message];
  }
};
lua_core["print"] = function () {
  print(slice(arguments).join("\t"));
  return [];
};
lua_core["rawequal"] = function () {
  not_supported();
};
lua_core["rawget"] = function (table, key) {
  if (typeof table == "object" && table != null && key != null) {
    return [lua_rawget(table, key)];
  }
  throw new Error("Unable to index key " + key + " from " + table);
};
lua_core["rawset"] = function (table, key, value) {
  if (typeof table == "object" && table != null && key != null) {
    lua_rawset(table, key, value);
    return [table];
  }
  throw new Error("Unable set key " + key + " in " + table);
};
lua_core["select"] = function () {
  not_supported();
};
lua_core["setfenv"] = function (func, table) {
  not_supported();
};
lua_core["setmetatable"] = function (table, metatable) {
  if (typeof table != "object" || table == null) {
    throw new Error("table expected, got " + table);
  }
  if (metatable == null) {
    delete table.metatable;
  } else if (typeof metatable === "object") {
    table.metatable = metatable;
  } else {
    throw new Error("table or nil expected, got " + metatable);
  }
  return [table]
};
lua_core["tonumber"] = function (e, base) {
  if (typeof e == "number") {
    return [e];
  }
  if (base === 10 || base == null) {
    return [parseFloat(e)];
  } else {
    return [parseInt(e, base)];
  }
};
lua_core["tostring"] = function (e) {
  // TODO
  not_supported();
};
lua_core["type"] = function (v) {
  switch (typeof v) {
    case "number":
      return ["number"];
    case "string":
      return ["string"];
    case "boolean":
      return ["boolean"];
    case "function":
      return ["function"];
    case "object":
      return [v === null ? "nil" : "table"];
    case "undefined":
      return ["nil"];
    default:
      throw new Error("Unepected value of type " + typeof v);
  }
};
lua_core["unpack"] = function (list, i, j) {
  not_supported();
};
lua_core["_VERSION"] = "Lua 5.1";
lua_core["xpcall"] = function () {
  not_supported();
};

// coroutine
lua_core["coroutine"] = {};
lua_core["coroutine"]["resume"] = lua_core["coroutine"]["running"] = lua_core["coroutine.status"] = lua_core["coroutine"]["wrap"] = lua_core["coroutine"]["yield"] = lua_core["coroutine"]["create"] = function () {
  not_supported();
};

// debug
lua_core["debug"] = {};
lua_core["debug"]["getmetatable"] = function (obj) {
  return [obj.metatable];
}
lua_core["debug"]["traceback"] = lua_core["debug"]["getfenv"] = lua_core["debug"]["gethook"] = lua_core["debug"]["getinfo"] = lua_core["debug"]["getlocal"] = lua_core["debug"]["getregistry"] = lua_core["debug"]["getupvalue"] = lua_core["debug"]["setfenv"] = lua_core["debug"]["sethook"] = lua_core["debug"]["setlocal"] = lua_core["debug"]["setupvalue"] = lua_core["debug"]["debug"] = function () {
  not_supported();
};

// io
lua_core["io"] = {};
var lua_write_buffer = "";
lua_core["io"]["write"] = function () {
  lua_write_buffer += Array.prototype.join.call(arguments, "");
  var lines = lua_write_buffer.split("\n");
  while (lines.length > 1) {
    print(lines.shift());
  }
  lua_write_buffer = lines[0];
  return [];
}
lua_core["io"]["flush"] = function () {};// no-op
lua_core["io"]["close"] = lua_core["io"]["input"] = lua_core["io"]["lines"] = lua_core["io"]["output"] = lua_core["io"]["popen"] = lua_core["io"]["read"] = lua_core["io"]["tmpfile"] = lua_core["io"]["type"] = lua_core["io"]["open"] = function () {
  not_supported();
}
;
lua_core["io"]["stderr"] = lua_core["io"]["stdin"] = lua_core["io"]["stdout"] = null;

// math
lua_core["math"] = {};
lua_core["math"]["abs"] = function (x) {
  return [Math.abs(x)];
};
lua_core["math"]["acos"] = function (x) {
  return [Math.acos(x)];
};
lua_core["math"]["asin"] = function (x) {
  return [Math.asin(x)];
};
lua_core["math"]["atan"] = function (x) {
  return [Math.atan(x)];
};
lua_core["math"]["atan2"] = function (y, x) {
  return [Math.atan2(y, x)];
};
lua_core["math"]["ceil"] = function (x) {
  return [Math.ceil(x)];
};
lua_core["math"]["cos"] = function (x) {
  return [Math.cos(x)];
};
lua_core["math"]["cosh"] = function (x) {
  return [(Math.exp(x) + Math.exp(-x)) / 2];
};
lua_core["math"]["deg"] = function (x) {
  return [x * (Math.PI / 180)];
};
lua_core["math"]["exp"] = function (x) {
  return [Math.exp(x)];
};
lua_core["math"]["floor"] = function (x) {
  return [Math.floor(x)];
};
lua_core["math"]["fmod"] = function (x, y) {
  return [x % y];
};
lua_core["math"]["frexp"] = function (m, e) {
  not_supported();
};
lua_core["math"]["huge"] = Infinity;
lua_core["math"]["ldexp"] = function (m, e) {
  return [m * Math.pow(2, e)];
};
lua_core["math"]["log"] = function (x) {
  return [Math.log(x)];
};
lua_core["math"]["log10"] = function (x) {
  return [Math.log(x) / Math.LN10];
};
lua_core["math"]["max"] = function () {
  return [Math.max.apply(null, arguments)];
};
lua_core["math"]["min"] = function () {
  return [Math.min.apply(null, arguments)];
};
lua_core["math"]["modf"] = function (x) {
  var frac = x % 1;
  return [x - frac, frac];
};
lua_core["math"]["pi"] = Math.PI;
lua_core["math"]["pow"] = function (x, y) {
  return [Math.pow(x, y)];
};
lua_core["math"]["rad"] = function (x) {
  return [x * (180 / Math.PI)];
};
lua_core["math"]["sin"] = function (x) {
  return [Math.sin(x)];
};
lua_core["math"]["sinh"] = function (x) {
  return [(Math.exp(x) - Math.exp(-x)) / 2];
};
lua_core["math"]["sqrt"] = function (x) {
  return [Math.sqrt(x)];
};
lua_core["math"]["tan"] = function (x) {
  return [Math.tan(x)];
};
lua_core["math"]["tanh"] = function (x) {
  var a = Math.exp(x);
  var b = Math.exp(-x);
  return [(a - b) / (a + b)];
};

var max = 0x100000000;
var seed = (Math.random() * max) & (max - 1);
lua_core["math"]["random"] = function (m, n) {
  // Based on the 32 bit mix function found here:
  // http://www.concentric.net/~Ttwang/tech/inthash.htm
  seed = ~seed + (seed << 15); // seed = (seed << 15) - seed - 1;
  seed = seed ^ (seed >>> 12);
  seed = seed + (seed << 2);
  seed = seed ^ (seed >>> 4);
  seed = seed * 2057; // seed = (seed + (seed << 3)) + (seed << 11);
  seed = seed ^ (seed >>> 16);

  var val;
  if (seed < 0) {
    val = ((seed + max) / max) % 1;
  } else {
    val = (seed / max) % 1;
  }

  if (arguments.length >= 2) {
    if (m >= n) {
      throw new Error("Invalid range");
    }
    return [Math.floor(val * (n - m + 1) + m)];
  } else if (arguments.length == 1) {
    return [Math.floor(val * m + 1)];
  } else {
    return val;
  }
};
lua_core["math"]["randomseed"] = function (x) {
  seed = x & (max - 1);
};

// os
lua_core["os"] = {};
// TODO: this should be different for each script, I think?
var clock_start = (new Date()).getTime() / 1000;
lua_core["os"]["clock"] = function () {
  // This function is supposed to return the time the script has been executing
  // not the time since it started, but I don't know of a way to do this.
  return [(((new Date()).getTime()) / 1000) - clock_start];
};
lua_core["os"]["date"] = function (format, time) {
  return ["[" + time + "]" + format];
};
lua_core["os"]["difftime"] = function (t2, t1) {
  return [t2 - t1];
};
lua_core["os"]["execute"] = function () {
  return 0;// all commands fail
};
lua_core["os"]["exit"] = function () {
  //window.close();
};
lua_core["os"]["getenv"] = function (varname) {
  return [null];
};
lua_core["os"]["remove"] = lua_core["os"]["rename"] = lua_core["os"]["setlocale"] = function () {
  not_supported();
};
lua_core["os"]["time"] = function () {
  // TODO
  not_supported();
};

// package
lua_core["package"] = {};
lua_core["package"]["path"] = "";
lua_core["package"]["cpath"] = "";
lua_core["package"]["loaded"] = {};
lua_core["package"]["loaders"] = {};// TODO
lua_core["package"]["preload"] = {};
lua_core["package"]["seeall"] = lua_core["package"]["loadlib"] = function () {
  not_supported();
};

// string
lua_core["string"] = {};
lua_core["string"]["byte"] = function (s, i, j) {
  if (i == null) {
    i = 0;
  }
  if (j == null) {
    j = i;
  }
  var result = [];
  while (i < j && i < s.length) {
    result.push(s.charCodeAt(i));
  }
  return result;
};
lua_core["string"]["char"] = function () {
  return [String.fromCharCode.apply(null, arguments)];
};
lua_core["string"]["dump"] = function (func) {
  not_supported();
};
lua_core["string"]["find"] = function () {
  // TODO
  not_supported();
};
lua_core["string"]["format"] = function (formatstring) {
  // TODO: Finish implementation
  return ["[" + slice(arguments, 1).join(", ") + "]" + arguments[0]];
};
lua_core["string"]["gmatch"] = function (s, pattern) {
  // TODO
  not_supported();
};
lua_core["string"]["gsub"] = function (s, pattern, repl, n) {
  // TODO
  not_supported();
};
lua_core["string"]["len"] = function (s) {
  if (typeof s == "string") {
    return [s.length];
  } else {
    throw new Error("Input not string");
  }
};
lua_core["string"]["lower"] = function (s) {
  if (typeof s == "string") {
    return [s.toLowerCase()];
  } else {
    throw new Error("Input not string");
  }
};
lua_core["string"]["match"] = function (s) {
  // TODO
  not_supported();
};
lua_core["string"]["rep"] = function (s, n) {
  if (typeof s == "string" && typeof n == "number") {
    var result = [];
    while (n-- > 0) {
      result.push(s);
    }
    return [result.join("")];
  } else {
    throw new Error("Input not string and number");
  }
};
lua_core["string"]["reverse"] = function (s) {
  if (typeof s == "string") {
    return [s.split("").reverse().join("")];
  } else {
    throw new Error("Input not string");
  }
};
lua_core["string"]["sub"] = function (s, i, j) {
  if (i < 0) {
    i = s.length + 1 - i;
  }
  if (j == null) {
    return [s.substring(i)];
  } else if (j < 0) {
    j = s.length + 1 - j;
  }
  return [s.substring(i, j)];
};
lua_core["string"]["upper"] = function (s) {
  if (typeof s == "string") {
    return [s.toUpperCase()];
  } else {
    throw new Error("Input not string");
  }
};

lua_core["table"] = {};
lua_core["table"]["concat"] = function (table, sep, i, j) {
  // TODO
  not_supported();
};
lua_core["table"]["insert"] = function (table, pos, value) {
  ensure_arraymode(table);
  if (arguments.length == 2) {
    value = pos;
    pos = table.ints.length + 1;
  }
  table.ints.splice(pos - 1, 0, value);
  if (table.length != null) {
    table.length++;
  }
  return [];
};
lua_core["table"]["maxn"] = function (table) {
  if (table.arraymode) {
    return [table.ints.length];
  } else {
    var max = 0;
    for (var i in table.ints) {
      var val = parseFloat(i);
      if (val > max) {
        max = val;
      }
    }
    return [max];
  }
};
// TODO: This will probably mess up if pos is not valid
lua_core["table"]["remove"] = function (table, pos) {
  ensure_arraymode(table);
  var value = table.ints[pos - 1];
  table.ints.splice(pos - 1, 1);
  if (table.length != null) {
    table.length--;
  }
  return [value];
};
function _defaultsort(a, b) {
  return [lua_lt(a, b)];
}
lua_core["table"]["sort"] = function (table, comp) {
  if (!comp) {
    comp = _defaultsort;
  }
  ensure_arraymode(table)
  table.ints.sort(function (a, b) {
    return comp(a, b)[0] ? -1 : 1;
  });
  return [];
};

// based on BitOp <http://bitop.luajit.org/>
lua_core["bit"] = {}
lua_core["bit"]["tobit"] = function (x) {
  return [x << 0]
}
lua_core["bit"]["tohex"] = function (x, n) {
  if (n > 0) {
    var str = x.toString(16).substr(-n);
    while (str.length < n) {
      str = "0" + str;
    }
    return [str];
  } else if (n < 0) {
    var str = x.toString(16).substr(n).toUpperCase();
    while (str.length < -n) {
      str = "0" + str;
    }
    return [str];
  } else {
    return [x.toString(16)]
  }
}
lua_core["bit"]["bnot"] = function (x) {
  return [~x];
}
lua_core["bit"]["bor"] = function () {
  var result = 0;
  for (var i = 0; i < arguments.length; i++) {
    result |= arguments[i];
  }
  return [result];
}
lua_core["bit"]["band"] = function (x) {
  var result = 0;
  for (var i = 0; i < arguments.length; i++) {
    result &= arguments[i];
  }
  return [result];
}
lua_core["bit"]["bxor"] = function (x) {
  var result = 0;
  for (var i = 0; i < arguments.length; i++) {
    result ^= arguments[i];
  }
  return [result];
}
lua_core["bit"]["lshift"] = function (x, n) {
  return [x << n];
}
lua_core["bit"]["rshift"] = function (x, n) {
  return [x >>> n];
}
lua_core["bit"]["arshift"] = function (x, n) {
  return [x >> n];
}
lua_core["bit"]["rol"] = function (x, n) {
  n &= 0xf;
  return [(x << n) | (x >>> -n)];
}
lua_core["bit"]["ror"] = function (x, n) {
  n &= 0xf;
  return [(x >>> n) | (x << -n)];
}
lua_core["bit"]["bswap"] = function (x) {
  // from Bit Twiddling hacks <http://graphics.stanford.edu/~seander/bithacks.html>
  x = ((x >> 1) & 0x55555555) | ((x & 0x55555555) << 1);
  x = ((x >> 2) & 0x33333333) | ((x & 0x33333333) << 2);
  x = ((x >> 4) & 0x0F0F0F0F) | ((x & 0x0F0F0F0F) << 4);
  x = ((x >> 8) & 0x00FF00FF) | ((x & 0x00FF00FF) << 8);
  x = (x >> 16) | (x << 16);
  return [x];
}

lua_core["js"] = {};
lua_core["js"]["log"] = function () {
  print.apply(null, arguments);
}
