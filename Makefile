# ex:noexpandtab:softtabstop=0

CLOSURE_COMPILER=closurecompiler/compiler.jar

GENERATED_FILES=lua2js lua.js lua.as lua.min.js lua+parser.js lua+parser.min.js

all: $(GENERATED_FILES)

lua2js: src/lua2js src/lua_parser.js
	cp $< $@

src/lua_parser.js: src/build_lua_parser.js src/lua.jison $(shell find jison)
	pwd
	cd . && node $<

lua.js: src/lua_header.js src/lualib.js
	cat $^ > $@

lua.as: src/lua_header.as src/lualib.js
	cat $^ > $@

lua.min.js: lua.js
	java -jar $(CLOSURE_COMPILER) --compilation_level SIMPLE_OPTIMIZATIONS --js_output_file $@ --js $<

lua+parser.js: src/lua_header.js src/lua_parser.js src/lualib.js
	cat $^ > $@

lua+parser.min.js: lua+parser.js
	java -jar $(CLOSURE_COMPILER) --compilation_level SIMPLE_OPTIMIZATIONS --js_output_file $@ --js $<

clean:
	rm -rf $(GENERATED_FILES)

.PHONY: all clean
