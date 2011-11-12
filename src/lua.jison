%lex

%%

\s+                     /* skip whitespace */
"--[["(.|\n|\r)*?"]]--" /* skip multiline comment */
"--".*                  /* skip comment */
"0x"[0-9a-fA-f]+        return 'NUMBER';
\d+(\.\d*)?([eE]-?\d+)? return 'NUMBER';
"\""([^\n]|(\.))*?"\""  return 'STRING';
"'"([^\n]|(\.))*?"'"    return 'STRING';
":"                     return ':';
";"                     return ';';
"("                     return '(';
")"                     return ')';
"["                     return '[';
"]"                     return ']';
"{"                     return '{';
"}"                     return '}';
"."                     return '.';
"+"                     return '+';
"-"                     return '-';
"*"                     return '*';
"/"                     return '/';
"%"                     return '%';
"^"                     return '^';
"="                     return '=';
"=="                    return '==';
"~="                    return '~=';
"<"                     return '<';
"<="                    return '<=';
">"                     return '>';
">="                    return '>=';
".."                    return '..';
"#"                     return '#';
","                     return ',';
"..."                   return '...';
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
    return "var lua_script = (function () {\n" +
      "  var tmp;\n" +
      "  var _G = lua_newtable(null, 'arg', lua_newtable());\n" +
      "  _G.str['_G'] = _G;\n" +
      "  for (var i in lua_core) {\n" +
      "    if (typeof lua_core[i] == 'object') {\n" +
      "      _G.str[i] = lua_newtable();\n" +
      "      for (var j in lua_core[i]) {\n" +
      "        _G.str[i].str[j] = lua_core[i][j];\n" +
      "      }\n" +
      "    } else {\n" +
      "      _G.str[i] = lua_core[i];\n" +
      "    }\n" +
      "  }\n" +
      $2 + "\n" +
      "  return _G;\n" +
      "})();\n";
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

semi
  : ";" { }
  | { }
  ;

chunk
  : statlist {
    $$ = "  " + ($1 || "").split("\n").join("\n  ");
  }
  | statlist laststat {
    $$ = "  " + (($1 || "") + "\n" + $2).split("\n").join("\n  ");
  }
  ;

varargchunk
  : chunk { throw new Error("varargs not supported"); }
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
  | "(" exp ")" { $$ = {single: "(" + $2.single + ")"}; }
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
  | WHILE exp DO block END { $$ = "while (lua_true(" + $2.single + ")) {\n" + $4 + "\n}"; }
  | REPEAT block UNTIL exp { $$ = "do {\n" + $2 + "\n} while (lua_true(" + $4.single + "));"; }
  | IF exp THEN block END { $$ = "if (lua_true(" + $2.single + ")) {\n" + $4 + "\n}"; }
  | IF exp THEN block elseif END { $$ = "if (lua_true(" + $2.single + ")) {\n" + $4 + "\n} " + $5; }
  | FOR indent namelist "=" exp "," exp DO block unindent END {
    if ($3.length != 1) {
      throw new Error("Only one value allowed in for..= loop");
    }
    $$ = "var " + $3[0] + " = lua_assertfloat(" + $5.single + "), " +
      "stop_" + $2 + " = lua_assertfloat(" + $7.single + ");\n" +
      "for (; " + $3[0] + " <= stop_" + $2 + "; " + $3[0] + "++) {\n" +
      $9 + "\n" +
      "}";
  }
  | FOR indent namelist "=" exp "," exp "," exp DO block unindent END {
    if ($3.length != 1) {
      throw new Error("Only one value allowed in for..= loop");
    }
    $$ = "var " + $3[0] + " = lua_assertfloat(" + $5.single + "), " +
      "stop_" + $2 + " = lua_assertfloat(" + $7.single + "), " +
      "step_" + $2 + " = lua_assertfloat(" + $9.single + ");\n" +
      "for (; step_" + $2 + " > 0 ? " + $3[0] + " <= stop_" + $2 + " : " + $3[0] + " >= stop_" + $2 + "; " + $3[0] + " += step_" + $2 + ") {\n" +
      $11 + "\n" +
      "}";
  }
  | FOR indent namelist IN explist DO block unindent END {
    $$ = "tmp = " + getTempDecl($5) + "; " +
      "var f_" + $2 + " = tmp[0], " +
      "s_" + $2 + " = tmp[1], " +
      "var_" + $2 + " = tmp[2]; " +
      "tmp = null;\n" +
      "var " + $3.join(", ") + ";\n";

    if ($3.length == 1) {
      $$ += "while ((" + $3[0] + " = lua_call(f_" + $2 + ", [s_" + $2 + ", var_" + $2 + "])[0]) != null) {\n" +
        $7 + "\n" +
        "}";
    } else {
      $$ += "while ((tmp = lua_call(f_" + $2 + ", [s_" + $2 + ", var_" + $2 + "]))[0] != null) {\n";
      for (var i = 0; i < $3.length; i++) {
        $$ += "  " + $3[i] + " = tmp[" + i + "];\n";
      }
      $$ += "  tmp = null;\n" +
        $7 + "\n" +
        "}";
    }
  }
  | FUNCTION funcname indent funcbody unindent {
    $$ = "_G";
    for (var i = 0; i < $2.length; i++) {
      $$ += ".str['" + $2[i] + "']";
    }
    $$ += " = (function (" + $4.args.join(", ") + ") {\n" +
      "  var tmp;\n" +
      $4.body + "\n" +
      "  return [];\n" +
      "});";
  }
  | LOCAL FUNCTION NAME indent funcbody unindent {
    $$ = "var " + getLocal($3) + " = (function (" + $5.args.join(", ") + ") {\n" +
      "  var tmp;\n" +
      $5.body + "\n" +
      "  return [];\n" +
      "}";
  }
  ;

