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
"--[["(.|\n|\r)*?"]]" /* skip multiline comment */
"--".*                  /* skip comment */
"0x"[0-9a-fA-f]+        return 'NUMBER';
\d+(\.\d*)?([eE]"-"?\d+)? return 'NUMBER';
\.\d+([eE]"-"?\d+)?     return 'NUMBER';
"\""("\\."|[^"])*"\""   return 'STRING';
"'"("\\."|[^'])*"'"     return 'STRING';
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
      "var G = lua_newtable2(lua_core);\n" +
      "for (var i in lua_libs) {\n" +
      "  G.str[i] = lua_newtable2(lua_libs[i]);\n" +
      "}\n" +
      "G.str['arg'] = lua_newtable();\n" +
      "G.str['_G'] = G;\n" +
      "G.str['module'] = function (name) {\n" +
      "  lua_createmodule(G, name, slice(arguments, 1));\n" +
      "};\n" +
      "G.str['require'] = function (name) {\n" +
      "  lua_require(G, name);\n" +
      "};\n" +
      "G.str['package'].str['seeall'] = function (module) {\n" +
      "  if (!module.metatable) {\n" +
      "    module.metatable = lua_newtable();\n" +
      "  }\n" +
      "  module.metatable.str['__index'] = G;\n" +
      "};\n" +
      "{\n" +
      $2.simple_form + "\n" +
      "}\n";
  }
  ;

indent
  : {
    var localsCopy = {}
    for (var i in locals) {
      localsCopy[i] = locals[i];
    }
    stack.push({locals: localsCopy, blockId: blockId, inLoop: inLoop});

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
    inLoop = stackData.inLoop;
    if (!inLoop) {
      functionBlockAdded = false;
    }
    $$ = blockId = stackData.blockId;
  }
  ;

funcindent
  : indent {
    functionBlockAdded = false;
    inLoop = false;
    $$ = $1;
  }
  ;

funcunindent
  : unindent {
    functionBlockAdded = true;
    $$ = $1;
  }
  ;

block
  : indent chunk unindent { $$ = $2 }
  ;

loopblock
  : setinloop indent chunk unindent {
    // if a function is declared inside of a loop, there are some differences
    // with how variables behave due to the difference in scoping in JS and Lua
    // by wrapping a loop block in a function call, we resolve these problems, but it
    // is only necessary for situations where functions are declared inside of a loop
    
    if (functionBlockAdded) {
      $$ = {
        block: $3.varfix_form || $3.simple_form,
        use_function_block: true
      };
    } else {
      $$ = {block: $3.simple_form};
    }
  }
  ;

setinloop
  : { inLoop = true; }
  ;

semi
  : ";" { }
  | { }
  ;

chunk
  : statlist {
    $$ = {simple_form: indentStatlist($1.simple_form)};
    if ($1.varfix_form) {
      $$.varfix_form = indentStatlist($1.varfix_form);
    }
  }
  | statlist laststat {
    $$ = {simple_form: indentStatlist($1.simple_form, $2.simple_form)};
    if ($1.varfix_form || $2.varfix_form) {
      $$.varfix_form = indentStatlist(
        $1.varfix_form || $1.simple_form, $2.varfix_form || $2.simple_form);
    }
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
    if ($3.simple_form) {
      $$ = {simple_form: $1.simple_form + "\n" + $3.simple_form};
      if ($1.varfix_form || $3.varfix_form) {
        $$.varfix_form = ($1.varfix_form || $1.simple_form) + "\n" + ($3.varfix_form || $3.simple_form);
      }
    } else {
      $$ = $1;
    }
  }
  | { $$ = {simple_form: ""}; }
  ;

stat
  : varlist "=" explist {
    var tmp;
    if ($1.length == 1) {
      // avoid tmp entirely for certain situations
      if ($3.exps.length == 1) {
        if ($1[0].access) {
          tmp = "lua_tableset(" + $1[0].prefixexp + ", " + $1[0].access + ", " + $3.exps[0] + ");";
        } else {
          tmp = $1[0].prefixexp + " = " + $3.exps[0] + ";";
        }
      } else {
        if ($1[0].access) {
          tmp = "lua_tableset(" + $1[0].prefixexp + ", " + $1[0].access + ", " + getTempDecl($3) + "[0]);";
        } else {
          tmp = $1[0].prefixexp + " = " + getTempDecl($3) + "[0];";
        }
      }
    } else {
      tmp = "tmp = " + getTempDecl($3) + "; ";
      for (var i = 0; i < $1.length; i++) {
        if ($1[i].access) {
          tmp += "lua_tableset(" + $1[i].prefixexp + ", " + $1[i].access + ", tmp[" + i + "]); ";
        } else {
          tmp += $1[i].prefixexp + " = tmp[" + i + "]; ";
        }
      }
      tmp += "tmp = null;";
    }
    $$ = {simple_form: tmp};
  }
  | LOCAL namelist "=" explist {
    var tmp;
    if ($2.length == 1) {
      // avoid tmp entirely for certain situations
      if ($4.exps.length == 1) {
        tmp = "var " + $2[0] + " = " + $4.exps[0] + ";";
      } else {
        tmp = "var " + $2[0] + " = " + getTempDecl($4) + "[0];";
      }
    } else {
      tmp = "tmp = " + getTempDecl($4) + "; ";
      for (var i = 0; i < $2.length; i++) {
        tmp += "var " + $2[i] + " = tmp[" + i + "]; ";
      }
      tmp += "tmp = null;";
    }
    $$ = {simple_form: tmp};
  }
  | LOCAL namelist { $$ = {simple_form: "var " + $2.join(", ") + ";"}; }
  | functioncall { $$ = {simple_form: $1 + ";"}; }
  | DO block END {
    $$ = {simple_form: "// do\n" + $2.simple_form + "\n// end"};
    if ($2.varfix_form) {
      $$.varfix_form = "// do\n" + $2.varfix_form + "\n// end";
    }
  }
  | WHILE exp DO loopblock END { $$ = {simple_form: "while (" + getIfExp($2) + ") " + autoFunctionBlock($4)}; }
  | REPEAT loopblock UNTIL exp { $$ = {simple_form: "do " + autoFunctionBlock($2) + " while (!(" + getIfExp($4) + "));"}; }
  | IF conds END {
    $$ = $2
  }
  | FOR indent namelist "=" exp "," exp DO loopblock unindent END {
    if ($3.length != 1) {
      throw new Error("Only one value allowed in for..= loop");
    }
    if ($9.use_function_block) {
      $$ = {simple_form: "var var_" + $2 + " = " + autoAssertFloat($5) + ", " +
        "stop_" + $2 + " = " + autoAssertFloat($7) + ";\n" +
        "for (; var_" + $2 + " <= stop_" + $2 + "; var_" + $2 + "++) (function() {\n" +
        "  var " + $3[0] + " = var_" + $2 + ";\n" +
        $9.block + "\n" +
        "})();"};
    } else {
      $$ = {simple_form: "var var_" + $2 + " = " + autoAssertFloat($5) + ", " +
        "stop_" + $2 + " = " + autoAssertFloat($7) + ";\n" +
        "for (; var_" + $2 + " <= stop_" + $2 + "; var_" + $2 + "++) {\n" +
        "  var " + $3[0] + " = var_" + $2 + ";\n" +
        $9.block +
        "\n}"};
    }
  }
  | FOR indent namelist "=" exp "," exp "," exp DO loopblock unindent END {
    if ($3.length != 1) {
      throw new Error("Only one value allowed in for..= loop");
    }

    var tmp = "var var_" + $2 + " = " + autoAssertFloat($5) + ", " +
      "stop_" + $2 + " = " + autoAssertFloat($7) + ", " +
      "step_" + $2 + " = " + autoAssertFloat($9) + ";\n" +
      "for (; step_" + $2 + " > 0 ? var_" + $2 + " <= stop_" + $2 + " : var_" + $2 + " >= stop_" + $2 + "; var_" + $2 + " += step_" + $2 + ") ";
    if ($11.use_function_block) {
      tmp += "(function () {\n";
    } else {
      tmp += "{\n";
    }
    tmp += "  var " + $3[0] + " = var_" + $2 + ";\n" +
        $11.block + "\n";
    if ($11.use_function_block) {
      tmp += "\n})();";
    } else {
      tmp += "\n}";
    }
    $$ = {simple_form: tmp};
  }
  | FOR indent namelist IN explist DO loopblock unindent END {
    var tmp;
    tmp = "tmp = " + getTempDecl($5) + ";\n" +
      "var f_" + $2 + " = tmp[0], " +
      "s_" + $2 + " = tmp[1], " +
      "var_" + $2 + " = tmp[2];\n";

    if ($3.length == 1 && !$7.use_function_block) {
      // simple form of this loop that works in certain situations
      tmp += "tmp = null;\n" +
        "while ((var_" + $2 + " = lua_call(f_" + $2 + ", [s_" + $2 + ", var_" + $2 + "])[0]) != null) {\n" +
          "  var " + $3[0] + " = var_" + $2 + ";\n" +
          $7.block +
          "\n}";
    } else {
      tmp += "while ((tmp = lua_call(f_" + $2 + ", [s_" + $2 + ", var_" + $2 + "]))[0] != null) ";
      if ($7.use_function_block) {
        tmp += "(function () {\n";
      } else {
        tmp += "{\n";
      }
      tmp += "  var_" + $2 + " = tmp[0];\n" +
        "  var " + $3[0] + " = var_" + $2;
      for (var i = 1; i < $3.length; i++) {
        tmp += ", " + $3[i] + " = tmp[" + i + "]";
      }
      tmp += ";\n" +
        "  tmp = null;\n" +
        $7.block + "\n";
      if ($7.use_function_block) {
        tmp += "})();";
      } else {
        tmp += "}";
      }
      tmp += "\ntmp = null;";
    }
    $$ = {simple_form: tmp};
  }
  | FUNCTION funcname funcbody {
    var tmp;
    tmp = "G";
    for (var i = 0; i < $2.length; i++) {
      tmp += ".str['" + $2[i] + "']";
    }
    tmp += " = " + $3 + ";";
    $$ = {simple_form: tmp};
  }
  | FUNCTION funcname ":" NAME mfuncbody {
    var tmp;
    tmp = "G";
    for (var i = 0; i < $2.length; i++) {
      tmp += ".str['" + $2[i] + "']";
    }
    tmp += ".str['" + $4 + "'] = " + $5 + ";";
    $$ = {simple_form: tmp};
  }
  | LOCAL FUNCTION NAME funcbody {
    $$ = {simple_form: "var " + getLocal($3) + " = " + $4 + ";"};
  }
  ;

laststat
  : RETURN explist {
    $$ = {
      simple_form: "return " + getTempDecl($2) + ";",
      varfix_form: "throw new ReturnValues(" + getTempDecl($2) + ");"
    };
  }
  | RETURN {
    $$ = {
      simple_form: "return [];",
      varfix_form: "throw new ReturnValues();"
    };
  }
  | BREAK {
    $$ = {
      simple_form: "break;",
      varfix_form: "return;"
    };
  }
  ;

conds
  : condlist {
    $$ = $1;
  }
  | condlist ELSE block {
    $$ = {simple_form: $1.simple_form + " else {\n" + $3.simple_form + "\n}"};
    if ($1.varfix_form || $3.varfix_form) {
      $$.varfix_form = ($1.varfix_form || $1.simple_form) + " else {\n" + ($3.varfix_form || $3.simple_form) + "\n}";
    }
  }
  ;

condlist
  : cond {
    $$ = $1;
  }
  | condlist ELSEIF cond {
    $$ = {simple_form: $1.simple_form + " else " + $3.simple_form};
    if ($1.varfix_form || $3.varfix_form) {
      $$.varfix_form = ($1.varfix_form || $1.simple_form) + " else " + ($3.varfix_form || $3.simple_form)};
    }
  }
  ;

cond
  : exp THEN block {
    $$ = {simple_form: "if (" + getIfExp($1) + ") {\n" + $3.simple_form + "\n}"};
    if ($3.varfix_form) {
      $$.varfix_form = "if (" + getIfExp($1) + ") {\n" + $3.varfix_form + "\n}";
    }
  }
  ;

varlist
  : varlist "," var { $$ = $1.concat([$3]); }
  | var { $$ = [$1]; }
  ;

explist
  : explist "," exp { $$ = {exps: $1.exps.concat([$3.single]), endmulti: $3.multi}; }
  | exp { $$ = {exps: [$1.single], endmulti: $1.multi}; }
  ;

namelist
  : namelist "," NAME { $$ = $1.concat([setLocal($3)]); }
  | NAME { $$ = [setLocal($1)]; }
  ;

arglist
  : arglist "," NAME { $$ = $1.concat([setLocal($3, "_" + $3)]); }
  | NAME { $$ = [setLocal($1, "_" + $1)]; }
  ;

funcname
  : funcname "." NAME { $$ = $1.concat([$3]); }
  | NAME { $$ = [$1]; }
  ;

exp
  : NUMBER { $$ = {single: $1, is_number: true}; }
  | STRING { $$ = {single: $1}; }
  | TRUE { $$ = {single: 'true', simple_form: 'true'}; }
  | FALSE { $$ = {single: 'false', simple_form: 'false'}; }
  | tableconstructor { $$ = {single: $1}; }
  | NIL { $$ = {single: 'null', simple_form: 'null'}; }
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
  | exp "<" exp {
    $$ = {
      single: 'lua_lt(' + $1.single + ', ' + $3.single + ')',
      simple_form: 'lua_lt(' + $1.single + ', ' + $3.single + ')'
    };
  }
  | exp ">" exp {
    $$ = {
      single: 'lua_lt(' + $3.single + ', ' + $1.single + ')',
      simple_form: 'lua_lt(' + $3.single + ', ' + $1.single + ')'
    };
  }
  | exp "<=" exp {
    $$ = {
      single: 'lua_lte(' + $1.single + ', ' + $3.single + ')',
      simple_form: 'lua_lte(' + $1.single + ', ' + $3.single + ')'
    };
  }
  | exp ">=" exp {
    $$ = {
      single: 'lua_lte(' + $3.single + ', ' + $1.single + ')',
      simple_form: 'lua_lte(' + $3.single + ', ' + $1.single + ')'
    };
  }
  | exp "==" exp {
    $$ = {
      single: 'lua_eq(' + $1.single + ', ' + $3.single + ')',
      simple_form: 'lua_eq(' + $1.single + ', ' + $3.single + ')'
    };
  }
  | exp "~=" exp {
    $$ = {
      single: '!lua_eq(' + $1.single + ', ' + $3.single + ')',
      simple_form: '!lua_eq(' + $1.single + ', ' + $3.single + ')'
    };
  }
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
  | NOT exp {
    $$ = {
      single: 'lua_not(' + $2.single + ')',
      simple_form: 'lua_not(' + $2.single + ')'
    };
  }
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
  : funcindent "(" ")" chunk funcunindent END { $$ = createFunction([], $4); }
  | funcindent "(" arglist ")" chunk funcunindent END { $$ = createFunction($3, $5); }
  | funcindent "(" "..." ")" chunk funcunindent END { $$ = createFunction([], $5, true); }
  | funcindent "(" arglist "," "..." ")" chunk funcunindent END { $$ = createFunction($3, $7, true); }
  ;

mfuncbody
  : funcindent addself "(" ")" chunk funcunindent END { $$ = createFunction(["self"], $5); }
  | funcindent addself "(" arglist ")" chunk funcunindent END { $$ = createFunction(["self"].concat($4), $6); }
  | funcindent addself "(" "..." ")" chunk funcunindent END { $$ = createFunction(["self"], $6, true); }
  | funcindent addself "(" arglist "," "..." ")" chunk funcunindent END { $$ = createFunction(["self"].concat($4), $8, true); }
  ;

addself
  : { setLocal("self", "self") }
  ;

var
  : NAME { $$ = {prefixexp: getLocal($1, "G.str['" + $1 + "']")}; }
  | prefixexp "[" exp "]" { $$ = {prefixexp: $1.single, access: $3.single}; }
  | prefixexp "." NAME { $$ = {prefixexp: $1.single, access: "'" + $3 + "'"}; }
  ;

functioncall
  : prefixexp args { $$ = "lua_call(" + $1.single + ", " + getTempDecl($2) + ")"; } 
  | prefixexp ":" NAME args { $$ = "lua_mcall(" + $1.single + ", '" + $3 + "', " + getTempDecl($4) + ")"; }
  ;

args
  : "(" explist ")" { $$ = $2; }
  | "(" ")" { $$ = {exps: []}; }
  | tableconstructor { $$ = {exps: [$1]}; }
  | STRING { $$ = {exps: [$1]}; }
  ;

fieldlist
  : field { $$ = $1; }
  | fieldlist fieldsep field {
    $$ = {
      keyed: $1.keyed.concat($3.keyed),
      exps: $1.exps.concat($3.exps),
      endmulti: $3.endmulti
    };
  }
  ;

field
  : exp { $$ = {keyed: [], exps: [$1.single], endmulti: $1.endmulti}; }
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
var functionBlockAdded = false;
var inLoop = false;

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
  return locals[name] = localName || "_" + name + "_" + blockId;
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

function createFunction(args, body, hasVarargs) {
  var result = "(function (" + args.join(", ") + ") {\n" +
    "  var tmp;\n";
  if (hasVarargs) {
    result += "  var varargs = lua_newtable(slice(arguments, " + args.length + "));\n";
  }
  return result +
    body.simple_form + "\n" +
    "  return [];\n" +
    "})";
}

function getIfExp(exp) {
  return exp.simple_form || "lua_true(" + exp.single + ")";
}

function indentStatlist(statlist, laststat) {
  return "  " + ((statlist && laststat) ? statlist + "\n" + laststat : statlist + (laststat || "")).split("\n").join("\n  ");
}

function autoAssertFloat(possibleNumber) {
  return possibleNumber.is_number ? possibleNumber.single : "lua_assertfloat(" + possibleNumber.single + ")";
}

function autoFunctionBlock(loopblock) {
  return loopblock.use_function_block ?
    "(function() {\n" + loopblock.block + "\n})();" : "{\n" + loopblock.block + "\n}";
}
