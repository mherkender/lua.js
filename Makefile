# ex:noexpandtab:softtabstop=0

CLOSURE_COMPILER=closurecompiler/compiler.jar
NODE=node

GENERATED_FILES=lua2js lua.js lua.as lua.min.js lua+parser.js lua+parser.min.js

TESTS=$(patsubst %.lua,%.js,$(wildcard tests/*.lua))

build: $(GENERATED_FILES)

all: clean build test luajs.zip

node_modules/jison:
	npm install jison

closurecompiler/compiler.jar:
	wget http://closure-compiler.googlecode.com/files/compiler-latest.zip
	mkdir -p closurecompiler
	unzip -o compiler-latest.zip -d closurecompiler
	rm -f compiler-latest.zip

lua2js: src/lua2js_start src/lua_parser.js src/lua2js_end
	cat $^ > $@
	chmod +x $@ || rm -f $@

src/lua_parser.js: src/build_lua_parser.js src/lua.jison node_modules/jison
	cd . && $(NODE) $<

lua.js: src/lua_header.js src/lualib.js
	cat $^ > $@

lua.as: src/lua_header.as src/lualib.js
	cat $^ > $@

lua.min.js: lua.js $(CLOSURE_COMPILER)
	java -jar $(CLOSURE_COMPILER) --compilation_level SIMPLE_OPTIMIZATIONS --js_output_file $@ --js $<

lua+parser.js: src/lua_header.js src/lua_parser.js src/lualib.js
	cat $^ > $@

# TODO: SIMPLE_OPTIMIZATIONS is breaking lua_load
lua+parser.min.js: lua+parser.js $(CLOSURE_COMPILER)
	java -jar $(CLOSURE_COMPILER) --compilation_level WHITESPACE_ONLY --js_output_file $@ --js $<

luajs.zip: $(GENERATED_FILES)
	zip $@ $^

clean:
	rm -rf $(GENERATED_FILES) src/lua_parser.js compiler-latest.zip luajs.zip
	rm -f tests/*.js

clean_all: clean
	rm -rf node_modules/jison closurecompiler

test: $(TESTS)

tests/%.js: lua2js tests/%.lua
	./lua2js $< $@
	cat lua.js > /tmp/test.js
	cat $@  >> /tmp/test.js
	cp /tmp/test.js $@

.PHONY: build clean test all

.SUFFIXES:
