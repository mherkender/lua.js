"""
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
"""

import sys
from itertools import izip_longest
from ply import lex
from ply import yacc

class LuaLexer(object):
  token_data = [
    ("NUMBER", "0x[0-9a-fA-f]+|\d+(\.\d*)?([eE]-?\d+)?"),
    ("STRING", r'\"([^\\\n]|(\\.))*?\"|\'([^\\\n]|(\\.))*?\''),
    ("COLON" , ":"),
    ("SEMICOLON" , ";"),
    ("LPAREN", "\("),
    ("RPAREN", "\)"),
    ("LBRACKET", "\["),
    ("RBRACKET", "\]"),
    ("LBRACE", "\{"),
    ("RBRACE", "\}"),
    ("PERIOD", "\."),
    ("PLUS", "\+"),
    ("MINUS", "-"),
    ("MULTIPLY", "\*"),
    ("DIVIDE", "/"),
    ("MOD", "%"),
    ("POWER", "\^"),
    ("ASSIGN", "="),
    ("EQ", "=="),
    ("NEQ", "~="),
    ("LT", "<"),
    ("LTE", "<="),
    ("GT", ">"),
    ("GTE", ">="),
    ("CONCAT", "\.\."),
    ("LEN", "\#"),
    ("COMMA", ","),
    ("VARARGS", "\.\.\."),
  ]
  
  keywords = {
    "not": "NOT",
    "and": "AND",
    "or": "OR",
    "true": "TRUE",
    "false": "FALSE",
    "nil": "NIL",
    "function": "FUNCTION",
    "until": "UNTIL",
    "do": "DO",
    "end": "END",
    "while": "WHILE",
    "if": "IF",
    "then": "THEN",
    "elseif": "ELSEIF",
    "else": "ELSE",
    "for": "FOR",
    "local": "LOCAL",
    "repeat": "REPEAT",
    "in": "IN",
    "return": "RETURN",
    "break": "BREAK",
  }
  
  t_ignore = " \t"
  
  def t_newline(self, t):
    r'[\n]+'
    t.lexer.lineno += t.value.count("\n")

  def t_SHORTCOMMENT(self, t):
    r'--.*'
    t.value = t.value[2:]
    return t
  
  def t_NAME(self, t):
    "[a-zA-Z_][a-zA-Z0-9_]*"
    t.type = self.keywords.get(t.value, "NAME")
    return t
  
  def t_error(self, t):
      raise Exception("Illegal character %r" % t.value[0])
  
  def __init__(self):
    self.tokens = ("NAME", "SHORTCOMMENT") + \
      tuple(k for k, v in self.token_data) + \
      tuple(self.keywords.itervalues())
    for k, v in self.token_data:
      setattr(self, "t_%s" % k, v)

class LuaYacc(object):
  precedence = (
    ("left", "OR"),
    ("left", "AND"),
    ("left", "LT", "LTE", "GT", "GTE", "EQ", "NEQ"),
    ("right", "CONCAT"),
    ("left", "PLUS", "MINUS"),
    ("left", "MULTIPLY", "DIVIDE", "MOD"),
    ("right", "NOT", "LEN"),
    ("right", "POWER"),
  )
  
  tokens = LuaLexer().tokens
  
  def __init__(self):
    pass

  def p_lua_script(self, t):
    "lua : indentreset indent chunk unindent"
    t[0] = "var lua_script = (function () {\n" \
      "  var _tmp;\n" \
      "  var _G = lua_newtable(null, 'arg', lua_newtable());\n" \
      "  _G.str['_G'] = _G;\n" \
      "  for (var i in lua_core) {if (typeof lua_core[i] == 'object') {_G.str[i] = lua_newtable();for (var j in lua_core[i]) _G.str[i].str[j] = lua_core[i][j];} else _G.str[i] = lua_core[i];}\n" \
      "%s\n" \
      "  return _G;\n" \
      "})();\n" % t[3]

  def p_indent(self, t):
    "indent :"
    self.indent_level += 1
    self.stack.append((self.locals.copy(), self.block_id, self.arguments))
    self.block_id_max += 1
    self.block_id = self.block_id_max
    self.arguments = 0
  def p_unindent(self, t):
    "unindent :"
    self.indent_level -= 1
    self.locals, self.block_id, self.arguments = self.stack.pop()
  def p_indentreset(self, t):
    "indentreset :"
    self.indent_level = 0
    self.block_id = 0
    self.block_id_max = 0
    self.arguments = 0
    self.locals = {}
    self.stack = []
  
  def p_block(self, t):
    "block : indent chunk unindent"
    t[0] = t[2]

  def p_error(self, t):
    raise Exception("Error %r" % t)
  
  def p_semi(self, t):
    """
    semi : SEMICOLON
         |
    """
    t[0] = ";"
  
  def p_chunk_stat(self, t):
    "chunk : statlist"
    t[0] = "\n".join("%s%s" % ("  ", i) 
      for i in (t[1] if t[1] else "").split("\n"))
  def p_chunk_statwithlast(self, t):
    "chunk : statlist laststat"
    t[0] = "\n".join("%s%s" % ("  ", i) 
      for i in ("%s%s" % ("%s\n" % t[1] if t[1] else "", t[2])).split("\n"))
  
  def p_varargchunk(self, t):
    "varargchunk : chunk"
    if self.arguments > 0:
      t[0] = "  var vararg = Array.prototype.slice.apply(arguments, %s);\n%s" % (self.arguments, t[1])
    else:
      t[0] = "  var vararg = Array.prototype.slice.apply(arguments);\n%s" % t[1]

  def p_prefixexp_var(self, t):
    "prefixexp : var"
    prefixexp, access = t[1]
    if access:
      t[0] = "lua_tableget(%s, %s)" % (prefixexp, access), None
    else:
      t[0] = prefixexp, None
  def p_prefixexp_functioncall(self, t):
    "prefixexp : functioncall"
    t[0] = "%s[0]" % t[1], t[1]
  def p_prefixexp_exp(self, t):
    "prefixexp : LPAREN exp RPAREN"
    t[0] = "(%s)" % t[2][0], None
  
  def p_statlist_stat(self, t):
    "statlist : stat semi statlist"
    if t[3]:
      t[0] = "%s\n%s" % (t[1], t[3])
    else:
      t[0] = "%s" % (t[1])
  def p_statlist_empty(self, t):
    "statlist :"
    t[0] = None
  
  def p_stat_shortcomment(self, t):
    "stat : SHORTCOMMENT"
    t[0] = "//%s" % t[1]
  def p_stat_assign(self, t):
    "stat : varlist ASSIGN explist"
    if t[3][1]:
      if t[3][0][:-1]:
        tmpdecl = "_tmp = [%s].concat(%s);" % (", ".join(t[3][0][:-1]), t[3][1])
      else:
        tmpdecl = "_tmp = %s;" % t[3][1]
    else:
      if len(t[3][0]) == 1 and len(t[1]) == 1:
        prefixexp, access = t[1][0]
        if access:
          t[0] = "lua_tableset(%s, %s, %s); " % (prefixexp, access, t[3][0][0])
        else:
          t[0] = "%s = %s; " % (prefixexp, t[3][0][0])
        return
      tmpdecl = "_tmp = [%s];" % ", ".join(t[3][0])
    t[0] = "%s %s_tmp = null;" % (
      tmpdecl,
      "".join(
        "lua_tableset(%s, %s, _tmp[%s]); " % (prefixexp, access, i) if access else "%s = _tmp[%s]; " % (prefixexp, i)
        for i, (prefixexp, access) in enumerate(t[1])))
  def p_stat_assignlocal(self, t):
    "stat : LOCAL namelist ASSIGN explist"
    if t[4][1]:
      if t[4][0][:-1]:
        tmpdecl = "_tmp = [%s].concat(%s);" % (", ".join(t[4][0][:-1]), t[4][1])
      else:
        if len(t[2]) == 1:
          t[0] = "var %s = %s;" % (t[2][0], t[4][0][0])
          return
        tmpdecl = "_tmp = %s;" % t[4][1]
    else:
      if len(t[4][0]) == 1 and len(t[2]) == 1:
        t[0] = "var %s = %s;" % (t[2][0], t[4][0][0])
        return
      tmpdecl = "_tmp = [%s];" % ", ".join(t[4][0])
    t[0] = "%s %s_tmp = null;" % (
      tmpdecl,
      "".join("var %s = _tmp[%s]; " % (v, i) for i, v in enumerate(t[2])))
  def p_stat_assignlocalempty(self, t):
    "stat : LOCAL namelist"
    t[0] = "var %s;" % ", ".join(t[2])
  def p_stat_functioncall(self, t):
    "stat : functioncall"
    t[0] = "%s;" % t[1]
  def p_stat_chunk(self, t):
    "stat : DO block END"
    # blocks are automatically scoped, no need to do it twice
    t[0] = "/** do **/\n%s\n/** end **/" % t[2]
  def p_stat_whileloop(self, t):
    "stat : WHILE exp DO block END"
    t[0] = "while (lua_true(%s)) {\n%s\n}" % (t[2][0], t[4])
  def p_stat_repeat(self, t):
    "stat : REPEAT block UNTIL exp"
    t[0] = "do {\n%s\n} while (lua_true(%s));" % (t[2][0], t[4])
  def p_stat_if(self, t):
    "stat : IF exp THEN block END"
    t[0] = "if (lua_true(%s)) {\n%s\n}" % (t[2][0], t[4])
  def p_stat_ifelse(self, t):
    "stat : IF exp THEN block elseif END"
    t[0] = "if (lua_true(%s)) {\n%s\n} %s" % (t[2][0], t[4], t[5])
  def p_stat_forloop2(self, t):
    "stat : FOR indent forname ASSIGN exp COMMA exp DO block unindent END"
    # these are in for loop's scope (self.block_id + 1)
    i = t[3]
    j = "stop_%s" % (self.block_id + 1)
    t[0] = "var %s = parseFloat2(%s), %s = parseFloat2(%s);\n" \
      "if (isNaN(%s)) throw new Error('Invalid starting value');\n" \
      "if (isNaN(%s)) throw new Error('Invalid end value');\n" \
      "for (; %s <= %s; %s++) {\n%s\n}" % (
        i, t[5][0], j, t[7][0], i, j, i, j, i, t[9])
  def p_stat_forloop3(self, t):
    "stat : FOR indent forname ASSIGN exp COMMA exp COMMA exp DO block unindent END"
    # these are in for loop's scope (self.block_id + 1)
    i = t[3]
    k = "step_%s" % (self.block_id + 1)
    j = "stop_%s" % (self.block_id + 1)
    t[0] = "var %s = parseFloat2(%s), %s = parseFloat2(%s), %s = parseFloat2(%s);\n" \
      "if (isNaN(%s)) throw new Error('Invalid starting value');\n" \
      "if (isNaN(%s)) throw new Error('Invalid end value');\n" \
      "if (isNaN(%s)) throw new Error('Invalid step value');\n" \
      "for (; %s > 0 ? %s <= %s : %s >= %s; %s += %s) {\n%s\n}" % (
        i, t[5][0], j, t[7][0], k, t[9][0], i, j, k, k, i, j, i, j, i, k, t[11])
  def p_stat_forinloop(self, t):
    "stat : FOR indent namelist IN explist DO block unindent END"
    
    # these are in for loop's scope (self.block_id + 1)
    f = "f_%s" % (self.block_id + 1)
    s = "s_%s" % (self.block_id + 1)
    var = "var_%s" % (self.block_id + 1)
    
    if t[5][1]:
      if t[5][0][:-1]:
        tmpdecl = "_tmp = [%s].concat(%s);" % (", ".join(t[5][0][:-1]), t[5][1])
      else:
        tmpdecl = "_tmp = %s;" % t[5][1]
    else:
      tmpdecl = "_tmp = [%s];" % ", ".join(t[5][0])
    vardecl = "%s var %s = _tmp[0]; var %s = _tmp[1]; var %s = _tmp[2]; _tmp = null;" % (
      tmpdecl, f, s, var)
    t[0] = "%s\n" \
      "while (true) {\n" \
      "  _tmp = lua_call(%s, [%s, %s]); %s%s = %s; _tmp = null;\n" \
      "  if (%s == null) break;\n" \
      "%s\n" \
      "}" % (
        vardecl, f, s, var,
        "".join("var %s = _tmp[%s]; " % (v, i) for i, v in enumerate(t[3])),
        var, t[3][0], var, t[7])
  def p_stat_functiondef(self, t):
    "stat : FUNCTION funcname indent funcbody unindent"
    args, body = t[4]
    t[0] = "%s = (function (%s) {\n" \
      "  var _tmp;\n" \
      "%s\n" \
      "  return [];\n});" % (
      "_G%s" % "".join(".str['%s']" % i for i in t[2]),
      ", ".join(args), body)
  def p_stat_mfunctiondef(self, t):
    "stat : FUNCTION funcname COLON NAME indent mfuncbody unindent"
    args, body = t[6]
    t[0] = "_G%s = (function (%s) {\n" \
      "  var _tmp;\n" \
      "%s\n"\
      "  return [];\n});" % (
        "".join(".str['%s']" % i for i in t[2] + [t[4]]),
        ", ".join(args), body)
  def p_stat_localfunctiondef(self, t):
    "stat : LOCAL FUNCTION NAME indent funcbody unindent"
    args, body = t[5]
    self.locals.setdefault(t[3], "_%s_%s" % (t[3], self.block_id))
    t[0] = "var %s = (function (%s) {\n" \
      "  var _tmp;\n" \
      "%s\n"\
      "  return [];\n});" % (
        self.locals[t[3]], ", ".join(args), body)
  
  # we need the variable to be declared before it is used
  def p_forname(self, t):
    "forname : NAME"
    # this is in for loop's scope (self.block_id + 1)
    t[0] = self.locals.setdefault(t[1], "_%s_%s" % (t[1], self.block_id + 1))

  def p_laststat_return(self, t):
    "laststat : RETURN explist"
    if t[2][1]:
      if t[2][0][:-1]:
        t[0] = "return [%s].concat(%s);" % (", ".join(t[2][0][:-1]), t[2][1])
      else:
        t[0] = "return %s;" % t[2][1]
    else:
      t[0] = "return [%s];" % ", ".join(t[2][0])
  def p_laststat_returnonly(self, t):
    "laststat : RETURN"
    t[0] = "return [];"
  def p_laststat_break(self, t):
    "laststat : BREAK"
    t[0] = "break;"
  
  def p_elseif_if(self, t):
    "elseif : ELSEIF exp THEN block"
    t[0] = "else if (lua_true(%s)) {\n%s\n}" % (t[2][0], t[4])
  def p_elseif_ifmore(self, t):
    "elseif : ELSEIF exp THEN block elseif"
    t[0] = "else if (lua_true(%s)) {\n%s\n} %s" % (t[2][0], t[4], t[5])
  def p_elseif_end(self, t):
    "elseif : ELSE block"
    t[0] = "else {\n%s\n}" % t[2]

  def p_varlist_var(self, t):
    "varlist : var COMMA varlist"
    t[0] = [t[1]] + t[3]
  def p_varlist_lastvar(self, t):
    "varlist : var"
    t[0] = [t[1]]

  def p_explist_more(self, t):
    "explist : exp COMMA explist"
    t[0] = [t[1][0]] + t[3][0], t[3][1]
  def p_explist_last(self, t):
    "explist : exp"
    t[0] = [t[1][0]], t[1][1]

  def p_namelist_more(self, t):
    "namelist : NAME COMMA namelist"
    t[0] = [self.locals.setdefault(t[1], "_%s_%s" % (t[1], self.block_id))] + t[3]
  def p_namelist_last(self, t):
    "namelist : NAME"
    t[0] = [self.locals.setdefault(t[1], "_%s_%s" % (t[1], self.block_id))]

  def p_arglist(self, t):
    "arglist : namelist"
    for i in t[1]:
      self.locals[i] = i
    t[0] = t[1]

  def p_funcname_more(self, t):
    "funcname : NAME PERIOD funcname"
    t[0] = [t[1]] + t[3]
  def p_funcname_last(self, t):
    "funcname : NAME"
    t[0] = [t[1]]

  def p_exp_simple(self, t):
    """
    exp : NUMBER
        | STRING
        | TRUE
        | FALSE
        | tableconstructor
    """
    t[0] = t[1], None
  def p_exp_nil(self, t):
    "exp : NIL"
    t[0] = "null", None
  def p_exp_prefixexp(self, t):
    "exp : prefixexp"
    t[0] = t[1]
  def p_exp_anonfunction(self, t):
    "exp : FUNCTION indent funcbody unindent"
    args, body = t[3]
    t[0] = "(function (%s) {\n" \
      "  var _tmp;\n" \
      "%s\n" \
      "  return [];\n" \
      "})" % (", ".join(args), body), None
  def p_exp_add(self, t):
    "exp : exp PLUS exp"
    t[0] = "lua_add(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_subtract(self, t):
    "exp : exp MINUS exp"
    t[0] = "lua_subtract(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_multiply(self, t):
    "exp : exp MULTIPLY exp"
    t[0] = "lua_multiply(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_divide(self, t):
    "exp : exp DIVIDE exp"
    t[0] = "lua_divide(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_power(self, t):
    "exp : exp POWER exp"
    t[0] = "lua_power(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_mod(self, t):
    "exp : exp MOD exp"
    t[0] = "lua_mod(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_concat(self, t):
    "exp : exp CONCAT exp"
    t[0] = "lua_concat(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_lt(self, t):
    "exp : exp LT exp"
    t[0] = "lua_lt(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_gt(self, t):
    "exp : exp GT exp"
    t[0] = "lua_lt(%s, %s)" % (t[3][0], t[1][0]), None
  def p_exp_lte(self, t):
    "exp : exp LTE exp"
    t[0] = "lua_lte(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_gte(self, t):
    "exp : exp GTE exp"
    t[0] = "lua_lte(%s, %s)" % (t[3][0], t[1][0]), None
  def p_exp_eq(self, t):
    "exp : exp EQ exp"
    t[0] = "lua_eq(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_neq(self, t):
    "exp : exp NEQ exp"
    t[0] = "!lua_eq(%s, %s)" % (t[1][0], t[3][0]), None
  def p_exp_and(self, t):
    "exp : exp AND exp"
    t[0] = "lua_and(%s, function () {return %s;})" % (t[1][0], t[3][0]), None
  def p_exp_or(self, t):
    "exp : exp OR exp"
    t[0] = "lua_or(%s, function () {return %s;})" % (t[1][0], t[3][0]), None
  def p_exp_neg(self, t):
    "exp : MINUS exp"
    t[0] = "lua_unm(%s)" % t[2][0], None
  def p_exp_not(self, t):
    "exp : NOT exp"
    t[0] = "lua_not(%s)" % t[2][0], None
  def p_exp_len(self, t):
    "exp : LEN exp"
    t[0] = "lua_len(%s)" % t[2][0], None
  def p_exp_varargs(self, t):
    "exp : VARARGS"
    raise Exception("varargs not yet supported")

  def p_tableconstructor_empty(self, t):
    "tableconstructor : LBRACE RBRACE"
    t[0] = "lua_newtable()"
  def p_tableconstructor_args(self, t):
    "tableconstructor : LBRACE fieldlist fieldsepend RBRACE"
    keyed, indexvals, concat_arg = t[2]

    if concat_arg:
      if indexvals[:-1]:
        indexvals_arg = "[%s].concat(%s)" % (", ".join(indexvals[:-1]), concat_arg)
      else:
        indexvals_arg = "%s" % concat_arg
    else:
      indexvals_arg = "[%s]" % ", ".join(indexvals) if indexvals else "null"

    if keyed:
      t[0] = "lua_newtable(%s, %s)" % (
        indexvals_arg,
        ", ".join("%s, %s" % (k, v) for k, v in keyed))
    else:
      t[0] = "lua_newtable(%s)" % indexvals_arg
  
  def p_funcbody_noargs(self, t):
    "funcbody : LPAREN RPAREN chunk END"
    t[0] = [], t[3]
  def p_funcbody_namelist(self, t):
    "funcbody : LPAREN arglist RPAREN chunk END"
    t[0] = t[2], t[4]
  def p_funcbody_varargs(self, t):
    "funcbody : LPAREN VARARGS RPAREN varargchunk END"
    t[0] = [], t[4]
  def p_funcbody_bothargs(self, t):
    "funcbody : LPAREN arglist COMMA VARARGS RPAREN varargchunk END"
    t[0] = t[2], t[6]
 
  def p_mfuncbody(self, t):
    "mfuncbody : addself funcbody"
    t[0] = ["self"] + t[2][0], t[2][1]
  
  def p_addself(self, t):
    "addself :"
    self.locals["self"] = "self"

  def p_var_simple(self, t):
    "var : NAME"
    t[0] = self.locals.get(t[1], "_G.str['%s']" % t[1]), None
  def p_var_simplewithsuffix(self, t):
    "var : prefixexp LBRACKET exp RBRACKET"
    t[0] = t[1][0], t[3][0]
  def p_var_descendent(self, t):
    "var : prefixexp PERIOD NAME"
    t[0] = t[1][0], "'%s'" % t[3]
  
  def p_functioncall_args(self, t):
    "functioncall : prefixexp args"
    t[0] = "lua_call(%s, [%s])" % (t[1][0], ", ".join(t[2][0]))
  def p_functioncall_string(self, t):
    "functioncall : prefixexp STRING"
    t[0] = "lua_call(%s, [%s])" % (t[1][0], t[2])
  def p_functioncall_tableconstructor(self, t):
    "functioncall : prefixexp tableconstructor"
    t[0] = "lua_call(%s, [%s])" % (t[1][0], t[2])
  def p_functioncall_margs(self, t):
    "functioncall : prefixexp COLON NAME args"
    if t[4][0]:
      t[0] = "lua_mcall(%s, '%s', [%s])" % (t[1][0], t[3], ", ".join(t[4][0]))
    else:
      t[0] = "lua_mcall(%s, '%s', [])" % (t[1][0], t[3])
  def p_functioncall_mstring(self, t):
    "functioncall : prefixexp COLON NAME STRING"
    t[0] = "lua_mcall(%s, '%s', [%s])" % (t[1][0], t[3], t[4])
  def p_functioncall_mtableconstructor(self, t):
    "functioncall : prefixexp COLON NAME tableconstructor"
    t[0] = "lua_mcall(%s, '%s', [%s])" % (t[1][0], t[3], t[4])

  def p_args_explist(self, t):
    "args : LPAREN explist RPAREN"
    t[0] = t[2]
  def p_args_emptyexplist(self, t):
    "args : LPAREN RPAREN"
    t[0] = [], None
  
  def p_fieldlist_array(self, t):
    "fieldlist : fieldlist fieldsep exp"
    prev_keyed, prev_indexvals, concat_arg = t[1]
    t[0] = prev_keyed, prev_indexvals + [t[3][0]], t[3][1]
  def p_fieldlist_dict(self, t):
    "fieldlist : fieldlist fieldsep NAME ASSIGN exp"
    prev_keyed, prev_indexvals, concat_arg = t[1]
    t[0] = prev_keyed + [("'%s'" % t[3], t[5][0])], prev_indexvals, None
  def p_fieldlist_expdict(self, t):
    "fieldlist : fieldlist fieldsep LBRACKET exp RBRACKET ASSIGN exp"
    prev_keyed, prev_indexvals, concat_arg = t[1]
    t[0] = prev_keyed + [(t[4][0], t[7][0])], prev_indexvals, None
  def p_fieldlist_arraybegin(self, t):
    "fieldlist : exp"
    t[0] = [], [t[1][0]], t[1][1]
  def p_fieldlist_dictbegin(self, t):
    "fieldlist : NAME ASSIGN exp"
    t[0] = [("'%s'" % t[1], t[3][0])], [], None
  def p_fieldlist_expdictbegin(self, t):
    "fieldlist : LBRACKET exp RBRACKET ASSIGN exp"
    t[0] = [(t[2][0], t[5][0])], [], None
  
  def p_fieldsep(self, t):
    """
    fieldsep : SEMICOLON
             | COMMA
    """
    pass
  def p_fieldsepend(self, t):
    """
    fieldsepend : SEMICOLON
                | COMMA
                |
    """
    pass


lex.lex(object=LuaLexer()) # build lexer

#import logging
#logging.basicConfig(
#    level = logging.DEBUG,
#    format = "%(filename)10s:%(lineno)4d:%(message)s"
#)
#yacc.yacc(module=LuaYacc(), debug=1, write_tables=0) # generate parser
#yacc.yacc(module=LuaYacc(), debug=1, write_tables=0, debuglog=logging.getLogger()) # generate parser

yacc.yacc(module=LuaYacc(), write_tables=0, debug=0)
sys.stdout.write(yacc.parse(sys.stdin.read()))
