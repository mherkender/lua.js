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

%lex

%%

\s+                     /* skip whitespace */
"--[["(.|\n|\r)*?"]]--" /* skip multiline comment */
"--".*                  /* skip comment */
"0x"[0-9a-fA-f]+        return 'NUMBER';
\d+(\.\d*)?([eE]"-"?\d+)? return 'NUMBER';
"\""([^\n]|(\.))*?"\""  return 'STRING';
"'"([^\n]|(\.))*?"'"    return 'STRING';
"[["(.|\n|\r)*?"]]"     yytext = longStringToString(yytext); return 'STRING';
":"                     return ':';
";"                     return ';';
"("                     return '(';
")"                     return ')';
"["                     return '[';
"]"                     return ']';
"{"                     return '{';
"}"                     return '}';
"+"                     return '+';
"-"                     return '-';
"*"                     return '*';
"/"                     return '/';
"%"                     return '%';
"^"                     return '^';
"=="                    return '==';
"="                     return '=';
"~="                    return '~=';
"<="                    return '<=';
">="                    return '>=';
"<"                     return '<';
">"                     return '>';
"#"                     return '#';
","                     return ',';
"..."                   return '...';
".."                    return '..';
"."                     return '.';
"not"                   return 'NOT';
"and"                   return 'AND';
"or"                    return 'OR';
"true"                  return 'TRUE';
"false"                 return 'FALSE';
"nil"                   return 'NIL';
"function"              return 'FUNCTION';
"until"                 return 'UNTIL';
"do"                    return 'DO';
"end"                   return 'END';
"while"                 return 'WHILE';
"if"                    return 'IF';
"then"                  return 'THEN';
"elseif"                return 'ELSEIF';
"else"                  return 'ELSE';
"for"                   return 'FOR';
"local"                 return 'LOCAL';
"repeat"                return 'REPEAT';
"in"                    return 'IN';
"return"                return 'RETURN';
"break"                 return 'BREAK';
[a-zA-Z_][a-zA-Z0-9_]*  return 'NAME';
<<EOF>>                 return 'EOF';

/lex

%token NUMBER STRING ":" ";" "(" ")" "[" "]" "{" "}" "." "+" "-" "*" "/" "%" "^" "=" "==" "~=" "<" "<=" ">" ">=" ".." "#" "," "..." NOT AND OR TRUE FALSE NIL FUNCTION UNTIL DO END WHILE IF THEN ELSEIF ELSE FOR LOCAL REPEAT IN RETURN BREAK NAME EOF

%left "OR"
%left "AND"
%left "<" "<=" ">" ">=" "==" "~="
%right ".."
%left "+" "-"
%left "*" "/" "%"
%right "NOT" "#"
%right "^"

%start script

%%

script
  : indent chunk unindent EOF {
    return "var tmp;\n" +
      "var _G = lua_newtable(null, 'arg', lua_newtable());\n" +
      "_G.str['_G'] = _G;\n" +
      "for (var i in lua_core) {\n" +
      "  if (typeof lua_core[i] == 'object') {\n" +
      "    _G.str[i] = lua_newtable();\n" +
      "    for (var j in lua_core[i]) {\n" +
      "      _G.str[i].str[j] = lua_core[i][j];\n" +
      "    }\n" +
      "  } else {\n" +
      "    _G.str[i] = lua_core[i];\n" +
      "  }\n" +
      "}\n" +
      "_G.str['module'] = function (name) {\n" +
      "  lua_createmodule(_G, name, slice(arguments, 1));\n" +
      "};\n" +
      "_G.str['require'] = function (name) {\n" +
      "  lua_require(_G, name);\n" +
      "};\n" +
      "_G.str['package'].str['seeall'] = function (module) {\n" +
      "  if (!module.metatable) {\n" +
      "    module.metatable = lua_newtable();\n" +
      "  }\n" +
      "  module.metatable.str['__index'] = _G;\n" +
      "};\n" +
      "{\n" +
      cleanupLastStatements($2) + "\n" +
      "}\n";
  }
  ;

indent
  : {
    var localsCopy = {}
    for (var i in locals) {
      localsCopy[i] = locals[i];
    }
    stack.push({locals: localsCopy, blockId: blockId});

    indentLevel++;
    blockIdMax++;
    $$ = blockId = blockIdMax;
  }
  ;

