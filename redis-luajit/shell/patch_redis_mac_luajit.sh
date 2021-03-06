#!/bin/sh
if [ -f "src/scripting.c" ]; then
	gsed '/luaopen_debug/i luaLoadLib(lua, LUA_JITLIBNAME, luaopen_jit);\nluaLoadLib(lua, LUA_FFILIBNAME, luaopen_ffi);' -i src/scripting.c
fi
if [ -f "src/scripting.cpp" ]; then
    gsed '/luaopen_debug/i luaLoadLib(lua, LUA_JITLIBNAME, luaopen_jit);\nluaLoadLib(lua, LUA_FFILIBNAME, luaopen_ffi);' -i src/scripting.cpp
    gsed '/LUALIB_API int (luaopen_cjson)/a LUALIB_API int (luaopen_ffi) (lua_State *L);\nLUALIB_API int (luaopen_jit) (lua_State *L);' -i src/scripting.cpp
fi
gsed 's/cd lua/cd luajit2/g' deps/Makefile -i
gsed 's/lua\/src/luajit2\/src/g' src/Makefile -i
gsed 's/liblua.a/libluajit.a/g' src/Makefile -i
cd deps
if [ ! -d "lua-cjson" ]; then
	git clone https://github.com/openresty/lua-cjson.git
fi
cd lua-cjson
cd -
if [ ! -d "luajit2" ]; then
	git clone https://github.com/openresty/luajit2.git
fi
cd luajit2
cd -
cp -rf lua/src/lua_* luajit2/src/
cp -rf lua-cjson/*.c lua-cjson/*.h luajit2/src/
gsed 's/^XCFLAGS=/XCFLAGS=-DENABLE_CJSON_GLOBAL/' -i luajit2/src/Makefile
gsed 's/lib_ffi.o/lib_ffi.o fpconv.o lua_cjson.o lua_cmsgpack.o lua_struct.o strbuf.o/' -i luajit2/src/Makefile
gsed 's/<lua.h>/"lua.h"/' -i luajit2/src/lua_cjson.c
gsed 's/<lauxlib.h>/"lauxlib.h"/' -i luajit2/src/lua_cjson.c
