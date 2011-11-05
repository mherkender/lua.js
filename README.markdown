This is an unmaintained, incomplete, experimental project. While it might be useful to some, it should not be considered stable.

The goal of this project was to convert a subset of Lua code to ECMAscript code, without emulating a Lua VM. Since it was only used for one other project, there are many of missing features. I rarely implemented something I didn't need.

Still, through this project I haven't found much about Lua that can't be implemented by converting it to Javascript code, this is just an incomplete implementation of those goals.

Usage
=====

`PYTHONPATH=ply python lua2js.py < input.lua > output.js`

(you can skip the PYTHONPATH=ply part if you have ply installed)

lua.js must also be embedded on the same page as the generated js file. It contains many functions (or placeholders) used by generated code, the core set of lua functions, the lua standard library, and the 3rd-party binops library.

lua2js generates valid ActionScript 3.0 code as well. lua.as should be used instead of lua.js, as it adds a couple extra lines to suppress certain errors that would otherwise occur.

The generated code does not have direct access to any Javascript features or apis. What's generated is supposed to be an isolated environment, and code must be written to bridge the Lua code to ECMAscript. It wouldn't be difficult to add support for Javascript apis, but there's not much point to writing browser-only Lua code.

To call lua code, use the functions in lua.js. For example...

    // this is equivalent to: _G.init(1, 2, 3)
    lua_call(lua_tableget(lua_script, "init"), [1, 2, 3]);
    
    // this is equivalent to: local distFromCenter = _G.get_distance({x=1, y=2})
    var distFromCenter = lua_call(lua_tableget(lua_script, "get_distance"), [lua_newtable(null, "x", 1, "y", 2)])[0];

Known issues
------------

*   There are many missing library functions and incomplete implementations of some functions. They should all be marked with TODO comments, or set to the not_supported function.
*   The global table does not support metatables. This isn't difficult to change, but I didn't use a global metatable in my project, and didn't want to add the overhead associated with it.
*   I think more than a few functions do not handle error conditions in the same way as standard Lua does.
*   The way tables handle numbers has some serious issues with non-integer numbers for keys. From the looks of it they can overwrite integer keys or be lost. This was a major mistake that I never got around to fixing.
*   varargs are not supported
*   I wrote a (bad) random number generator so lua.js could support `math.randomseed()`, it will probably fail all but the most basic requirements of a random number generator.
*   The syntax errors lua2js.py generates are not at all helpful. Use luac to check for syntax errors for now.
*   Long comments (e.g. `--[[ ]]--`) are not supported


Unimplemented ideas
-------------------

*   `load()` can't work, because lua2js is written in Python. To parse code live, lua2js should be written in Javascript.
*   I was able to get `pairs()` and `ipairs()` working, most notably `pairs()` by using a hack. Meanwhile `next()` is unsupported. It seems like it needs some sort of caching system (much like how the # operator function `lua_len()` uses caching) to match indicies to values.
*   `select()` and `unpack()` could be implemented by having these functions throw a special object that has the arguments they're supposed to return. All lua.js functions that call other functions must catch these errors and return them (`lua_call()`, `lua_eq()`, etc).
*   `setfenv()` and `getfenv()` do not work because there is no current way to change the global context of anything. This is pretty difficult. Using setfenv/getfenv on 0 or 1 could work by giving each script have it's own version of setfenv/getfenv that could change _G. For functions, accessing _G through a variable associated with that function (arguments.callee._G?) should work I think. I'm not aware of any Javascript feature to analyze the stack though, so values >1 may never work.
*   Coroutine support is missing, but they could be faked or possibly implemented with web workers.
*   `xpcall()` could be implemented by having `lua_call()` catch errors when an error handler is set. This error handler could be set by `xpcall()` before it calls the function, then set to its original value before `xpcall()` returns what the function returned.
*   Most of the functions in the debug library seem like they cannot be implemented. It would be nice to support `debug.traceback()` for browsers that support similar features though.
*   There is no library support, but it shouldn't be that hard to add.
*   `string.dump()` would be very difficult to implement. The reference indicates it's supposed to return a string that could be used by `loadstring()`. A much improved version of the compiler could detect valid (no upvalue) functions and include their original lua representation somehow associated with the generated javascript function. `string.dump()` could then retrieve this value. It'd be a lot of extra data though, doesn't seem worth it.
*   I'm not sure I implemented vauge variable references ("`a = 2; local a; a = 3;`") correctly, but in the few situations I tried the behavior seemed to match.

Some implementation details
---------------------------

*   Lua functions in Javascript always return arrays. This is to support the multiple return values that Lua uses.
*   Tables are normal objects with keys (str, ints, bool, metatable) for various properties of that table, and to seperate things like the number keys and the string keys, since in Javascript a number is converted to a string when used as a key for an object.
*   The `ints` key in an object can be an array or an object, depending on how it is used. If `table.insert` is used for example, then it will be converted to an array if it is not already one. This is why there's problems mixing integers an non-integers in a single table, the keys can be lost in the transition. Non-integers should be seperated to their own section, but there's a performance penalty in doing so.
*   To force an ints object to be one thing or another, use `ensure_arraymode()` or `ensure_notarraymode()` to force a conversion.