unindent
  : {
    var stackData = stack.pop();
    indentLevel--;
    locals = stackData.locals;
    $$ = blockId = stackData.blockId;
  }
  ;

block
  : indent chunk unindent { $$ = $2 }
  ;

loopblock
  : indent chunk unindent {
    // if a function is declared inside of a loop, there are some differences
    // with how variables behave due to the difference in scoping in JS and Lua
    // by wrapping a loop block in a function call, we resolve these problems, but it
    // is only necessary for situations where functions are declared inside of a loop

    if (/\/\/\ lua\ function$/gm.test($2)) {
      $$ = "(function () {\n" +
        cleanupLastStatements($2, true) + "\n" +
        "})();";
    } else {
      $$ = "{\n" + $2 + "\n}";
    }
  }
  ;

semi
  : ";" { }
  | { }
  ;

chunk
  : statlist {
    $$ = "  " + ($1 || "").split("\n").join("\n  ");
  }
  | statlist laststat {
    $$ = "  " + (($1 ? $1 + "\n" : "") + $2).split("\n").join("\n  ");
  }
  ;

prefixexp
  : var {
    if ($1.access) {
      $$ = {single: "lua_tableget(" + $1.prefixexp + ", " + $1.access + ")"};
    } else {
      $$ = {single: $1.prefixexp};
    }
  }
  | functioncall { $$ = {single: $1 + "[0]", multi: $1}; }
  | "(" exp ")" { $$ = {single: "(" + $2.single + ")", simple_form: $2.simple_form}; }
  ;

statlist
  : stat semi statlist {
    if ($3) {
      $$ = $1 + "\n" + $3;
    } else {
      $$ = $1;
    }
  }
  | { }
  ;

