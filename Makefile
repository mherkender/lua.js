# ex:noexpandtab:softtabstop=0

all: lua2js

lua2js: src/lua2js src/lua_parser.js
	cp $< $@

src/lua_parser.js: src/build_lua_parser.js src/lua.jison $(shell find jison)
	node $<

.PHONY: all