laststat
  : RETURN explist {
    $$ = "return " + getTempDecl($2) + ";";
  }
  | RETURN { $$ = "return [];"; }
  | BREAK { $$ = "break;"; }
  ;

elseif
  : ELSEIF exp THEN block {
    $$ = "else if (lua_true(" + $2.single + ")) {\n" +
      $4 + "\n" +
      "}";
  }
  | ELSEIF exp THEN block elseif {
    $$ = "else if (lua_true(" + $2.single + ")) {\n" +
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
  : var "," varlist { $$ = $3.concat([$3]); }
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
  | NAME { $$ = [setLocal($3, "_" + $3)]; }
  ;

funcname
  : NAME "." funcname { $$ = [$1].concat($3); }
  | NAME { $$ = [$1]; }
  ;

exp
  : NUMBER { $$ = {single: $1}; }
  | STRING { $$ = {single: $1}; }
  | TRUE { $$ = {single: 'true'}; }
  | FALSE { $$ = {single: 'false'}; }
  | tableconstructor { $$ = {single: $1}; }
  | NIL { $$ = {single: 'null'}; }
  | prefixexp { $$ = $1; }
  | FUNCTION indent funcbody unindent {
    $$ = {single: "(function (" + $3.args.join(", ") + ") {\n" +
      "  var tmp;\n"+
      $3.body + "\n"+
      "  return [];\n" +
      "})"};
  }
  | exp "+" exp { $$ = {single: 'lua_add(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "-" exp { $$ = {single: 'lua_subtract(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "*" exp { $$ = {single: 'lua_multiply(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "/" exp { $$ = {single: 'lua_divide(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "^" exp { $$ = {single: 'lua_power(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "%" exp { $$ = {single: 'lua_mod(' + $1.single + ', ' + $3.single + ')'}; }
  | exp ".." exp { $$ = {single: 'lua_concat(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "<" exp { $$ = {single: 'lua_lt(' + $1.single + ', ' + $3.single + ')'}; }
  | exp ">" exp { $$ = {single: 'lua_gt(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "<=" exp { $$ = {single: 'lua_lte(' + $1.single + ', ' + $3.single + ')'}; }
  | exp ">=" exp { $$ = {single: 'lua_gte(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "==" exp { $$ = {single: 'lua_eq(' + $1.single + ', ' + $3.single + ')'}; }
  | exp "~=" exp { $$ = {single: 'lua_neq(' + $1.single + ', ' + $3.single + ')'}; }
  | exp AND exp { $$ = {single: 'lua_and(' + $1.single + ', ' + $3.single + ')'}; }
  | exp OR exp { $$ = {single: 'lua_or(' + $1.single + ', ' + $3.single + ')'}; }
  | "-" exp { $$ = {single: 'lua_unm(' + $2.single + ')'}; }
  | NOT exp { $$ = {single: 'lua_not(' + $2 + ')'}; }
  | "#" exp { $$ = {single: 'lua_len(' + $2.single + ')'}; }
  | "..." { throw new Error('varargs not supported'); }
  ;

tableconstructor
  : "{" "}" { $$ = "lua_newtable()"; }
  | "{" fieldlist fieldsepend "}" {
    if ($2.indexvals.endmulti) {
      if ($2.indexvals.length > 1) {
        $$ = "lua_newtable([" + $2.indexvals.slice(0, -1).join(", ") + "].concat(" + $2.indexvals.endmulti + ")";
      } else {
        $$ = "lua_newtable(" + $2.indexvals.endmulti;
      }
    } else {
      $$ = "lua_newtable([" + $2.indexvals.join(", ") + "]";
    }

    if ($2.keyed) {
      for (var i in $2.keyed) {
        $$ += ", " + $2.keyed[i][0] + ", " + $2.keyed[i][1];
      }
    }
    $$ += ")";
  }
  ;

funcbody
  : "(" ")" chunk END { $$ = {args: [], body: $3} }
  | "(" arglist ")" chunk END { $$ = {args: $2, body: $4} }
  | "(" "..." ")" chunk END { $$ = {args: [], body: $4} }
  | "(" arglist "," "..." ")" chunk END { $$ = {args: $2, body: $6} }
  ;

mfuncbody
  : addself funcbody { $$ = {args: [setLocal("self")].concat($2.args), body: $2.body} }
  ;

addself
  : { setLocal("self", "self") }
  ;

var
  : NAME { $$ = {prefixexp: getLocal($1, "_G.str['" + $1 + "']")}; }
  | prefixexp "[" exp "]" { $$ = {prefixexp: $1.single, access: $3}; }
  | prefixexp "." NAME { $$ = {prefixexp: $1.single, access: "'" + $3 + "'"}; }
  ;

functioncall
  : prefixexp args {
      $$ = "lua_call(" + $1.single + ", [";
      for (var i = 0; i < $2.exps.length; i++) {
        $$ += (i !== 0 ? ", " : "") + $2.exps[i];
      }
      $$ += "])";
    } 
  | prefixexp STRING { $$ = "lua_call(" + $1.single + ", [" + $2 + "])"; }
  | prefixexp tableconstructor { $$ = "lua_call(" + $1.single + ", [" + $2 + "])"; }
  | prefixexp ":" NAME args { $$ = "lua_mcall(" + $1.single + ", '" + $3 + "', [" + $4.exps.join(", ") + "])"; }
  | prefixexp ":" NAME STRING { $$ = "lua_mcall(" + $1.single + ", '" + $3 + "', [" + $4 + "])"; }
  | prefixexp ":" NAME tableconstructor { $$ = "lua_mcall(" + $1.single + ", '" + $3 + "', [" + $4 + "])"; }
  ;

args
  : "(" explist ")" { $$ = $2 }
  | "(" ")" { $$ = {exps: [] } }
  ;

fieldlist
  : fieldlist fieldsep exp { $$ = {keyed: $1.keyed, indexvals: $1.indexvals.concat([$3.single]), endmulti: $3.endmulti}; }
  | fieldlist fieldsep NAME "=" exp { $$ = {keyed: $1.keyed.concat([["'" + $3 + "'", $5.single]]), indexvals: $1.indexvals}; }
  | fieldlist fieldsep "[" exp "]" "=" exp { $$ = {keyed: $1.keyed.concat([[$4.single, $7.single]]), indexvals: $1.indexvals}; }
  | exp { $$ = {keyed: [], indexvals: [$1.single], endmulti: $1.endmulti}; }
  | NAME "=" exp { $$ = {keyed: [["'" + $1 + "'", $3.single]], indexvals: []}; }
  | "[" exp "]" "=" exp { $$ = {keyed: [[$2.single, $5.single]], indexvals: []}; }
  ;

fieldsep
  : ";" { }
  | "," { }
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