stat
  : varlist "=" explist {
    if ($1.length == 1) {
      // avoid tmp entirely for certain situations
      if ($3.exps.length == 1) {
        if ($1[0].access) {
          $$ = "lua_tableset(" + $1[0].prefixexp + ", " + $1[0].access + ", " + $3.exps[0] + ");";
        } else {
          $$ = $1[0].prefixexp + " = " + $3.exps[0] + ";";
        }
      } else {
        if ($1[0].access) {
          $$ = "lua_tableset(" + $1[0].prefixexp + ", " + $1[0].access + ", " + getTempDecl($3) + "[0]);";
        } else {
          $$ = $1[0].prefixexp + " = " + getTempDecl($3) + "[0];";
        }
      }
    } else {
      $$ = "tmp = " + getTempDecl($3) + "; ";
      for (var i = 0; i < $1.length; i++) {
        if ($1[i].access) {
          $$ += "lua_tableset(" + $1[i].prefixexp + ", " + $1[i].access + ", tmp[" + i + "]); ";
        } else {
          $$ += $1[i].prefixexp + " = tmp[" + i + "]; ";
        }
      }
      $$ += "tmp = null;";
    }
  }
  | LOCAL namelist "=" explist {
    if ($2.length == 1) {
      // avoid tmp entirely for certain situations
      if ($4.exps.length == 1) {
        $$ = "var " + $2[0] + " = " + $4.exps[0] + ";";
      } else {
        $$ = "var " + $2[0] + " = " + getTempDecl($4) + "[0];";
      }
    } else {
      $$ = "tmp = " + getTempDecl($4) + "; ";
      for (var i = 0; i < $2.length; i++) {
        $$ += "var " + $2[i] + " = tmp[" + i + "]; ";
      }
      $$ += "tmp = null;";
    }
  }
  | LOCAL namelist { $$ = "var " + $2.join(", ") + ";"; }
  | functioncall { $$ = $1 + ";"; }
  | DO block END { $$ = "/* do */\n" + $2 + "\n/* end */"; }
  | WHILE exp DO loopblock END { $$ = "while (" + getIfExp($2) + ") " + $4; }
  | REPEAT loopblock UNTIL exp { $$ = "do " + $2 + " while (" + getIfExp($4) + ");"; }
  | IF exp THEN block END { $$ = "if (" + getIfExp($2) + ") {\n" + $4 + "\n}"; }
  | IF exp THEN block elseif END { $$ = "if (" + getIfExp($2) + ") {\n" + $4 + "\n} " + $5; }
  | FOR indent namelist "=" exp "," exp DO loopblock unindent END {
    if ($3.length != 1) {
      throw new Error("Only one value allowed in for..= loop");
    }
    $$ = "var " + $3[0] + " = lua_assertfloat(" + $5.single + "), " +
      "stop_" + $2 + " = lua_assertfloat(" + $7.single + ");\n" +
      "for (; " + $3[0] + " <= stop_" + $2 + "; " + $3[0] + "++) " + $9;
  }
  | FOR indent namelist "=" exp "," exp "," exp DO loopblock unindent END {
    if ($3.length != 1) {
      throw new Error("Only one value allowed in for..= loop");
    }
    $$ = "var " + $3[0] + " = lua_assertfloat(" + $5.single + "), " +
      "stop_" + $2 + " = lua_assertfloat(" + $7.single + "), " +
      "step_" + $2 + " = lua_assertfloat(" + $9.single + ");\n" +
      "for (; step_" + $2 + " > 0 ? " + $3[0] + " <= stop_" + $2 + " : " + $3[0] + " >= stop_" + $2 + "; " + $3[0] + " += step_" + $2 + ") " + $11;
  }
  | FOR indent namelist IN explist DO loopblock unindent END {
    $$ = "var " + $3.join(", ") + ";\n" +
      "tmp = " + getTempDecl($5) + ";\n" +
      "var f_" + $2 + " = tmp[0], " +
      "s_" + $2 + " = tmp[1], " +
      "var_" + $2 + " = tmp[2];\n";

    if ($3.length == 1) {
      $$ += "tmp = null;\n" +
        "while ((" + $3[0] + " = lua_call(f_" + $2 + ", [s_" + $2 + ", var_" + $2 + "])[0]) != null) " + $7;
    } else {
      $$ += "while ((tmp = lua_call(f_" + $2 + ", [s_" + $2 + ", var_" + $2 + "]))[0] != null) {\n" +
        "  var_" + $2 + " = tmp[0];\n";
      for (var i = 0; i < $3.length; i++) {
        $$ += "  " + $3[i] + " = tmp[" + i + "];\n";
      }
      $$ += "  " + $7.split("\n").join("\n  ") + "\n" +
        "}\n" +
        "tmp = null;";
    }
  }
  | FUNCTION funcname funcbody {
    $$ = "_G";
    for (var i = 0; i < $2.length; i++) {
      $$ += ".str['" + $2[i] + "']";
    }
    $$ += " = " + $3 + ";";
  }
  | FUNCTION funcname ":" NAME mfuncbody {
    $$ = "_G";
    for (var i = 0; i < $2.length; i++) {
      $$ += ".str['" + $2[i] + "']";
    }
    $$ += ".str['" + $4 + "'] = " + $5 + ";";
  }
  | LOCAL FUNCTION NAME funcbody {
    $$ = "var " + getLocal($3) + " = " + $4 + ";";
  }
  ;

laststat
  : RETURN explist {
    $$ = "/*return " + getTempDecl($2) + "*/";
  }
  | RETURN {
    $$ = "/*return []*/";
  }
  | BREAK { $$ = "/*break*/"; }
  ;

elseif
  : ELSEIF exp THEN block {
    $$ = "else if (" + getIfExp($2) + ") {\n" +
      $4 + "\n" +
      "}";
  }
  | ELSEIF exp THEN block elseif {
    $$ = "else if (" + getIfExp($2) + ") {\n" +
      $4 + "\n" +
      "} " + $5;
  }
  | ELSE block {
    $$ = "else {\n" +
      $2 + "\n" +
      "}";
  }
  ;

varlist
  : var "," varlist { $$ = [$1].concat($3); }
  | var { $$ = [$1]; }
  ;

explist
  : explist "," exp { $$ = {exps: $1.exps.concat([$3.single]), endmulti: $3.multi}; }
  | exp { $$ = {exps: [$1.single], endmulti: $1.multi}; }
  ;

namelist
  : namelist "," NAME { $$ = $1.concat([getLocal($3)]); }
  | NAME { $$ = [getLocal($1)]; }
  ;

arglist
  : arglist "," NAME { $$ = $1.concat([setLocal($3, "_" + $3)]); }
  | NAME { $$ = [setLocal($1, "_" + $1)]; }
  ;

funcname
  : NAME "." funcname { $$ = [$1].concat($3); }
  | NAME { $$ = [$1]; }
  ;

exp
  : NUMBER { $$ = {single: $1, is_number: true}; }
  | STRING { $$ = {single: $1}; }
  | TRUE { $$ = {single: 'true'}; }
  | FALSE { $$ = {single: 'false'}; }
  | tableconstructor { $$ = {single: $1}; }
  | NIL { $$ = {single: 'null'}; }
  | prefixexp { $$ = $1; }
  | FUNCTION funcbody {
    $$ = {single: $2};
  }
  | exp "+" exp { $$ = {single: 'lua_add(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "-" exp { $$ = {single: 'lua_subtract(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "*" exp { $$ = {single: 'lua_multiply(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "/" exp { $$ = {single: 'lua_divide(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "^" exp { $$ = {single: 'lua_power(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "%" exp { $$ = {single: 'lua_mod(' + $1.single + ', ' + $3.single + ')'}; }
  | exp ".." exp { $$ = {single: 'lua_concat(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "<" exp { $$ = {single: 'lua_lt(' + $1.single + ', ' + $3.single + ')'}; }
  | exp ">" exp { $$ = {single: 'lua_lt(' + $3.single + ', ' + $1.single + ')'}; }
  | exp "<=" exp { $$ = {single: 'lua_lte(' + $1.single + ', ' + $3.single + ')'}; }
  | exp ">=" exp { $$ = {single: 'lua_lte(' + $3.single + ', ' + $1.single + ')'}; }
  | exp "==" exp { $$ = {single: 'lua_eq(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "~=" exp { $$ = {single: '!lua_eq(' + $1.single + ', ' + $3.single + ')'}; }
  | exp AND exp {
    $$ = {
      single: 'lua_and(' + $1.single + ', function () {return ' + $3.single + ';})',
      simple_form: '(' + getIfExp($1) + ' && ' + getIfExp($3) + ')'
    };
  }
  | exp OR exp {
    $$ = {
      single: 'lua_or(' + $1.single + ', function () {return ' + $3.single + ';})',
      simple_form: '(' + getIfExp($1) + ' || ' + getIfExp($3) + ')'
    };
  }
  | "-" exp { $$ = {single: $2.is_number ? ('-' + $2.single) : ('lua_unm(' + $2.single + ')')}; }
  | NOT exp { $$ = {single: 'lua_not(' + $2.single + ')'}; }
  | "#" exp { $$ = {single: 'lua_len(' + $2.single + ')'}; }
  | "..." { $$ = {single: 'varargs[0]', multi: 'varargs'}; }
  ;

tableconstructor
  : "{" "}" { $$ = "lua_newtable()"; }
  | "{" fieldlist fieldsepend "}" {
    $$ = "lua_newtable(" + getTempDecl($2);
    if ($2.keyed) {
      for (var i in $2.keyed) {
        $$ += ", " + $2.keyed[i][0] + ", " + $2.keyed[i][1];
      }
    }
    $$ += ")";
  }
  ;

funcbody
  : indent "(" ")" chunk unindent END { $$ = createFunction([], $4); }
  | indent "(" arglist ")" chunk unindent END { $$ = createFunction($3, $5); }
  | indent "(" "..." ")" chunk unindent END { $$ = createFunction([], $6, true); }
  | indent "(" arglist "," "..." ")" chunk unindent END { $$ = createFunction($3, $7, true); }
  ;

mfuncbody
  : indent addself "(" ")" chunk unindent END { $$ = createFunction(["self"], $5); }
  | indent addself "(" arglist ")" chunk unindent END { $$ = createFunction(["self"].concat($4), $6); }
  | indent addself "(" "..." ")" chunk unindent END { $$ = createFunction(["self"], $6, true); }
  | indent addself "(" arglist "," "..." ")" chunk unindent END { $$ = createFunction(["self"].concat($4), $8, true); }
  ;

addself
  : { setLocal("self", "self") }
  ;

var
  : NAME { $$ = {prefixexp: getLocal($1, "_G.str['" + $1 + "']")}; }
  | prefixexp "[" exp "]" { $$ = {prefixexp: $1.single, access: $3.single}; }
  | prefixexp "." NAME { $$ = {prefixexp: $1.single, access: "'" + $3 + "'"}; }
  ;

functioncall
  : prefixexp args {
    $$ = "lua_call(" + $1.single + ", " + getTempDecl($2) + ")";
  } 
  | prefixexp STRING { $$ = "lua_call(" + $1.single + ", [" + $2 + "])"; }
  | prefixexp tableconstructor { $$ = "lua_call(" + $1.single + ", [" + $2 + "])"; }
  | prefixexp ":" NAME args { $$ = "lua_mcall(" + $1.single + ", '" + $3 + "', " + getTempDecl($4) + ")"; }
  | prefixexp ":" NAME STRING { $$ = "lua_mcall(" + $1.single + ", '" + $3 + "', [" + $4 + "])"; }
  | prefixexp ":" NAME tableconstructor { $$ = "lua_mcall(" + $1.single + ", '" + $3 + "', [" + $4 + "])"; }
  ;

args
  : "(" explist ")" { $$ = $2; }
  | "(" ")" { $$ = {exps: []}; }
  ;

fieldlist
  : fieldlist fieldsep exp { $$ = {keyed: $1.keyed, exps: $1.exps.concat([$3.single]), endmulti: $3.multi}; }
  | fieldlist fieldsep NAME "=" exp { $$ = {keyed: $1.keyed.concat([["'" + $3 + "'", $5.single]]), exps: $1.exps}; }
  | fieldlist fieldsep "[" exp "]" "=" exp { $$ = {keyed: $1.keyed.concat([[$4.single, $7.single]]), exps: $1.exps}; }
  | exp { $$ = {keyed: [], exps: [$1.single], endmulti: $1.endmulti}; }
  | NAME "=" exp { $$ = {keyed: [["'" + $1 + "'", $3.single]], exps: []}; }
  | "[" exp "]" "=" exp { $$ = {keyed: [[$2.single, $5.single]], exps: []}; }
  ;

fieldsep
  : ";" { }
  | "," { }
  ;

fieldsepend
  : ";" { }
  | "," { }
  | {}
  ;

%%

var indentLevel = 0;
var blockId = 0;
var blockIdMax = 0;
var locals = {};
var stack = [];

function getLocal(name, alternative) {
  if (!locals[name]) {
    if (alternative) {
      return alternative;
    }
    locals[name] = "_" + name + "_" + blockId;
  }
  return locals[name];
}

function setLocal(name, localName) {
  return locals[name] = localName;
}

function getTempDecl(explist) {
  if (explist.endmulti) {
    if (explist.exps.length > 1) {
      return "[" + explist.exps.slice(0, -1).join(", ") + "].concat(" + explist.endmulti + ")";
    } else {
      return explist.endmulti;
    }
  } else {
    return "[" + explist.exps.join(", ") + "]";
  }
}

function longStringToString(str) {
  return '"' + str.substring(0, str.length - 2).replace(/^\[\[(\r\n|\r|\n)?/m, "").replace(/\n/mg, "\\n").replace(/\r/mg, "\\r").replace(/\"/mg, "\\\"") + '"';
}

function cleanupLastStatements(str, breakFromFunction) {
  // \044 is used instead of the dollar sign so jison doesn't replace the character
  if (breakFromFunction) {
    return str.replace(/\/\*return\ ((.|\n)*?)\*\//gm, "throw new ReturnValues(\0441);").replace(/\/\*break\*\/$/gm, "return;");
  } else {
    return str.replace(/\/\*return\ ((.|\n)*?)\*\//gm, "return \0441;").replace(/\/\*break\*\//gm, "break;");
  }
}

function createFunction(args, body, hasVarargs) {
  var result = "(function (" + args.join(", ") + ") { // lua function\n" +
    "  var tmp;\n";
  if (hasVarargs) {
    result += "  var varargs = lua_newtable(slice(arguments, " + args.length + "));\n";
  }
  return result + cleanupLastStatements(
      body + "\n" +
      "  /*return []*/\n") +
    "})";
}

function getIfExp(exp) {
  return exp.simple_form || "lua_true(" + exp.single + ")";
}
