// Copyright(C) 2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module parser

import os
// import strings
import math
import regex
import toml
import toml.ast as tast
import strconv
// For running vfmt programatically
import v.ast
import v.fmt
import v.parser as vparser
import v.pref

const (
	// regex_params_in_comment = regex.regex_opt(r'\\param\s+([\w\-\(\)]+)(\s|\.|,|$)') or { panic(err) }
	// regex_c_in_comment = regex.regex_opt(r'\\c|a\s+([\w\->\(\)]+)(\s|\.|,|$)') or { panic(err) }
	// regex_cs_triple_in_comment = regex.regex_opt(r'//\s+(```)') or { panic(err) }
	regex_block_comment = regex.regex_opt(r'§(.*)¾') or { panic(err) }
		// regex_word = regex.regex_opt(r'\w+') or { panic(err) }
)

const (
	c_to_v_type_map = {
		'bool':                   'bool'
		//
		'char':                   'char'
		'signed char':            'i8'
		'unsigned char':          'u8'
		//
		'short':                  'i16'
		'short int':              'i16'
		'signed short':           'i16'
		'signed short int':       'i16'
		//
		'unsigned short':         'u16'
		'unsigned short int':     'u16'
		//'wchar_t':                'u16'
		//
		'int':                    'int'
		'signed':                 'int'
		'signed int':             'int'
		'unsigned':               'u32'
		'unsigned int':           'u32'
		'long':                   'int'
		'long int':               'int'
		'signed long':            'int'
		'signed long int':        'int'
		//
		'unsigned long':          'u32'
		'unsigned long int':      'u32'
		//
		'long long':              'i64'
		'long long int':          'i64'
		'signed long long':       'i64'
		'signed long long int':   'i64'
		//
		'unsigned long long':     'u64'
		'unsigned long long int': 'u64'
		//
		'float':                  'f32'
		'double':                 'f64'
		'long double':            'f64'
		//
		'size_t':                 'usize'
		// stdint.h
		'int8_t':                 'i8'
		'uint8_t':                'u8'
		'uint16_t':               'u16'
		'int16_t':                'i16'
		'int32_t':                'int'
		'uint32_t':               'u32'
		'int64_t':                'i64'
		'uint64_t':               'u64'
	}

	// NOTE the mapped values aren't used currently, "@" is just prepended automatically.
	keywords = {
		'assert':     '@assert'
		'struct':     '@struct'
		'if':         '@if'
		'it':         'ti'
		'else':       '@else'
		'asm':        '@asm'
		'return':     '@return'
		'module':     '@module'
		'sizeof':     '@sizeof'
		'isreftype':  'isreftyp'
		'_likely_':   'likly'
		'_unlikely_': 'unlikly'
		'go':         '@go'
		'goto':       '@goto'
		'const':      '@const'
		'mut':        'mute'
		'shared':     '@shared'
		'lock':       '@lock'
		'rlock':      '@rlock'
		'type':       '@type'
		'for':        'fro'
		'fn':         'func'
		'true':       'yes'
		'false':      'nope'
		'continue':   'keepgoing'
		'break':      'smash'
		'import':     'imported'
		'unsafe':     'not_safe'
		'typeof':     'kind'
		'dump':       'dmp'
		'enum':       'num'
		'interface':  'iface'
		'pub':        'publ'
		'in':         'i_n'
		'atomic':     'atmic'
		'or':         'orr'
		'__global':   'glbl'
		'union':      'onion'
		'static':     'sttc'
		'volatile':   'vola'
		'as':         'aas'
		'defer':      'defr'
		'match':      'mtch'
		'select':     'slct'
		'none':       'non'
		'__offsetof': 'offsof'
		'is':         'iss'
	}

	empty_toml_doc = toml.Doc{
		ast: &tast.Root(unsafe { nil })
	}
)

pub struct Config {
	toml_doc toml.Doc = parser.empty_toml_doc
pub:
	lib_name string

	api_export string
	api_inline string

	imports []string

	skip_typedefs []string
	skip_keywords []string
	skip_files    []string

	struct_id_prefix string
	enum_id_prefix   string
	fn_id_prefix     string
	define_id_prefix string

	fields_structs map[string][]string

	primitives_map map[string]string

	rewrite map[string]map[string]map[string]string
	inject  map[string]string

	v_fmt bool
}

fn (c Config) get_raw(query string, default toml.Any) toml.Any {
	$if debug ? {
		eprintln('${@MOD}.${@FN}({query},...)')
	}
	return c.toml_doc.value(query).default_to(default)
}

fn (c Config) get_map(query string) map[string]string {
	$if debug ? {
		eprintln('${@MOD}.${@FN}({query},...)')
	}
	dm := map[string]toml.Any{}
	m := c.get_raw(query, dm) as map[string]toml.Any
	return m.as_strings()
}

fn (c Config) get_map_of_array(query string) map[string][]string {
	$if debug ? {
		eprintln('${@MOD}.${@FN}({query},...)')
	}
	dma := map[string]toml.Any{}
	m := c.get_raw(query, dma) as map[string]toml.Any
	mut map_of_array := map[string][]string{}
	for k, v in m {
		cast_v := v as []toml.Any
		arr := cast_v.as_strings()
		map_of_array[k] = arr
	}
	return map_of_array
}

fn (c Config) get_array(query string) []string {
	$if debug ? {
		eprintln('${@MOD}.${@FN}({query},...)')
	}
	a := c.get_raw(query, []toml.Any{}) as []toml.Any
	return a.as_strings()
}

fn (c Config) get_string(query string) string {
	$if debug ? {
		eprintln('${@MOD}.${@FN}({query},...)')
	}
	return c.get_raw(query, '').string()
}

pub fn config_from_toml(file string) Config {
	mut toml_doc := parser.empty_toml_doc
	if os.is_file(file) {
		eprintln('Using ${file}')
		toml_doc = toml.parse_file(file) or { parser.empty_toml_doc }
	}
	assert !isnil(toml_doc.ast)
	// return toml.parse_text('') or { empty_toml_doc }
	// toml_doc.value('wrong.key').default_to(123).int()
	mut conf := Config{
		toml_doc: toml_doc
	}

	mut rewrite := {
		'value': {
			'const': map[string]string{}
		}
	}
	rewrite['value']['const'] = conf.get_map('rewrite.value.const')
	return Config{
		toml_doc: toml_doc
		lib_name: conf.get_string('lib_name')
		api_export: conf.get_string('api.export')
		api_inline: conf.get_string('api.inline')
		imports: conf.get_array('imports')
		skip_typedefs: conf.get_array('skip.typedefs')
		skip_keywords: conf.get_array('skip.keywords')
		skip_files: conf.get_array('skip.files')
		struct_id_prefix: conf.get_string('prefix.struct')
		enum_id_prefix: conf.get_string('prefix.enum')
		fn_id_prefix: conf.get_string('prefix.function')
		define_id_prefix: conf.get_string('prefix.define')
		fields_structs: conf.get_map_of_array('fields.structs')
		primitives_map: conf.get_map('primitives')
		rewrite: rewrite
		inject: conf.get_map('inject')
	}
}

pub fn vfmt(v_code string) string {
	fpref := pref.Preferences{
		is_fmt: true
		fatal_errors: false
	}
	table := ast.new_table()
	file_ast := vparser.parse_text(v_code, 'memory/1.v', table, .parse_comments, &fpref)
	fmtd_v_code := fmt.fmt(file_ast, table, &fpref, false)
	unsafe { free(table) }
	return fmtd_v_code
}

type Node = CDefine | CEnum | CFnCallbackSig | CFnSig | CStruct

pub struct Parser {
pub:
	conf Config
pub mut:
	files []CFile

	aliases      map[string]CAlias
	defines      map[string]CDefine
	enums        map[string]CEnum
	structs      map[string]CStruct
	fn_callbacks []CFnCallbackSig
}

pub fn (mut p Parser) parse_file(path string) {
	if os.file_name(path) in p.conf.skip_files {
		eprintln('Skipping ${path}')
		return
	}
	c_code := os.read_file(path) or { panic(err) }

	// eprintln('Parsing $path')
	mut f := CFile{
		raw: c_code
		path: path
	}

	p.parse(mut f)
}

pub fn (mut p Parser) file_to_v_code(f CFile) !string {
	filename := os.file_name(f.path)

	lib_name := p.conf.lib_name
	mut v_code := '// NOTE this file is auto-generated by chew
module ${lib_name}

import ${lib_name}.c
'

	for inport in p.conf.imports {
		v_code += 'import ${inport}\n'
	}

	v_code += '
pub const used_import = c.used_import

//
// ${filename}
'
	$if debug {
		v_code += '// (${f.path})
'
	}
	v_code += '//

'
	if p.aliases.len > 0 {
		v_code += '// C typedef aliases used\n'
		for _, alias in p.aliases {
			if alias.name != alias.alias {
				mut v_alias := p.c_to_v_type_name(alias.name)
				v_code += '// ${alias.alias} -> ${alias.name} -> ${v_alias}\n'
			}
		}
		v_code += '\n'
	}

	header_offset := v_code.count('\n')
	for node in f.nodes {
		match node {
			CDefine {
				code := p.gen_v_const(node) or { 'TODO ' + err.msg() + ': ' + node.raw }
				if code.starts_with('TODO') {
					v_code += '/' + '*\n' + code + '\n*' + '/\n\n'
				} else {
					v_code += code + '\n\n'
				}
			}
			CFnSig {
				if node.raw.contains('...') {
					v_code += '// Skipped:\n/' + '*\n${node.raw}\n*' + '/' + '\n\n'
					continue
				}

				// if node.raw.contains('[]') {
				//	v_code += '// TODO\n/' + '*\n$node.raw\n*' + '/' + '\n\n'
				//	continue
				//}
				wrapper_code, fn_name := p.gen_v_wrapper(node)

				v_code += '// C: `${node.raw.replace('  ', '').trim_right(';')}`\n'
				v_code += p.gen_vc_fn_sig(node) + '\n\n'

				mut comment_code := c_to_v_comment(node.comment, fn_name)

				if comment_code == '' {
					comment_code = '// ${fn_name} is currently undocumented\n'
				}

				v_code += comment_code
				v_code += wrapper_code + '\n\n'
			}
			CFnCallbackSig {
				v_code += p.gen_v_fn_callback_def(node) + '\n\n'
			}
			CStruct {
				if node.is_typedef {
					v_code += p.gen_v_struct_def(node)! + '\n\n'
				}
			}
			CEnum {
				v_code += p.gen_v_enum_def(node) + '\n\n'
			}
		}
	}

	// Post-process
	mut lines := v_code.split('\n')
	for i, mut line in lines {
		ln := i - header_offset
		if inject := p.conf.inject['${ln}'] {
			// eprintln('injecting "$inject"')
			line = inject + '\n' + line + '\n'
		}
	}
	v_code = lines.join('\n')

	return v_code
}

fn (mut p Parser) parse(mut cf CFile) {
	// mut peek_line := ''
	mut in_comment := false
	mut comment := ''
	mut comment_count := 0

	lines := cf.raw.split('\n')
	mut skip := 0
	for i, imline in lines {
		mut line := imline

		stop_marker := p.conf.get_string('stop-marker.line_starts_with')
		if stop_marker != '' && line.starts_with(stop_marker) {
			println('Stopping parsing at line ${i}')
			break
		}

		if skip > 0 {
			skip--
			continue
		}

		// if i > 1 {
		//	prev_line = lines[i - 1]
		//}
		// if i + 1 < lines.len {
		//	peek_line = lines[i + 1]
		//}
		if line.trim_space().starts_with('/*') && line.trim_space().ends_with('*/') {
			comment += line.all_after('/*').all_before_last('*/') + '\n'
			comment_count++
			continue
		}
		if line.contains('/*') && line.trim_space().contains('*/') {
			comment += line.all_after('/*').all_before_last('*/') + '\n'
			comment_count++
			line = line.all_before('/*')
		}
		if line.trim_space().contains('/*') && line.contains('*/') {
			comment += line.all_after('/*').all_before_last('*/') + '\n'
			comment_count++
			line = line.all_after_last('*/')
		}
		if line.starts_with('*/') || (!line.trim_space().starts_with('//') && (line.ends_with('*/')
			&& !line.contains('/' + '*'))) {
			comment += line.all_before('*/') + '\n'
			if !in_comment {
				panic('Uneven block comment:\n${comment}')
			}
			in_comment = !in_comment

			continue
		}
		if in_comment {
			comment += line + '\n'
			continue
		}
		if line.trim_space().starts_with('/*') || line.ends_with('/*') {
			if line.starts_with('/*') {
				// If it starts clean just delete what we've gathered so far
				comment = ''
			}
			comment += line.all_after('/*') + '\n'
			comment_count++
			in_comment = !in_comment
			continue
		}
		if line.starts_with('// ') {
			comment += line + '\n'
			comment_count++
			continue
		}

		if comment_count == 2 {
			// TODO Miniaudio doc header(s)
			/*
			os.write_file(os.real_path(os.join_path(os.dir(path), 'README.${lib_name}.auto.md')), comment) or {
				panic(err)
			}*/
			comment = ''
		}

		if line == '' {
			comment = ''
			continue
		}

		if line.to_lower().starts_with('#define ') {
			mut def := p.parse_define([line])
			if _ := def.valid() {
				def.comment = comment
				comment = ''
				p.defines[def.name] = def
			}
			cf.nodes << def
			continue
		}

		if line.starts_with('typedef enum') {
			if line.contains(';') {
				mut td_enums := p.parse_typedef_enum([line])
				if td_enums.len > 0 {
					td_enums[0].comment = comment
					comment = ''
				}
				// p.enums << td_enums

				for enu in td_enums {
					p.enums[enu.name] = enu
					cf.nodes << enu
				}

				continue
			}

			typedefa := eat_lines_until(i, lines, fn (l string) bool {
				return l.starts_with('}') && l.contains(';')
			})
			skip = typedefa.len - 1

			mut td_enums := p.parse_typedef_enum(typedefa)
			if td_enums.len > 0 {
				td_enums[0].comment = comment
				comment = ''
			}

			// p.enums << td_enums

			for enu in td_enums {
				p.enums[enu.name] = enu
				cf.nodes << enu
			}
		}

		if line.starts_with('typedef struct') || line.starts_with('typedef union') {
			if line.contains(';') {
				if !line.contains('{') {
					mut alias := parse_typedef_alias(line) or {
						eprintln(err)
						continue
					}
					alias.comment = comment
					comment = ''
					p.aliases[alias.alias] = alias
					// cf.nodes << alias
					continue
				}

				mut stts := p.parse_struct([line]) or {
					eprintln(err)
					continue
				}

				if stts.len > 0 {
					stts[0].comment = comment
					comment = ''
				}
				// p.structs << stts

				for stt in stts {
					p.structs[stt.name] = stt
					cf.nodes << stt
				}

				continue
			}

			typedefa := eat_lines_until(i, lines, fn (l string) bool {
				return l.starts_with('}') && l.contains(';')
			})
			skip = typedefa.len - 1

			mut stts := p.parse_struct(typedefa) or {
				eprintln(err)
				continue
			}

			if stts.len > 0 {
				stts[0].comment = comment
				comment = ''
			}
			// p.structs << stts

			for stt in stts {
				p.structs[stt.name] = stt
				cf.nodes << stt
			}
		}

		if line.starts_with('typedef ') && line.replace(' ', '').contains(')(') {
			if line.contains(';') {
				mut fnts := parse_typedef_fn_callback([line])
				fnts.comment = comment
				comment = ''
				p.fn_callbacks << fnts

				// v_code += gen_v_fn_callback_def(fnts) + '\n\n'
				cf.nodes << fnts
				continue
			}
		}

		if line.starts_with('typedef ') && line.contains(';') {
			mut alias := parse_typedef_alias(line) or {
				eprintln(err)
				continue
			}
			alias.comment = comment
			comment = ''
			p.aliases[alias.alias] = alias
			// cf.nodes << alias
			continue
		}
		// continue

		if line.starts_with('struct') {
			if line.contains(';') {
				mut stts := p.parse_struct([line]) or {
					eprintln(err)
					continue
				}

				if stts.len > 0 {
					stts[0].comment = comment
					comment = ''
				}
				// p.structs << stts

				for stt in stts {
					p.structs[stt.name] = stt
					cf.nodes << stt
				}

				continue
			}

			typedefa := eat_lines_until(i, lines, fn (l string) bool {
				return l.starts_with('}') && l.contains(';')
			})
			skip = typedefa.len - 1

			mut stts := p.parse_struct(typedefa) or {
				eprintln(err)
				continue
			}

			if stts.len > 0 {
				stts[0].comment = comment
				comment = ''
			}
			// p.structs << stts

			for stt in stts {
				p.structs[stt.name] = stt
				cf.nodes << stt
			}
		}

		if line.starts_with(p.conf.api_export) { //|| line.starts_with('extern DECLSPEC ') { // 'SOKOL_GP_API_DECL'
			api_export := eat_lines_until(i, lines, fn (l string) bool {
				return l.contains(';')
			})

			skip = api_export.len - 1

			if !api_export.any(it.contains(';')) {
				continue
			}

			mut fnc := p.parse_fn_def(api_export)
			fnc.comment = comment
			comment = ''
			cf.nodes << fnc
			// v_code += export_api(api_export, comment) + '\n\n'
		}
	}

	p.files << cf
	// return v_code + '\n'
}

struct CFile {
pub:
	path string
mut:
	raw   string
	nodes []Node
}

struct CDefine {
	raw    string
	name   string
	prefix string // 'ma_'
	value  string
mut:
	comment string
}

struct CArg {
	full     string
	kind     string
	name     string
	is_const bool
}

struct CFnSig {
mut:
	raw         string
	return_type string
	name        string
	args        []CArg
	// mut:
	comment string
}

struct CFnCallbackSig {
	raw         string
	return_type string
	name        string
	args        []CArg
mut:
	comment string
}

struct CField {
	raw             string
	kind            string
	name            string
	comment         string
	comment_above   string
	embedded_struct CStruct
	//	is_const bool
}

enum CAliasType {
	primitive
	_struct
}

struct CAlias {
	raw   string
	name  string
	alias string
	typ   CAliasType = .primitive
mut:
	comment string
}

struct CStruct {
	raw        string
	name       string
	prefix     string // 'ma_'
	is_typedef bool
	is_union   bool
	fields     []CField
mut:
	comment string
}

fn (cs CStruct) v_name() !string {
	mut name := c_to_v_struct_name(cs.name, cs.prefix)
	name = rewrite_known_v_pitfall_name(name, cs.prefix)
	return name
}

struct CEnum {
	raw        string
	name       string
	prefix     string // 'ma_'
	is_typedef bool
	fields     []CEnumField
mut:
	comment string
}

struct CEnumField {
	raw               string
	value             string
	name              string
	comment           string
	comment_was_above bool
}

fn eat_lines_until(from int, lines []string, marked fn (line string) bool) []string {
	mut gulp := []string{}
	for i := from; i < lines.len; i++ {
		line := lines[i]
		gulp << line
		if marked(line) {
			return gulp
		}
	}
	return gulp
}

fn find_backwards_until(from int, lines []string, marked fn (line string) bool) int {
	for i := from; i >= 0; i-- {
		line := lines[i]
		if marked(line) {
			return i
		}
	}
	return 0
}

fn c_to_v_struct_name(sn string, prefix string) string {
	sanitized := sn.replace(prefix, '')
	if !sanitized.contains('_') {
		return sanitized.title()
	}
	mut ids := sanitized.split('_')
	for mut id in ids {
		id = id.title()
	}
	return ids.join('')
}

fn (p Parser) parse_typedef_enum(lines []string) []CEnum {
	// eprintln('Parsing enum: $lines')

	raw := lines.join('\n').trim_space()

	flat := lines.join(' ').replace('\n', '')
	raw_enum_ids := flat.all_after_last('}').trim(' ').all_before_last(';').replace(' ',
		'').split(',')

	tmp_nl_char := '¤-¤-¤-¤'
	mut flat_reblow := lines.join(tmp_nl_char)
	flat_reblow = flat_reblow.replace('*//*', '*/  /*').replace('/*', '§').replace('*/',
		'¾')

	flat_reblow = flat_reblow.all_after('{').all_before_last('}').trim(' ')

	mut re := parser.regex_block_comment
	// type FnReplace = fn (re RE, in_txt string, start int, end int) string
	// .replace_by_fn(in_txt string, repl_fn FnReplace)
	mut flat_blocks := re.replace_by_fn(flat_reblow, fn (re regex.RE, in_txt string, start int, end int) string {
		res := re.get_group_by_id(in_txt, 0).replace('¤-¤-¤-¤', '½').replace('   ',
			' ').replace('  ', '').replace('  ', ' ').trim(' ')
		// eprintln('comment block: $res')
		return '// ${res}'
	})

	mut new_lines := flat_blocks.split(tmp_nl_char)

	//@ eprintln('\nC enum lines: ${new_lines.join("\n")}')

	mut fields := []CEnumField{}
	mut last_comment := ''
	mut prev_comment := ''
	mut skip := 0
	for line in new_lines {
		if skip > 0 {
			skip--
			continue
		}

		line_no_comment := line.all_before('//') // .all_before('¾').all_before('§').trim(' ')
		mut comment := ''
		if line.contains('//') {
			comment = line.all_after('//').trim(' ')
		} else if line.contains('§') {
			comment = line.all_after('§').all_before('¾').trim(' ')
		}
		comment = comment.replace('½', '\n')
		if comment != '' {
			last_comment = comment
		}
		mut used_comment := comment

		if line_no_comment == '' {
			continue
		}
		//@ eprintln('C enum line: $line_no_comment (COMMENT: "$comment")')

		mut l_split := line_no_comment.all_before(',').split('=')
		l_split = l_split.map(it.trim(' '))
		l_split = l_split.filter(it != '')

		if l_split.len >= 1 {
			mut name := l_split[0]

			mut val := ''

			//&& l_split[1] == '='
			if l_split.len > 1 {
				val = l_split[1].replace(',', '')
			}

			if _ := parser.keywords[name] {
				name = '@' + name // rewrite
			}
			name = name.trim(' ')

			mut comment_was_above := false
			if comment == '' && last_comment != '' && prev_comment != last_comment {
				used_comment = last_comment
				prev_comment = ''
				last_comment = ''
				comment_was_above = true
			}
			if used_comment == comment {
				last_comment = ''
				comment = ''
			}

			// TODO skip names that are numbers solely
			if name.contains_any(',()#/') {
				eprintln('Skipping enum field `${name}`')
				continue
			}

			fields << CEnumField{
				raw: line_no_comment
				name: name
				value: val.trim(' ')
				comment: used_comment
				comment_was_above: comment_was_above
			}
		}

		prev_comment = comment
		if used_comment == prev_comment {
			prev_comment = ''
		}
	}

	mut c_enums := []CEnum{}
	// eprintln(members)
	for enum_id in raw_enum_ids {
		c_enums << CEnum{
			raw: raw
			name: enum_id
			prefix: p.conf.enum_id_prefix
			is_typedef: true
			fields: fields
		}
	}

	return c_enums
}

fn (ce CEnum) v_name() ?string {
	// e.valid() ?
	mut enum_name_no_prefix := ce.name.replace(ce.prefix, '')
	mut enum_name := enum_name_no_prefix
	if enum_name.contains('_') {
		mut nsp := enum_name.split('_')
		nsp = nsp.map(it.title())
		enum_name = nsp.join('')
	} else {
		enum_name = enum_name.title()
	}

	enum_name = rewrite_known_v_pitfall_name(enum_name, ce.prefix)
	return enum_name
}

fn rewrite_known_v_pitfall_name(name string, prefix string) string {
	if name == 'Error' {
		return prefix.to_upper().trim('_') + name
	}
	return name
}

fn (p Parser) gen_v_enum_def(ce CEnum) string {
	mut v_code := ''

	/*
	v_code += '/' + '*'
	v_code += ce.raw + '\n'
	// v_code += '$ce\n'
	v_code += '*' + '/\n'
	*/

	mut enum_name_no_prefix := ce.name.replace(ce.prefix, '')
	mut enum_name := ce.v_name() or { enum_name_no_prefix }

	v_code += '// ${enum_name} is C.${ce.name}\n'
	v_code += 'pub enum ${enum_name} {\n'

	mut names := map[string]string{}
	mut common_name_prefix := ''
	mut ic := 0
	for field in ce.fields {
		// v_code += ''
		mut name := field.name

		if name.starts_with(ce.name.to_lower()) {
			name = name.all_after(ce.name.to_lower())
		}

		name = name.to_lower()
		name = name.all_after(ce.prefix)
		if name.starts_with(enum_name_no_prefix.to_lower()) {
			name = name.all_after(enum_name_no_prefix.to_lower())
		}
		if name.starts_with('_') {
			name = name.all_after('_')
		}
		if name[0].is_digit() {
			name = '_' + name
		}

		names[field.name] = name

		// Find common prefix
		if ic == 0 {
			common_name_prefix = name
		}

		mut res := []string{}
		cnps := common_name_prefix.split('_')
		ns := name.split('_')
		min := math.min(cnps.len, ns.len)
		for i := 0; i < min; i++ {
			if cnps[i] == ns[i] {
				res << cnps[i]
			}
		}
		common_name_prefix = res.join('_')

		ic++
	}

	for field in ce.fields {
		// v_code += ''
		mut name := names[field.name]

		name = name.replace(common_name_prefix, '')
		if name == '' {
			name = field.name
		}

		// TODO same as above, make a function
		if name.starts_with(ce.name.to_lower()) {
			name = name.all_after(ce.name.to_lower())
		}

		name = name.to_lower()
		name = name.all_after(ce.prefix)
		if name.starts_with(enum_name_no_prefix.to_lower()) {
			name = name.all_after(enum_name_no_prefix.to_lower())
		}
		if name.starts_with('_') {
			name = name.all_after('_')
		}
		if name[0].is_digit() {
			name = '_' + name
		}
		// TODO end

		if _ := parser.keywords[name] {
			name = '@' + name
		}

		mut comment := field.comment //.replace('*<', '`$name`')

		mut val := 'C.' + field.name

		if field.value != '' {
			comment = field.value + ', ' + field.comment
		}

		name += ' ='

		mut comment_above := field.comment_was_above
		if comment != '' {
			if comment.contains('\n') {
				mut comment_split := comment.split('\n')
				comment_split = comment_split.map(it.trim_left('* '))
				comment = comment_split.join('\n')
				comment = '// ' + comment.replace('\n', '\n// ')
			} else {
				comment = '// ' + comment
			}
		}

		if comment_above {
			v_code += '\t${comment}\n\t${name} ${val}\n'
		} else {
			v_code += '\t${name} ${val} ${comment}\n'
		}
	}
	v_code += '}\n'

	return v_code
}

fn (p Parser) parse_define(lines []string) CDefine {
	lns := lines.join(' ')
	if lns.contains(r'\ ') {
		return CDefine{
			raw: '// TODO ' + lns
			prefix: p.conf.define_id_prefix
		}
	}
	if lines.len == 0 {
		panic('Empty define')
	}

	mut name := ''
	mut value := ''
	// if lns.contains(' ') {
	name = lines[0].all_after('#define').trim(' ').all_before(' ').trim(' ')
	value = lines[0].all_after('#define').trim(' ').all_after(' ').trim(' ')
	//}

	return CDefine{
		raw: lines.join('\n')
		name: name
		prefix: p.conf.define_id_prefix
		value: value
	}
}

fn is_numerical_value(str string) bool {
	_ := strconv.parse_int(str, 0, 64) or { return false }
	return true
}

fn (cd CDefine) valid() ! {
	if cd.value.all_before('//').contains('"') {
		return
	}
	if cd.raw.starts_with('// ') {
		return error('Comment')
	}
	if cd.value.contains('(') {
		return error('Function')
	}
	if !is_numerical_value(cd.value) {
		return error('Non-numerical')
	}
}

fn (cd CDefine) v_name() !string {
	cd.valid()!

	mut name := cd.name
	if name.starts_with(cd.prefix) {
		name = name.all_after(cd.prefix)
	}
	name = name.to_lower()
	if _ := parser.keywords[name] {
		name = '@' + name // rewrite
	}
	return name
}

fn (cd CDefine) v_value() !string {
	cd.valid()!
	mut value := cd.value.all_before('//').trim(' ')
	if value.contains('"') {
		value = value.replace('"', "'")
	}
	return value
}

fn (cd CDefine) tail_comment() string {
	if cd.value.contains('//') {
		return cd.value.all_after('//').trim(' ')
	}
	if cd.value.contains('/*') && cd.value.contains('*/') {
		return cd.value.all_after('/*').all_before_last('*/').trim(' ')
	}
	return ''
}

fn (p Parser) gen_v_const(cd CDefine) !string {
	mut v_code := '/' + '* ' + cd.raw + ' *' + '/'

	name := cd.v_name()!
	mut value := cd.v_value()!
	if override := p.conf.rewrite['value']['const'][name] {
		value = override
	}

	comment := c_to_v_comment_any(cd.comment)
	tail_comment := cd.tail_comment()
	v_code = '${comment}'
	v_code += 'pub const ' + name + ' = ' + value
	v_code = v_code.trim_right(' ')
	if tail_comment != '' {
		v_code += ' // ' + tail_comment
	}

	return v_code
}

fn (p Parser) filter_ifdefs(lines []string) []string {
	mut sanitized := []string{}
	mut skip_line := false
	for line in lines {
		if line.trim_space().contains('#ifdef') {
			skip_line = true
			continue
		}
		if line.trim_space().contains('#endif') {
			skip_line = false
			continue
		}

		if skip_line {
			continue
		}
		sanitized << line
	}
	return sanitized
}

fn (p Parser) parse_struct(lines []string) ![]CStruct {
	// eprintln('Parsing struct: $lines')
	if lines.len == 0 {
		return error('no lines')
	}

	mut sanitized := p.filter_ifdefs(lines)

	raw := sanitized.join('\n').trim_space()
	mut is_typedef := false
	if raw.contains('typedef') {
		is_typedef = true
	}

	is_union := raw.all_before('{').contains('union')
	mut line := ''
	if lines.len == 1 {
		line = lines[0]
		tokens := line.split(' ')

		mut c_name := '/' + '*' + ' TODO ' + '*' + '/'
		if tokens.len > 3 {
			c_name = tokens[3].trim('{').trim(';')
		}
		if tokens.len > 2 {
			c_name = tokens[2].trim('{').trim(';')
		}
		//@ eprintln('C Struct: $line')
		return [
			CStruct{
				raw: raw
				name: c_name
				prefix: p.conf.struct_id_prefix
				is_typedef: is_typedef
				is_union: is_union
			},
		]
	}

	for i := 0; i < sanitized.len; i++ {
		mut s := sanitized[i]
		if s.trim_space().starts_with('//') {
			s = s + '%%%%'
			sanitized[i] = s
		}
	}
	flat := sanitized.join(' ').replace('\n', '')
	// tokens := flat.split(' ')
	mut raw_members := flat.all_after('{').all_before_last('}').trim(' ')
	raw_members = raw_members.replace('*/', '*/;')
	raw_members = raw_members.replace(' *', '* ')
	raw_members = raw_members.replace('* /', '*/')
	// TODO .replace('[] ',' []') //.replace('const ','')
	// eprintln('C Struct raw members: $raw_members')
	raw_members = raw_members.split(' ').filter(it.trim_space() != '').join(' ')

	mut raw_struct_ids := flat.all_after_last('}').trim(' ').all_before_last(';').replace(' ',
		'').split(',')

	if !is_typedef {
		struct_id := flat.all_before('{').all_after('struct').trim_space()
		raw_struct_ids = [
			struct_id,
		]
	}

	raw_members = raw_members.replace('; }', ' }')
	// em_raw_members := raw_members
	i_members := raw_members.split(';').map(it.trim_space()).filter(it != '')
	mut members := []string{}
	// eprintln(i_members)
	// eprintln('-')
	mut buf := ''
	for i_member in i_members {
		if i_member.contains('%%%%') {
			i_sp := i_member.split('%%%%')
			for sp in i_sp {
				members << sp
			}
			continue
		}
		if i_member.starts_with('/*') && !i_member.contains('}') {
			members << i_member
			continue
		}
		if i_member.contains('}') {
			buf += ' ' + i_member
			members << buf
			buf = ''
		} else if i_member.contains('{') {
			buf += ' ' + i_member
		} else if buf != '' {
			buf += ' ' + i_member
		} else {
			members << i_member
		}
	}
	members = members.filter(it != '')
	members = members.map(it.trim_space())

	//@ eprintln('C Struct members: $members')

	mut fields := []CField{}
	mut in_block_comment := false
	mut comment_above := ''
	mut skip := 0
	for i, member in members {
		if skip > 0 {
			skip--
			continue
		}

		mut embedded_struct := CStruct{}
		msplit := member.split(' ')

		if msplit[0].starts_with('/' + '*') && !msplit[0].contains('*' + '/') {
			comment_above += member
			in_block_comment = true
			continue
		}

		if in_block_comment && msplit[0].contains('*' + '/') {
			comment_above += member
			in_block_comment = false
			continue
		}

		if msplit[0].trim_space().starts_with('//') {
			comment_above += member.all_after('//').trim_space() + '\n'
			// println('CA: $comment_above')
			continue
		}

		probably_has_struct := member.contains('{')
		probably_has_function := member.contains('(')

		// struct { int x, y, z }
		if msplit.len >= 3 && member.contains(',') && !(probably_has_function
			|| probably_has_struct) {
			mut kind := msplit[0]

			for mbr in msplit[1..] {
				mbr_clean := mbr.trim_space()
				mut comment := ''
				if mbr_clean.starts_with('/*') || mbr_clean.starts_with('//') {
					comment = mbr_clean
				}

				mut name := mbr_clean.trim(',')
				if _ := parser.keywords[name] {
					name = '@' + name // rewrite
				}

				fields << CField{
					raw: member
					kind: kind
					name: name
					comment_above: comment_above
					comment: comment
					// embedded_struct: embedded_struct
				}

				if comment_above != '' {
					comment_above = ''
				}
			}
		} else if msplit.len >= 2 {
			mut kind := msplit[0].trim_space()
			mut name := msplit[1].trim_space()
			mut c_id := 2

			if kind == 'const' {
				kind = name
				if msplit.len >= 3 {
					name = msplit[2].trim_space()
					c_id++
				}
			}

			if kind in ['struct', 'union'] {
				mut s_or_u := member

				// TODO YUK-sauce
				// if 'ma_device' in raw_struct_ids {
				mut rewritten := ''
				mut c := f32(1)
				for ch in s_or_u {
					mut put := ch.ascii_str()
					if ch.is_space() {
						if math.mod(c, 2) == 0 {
							put = ';' + put
						}
						c++
					}
					rewritten += put
				}
				s_or_u = rewritten.replace('{;', '{\n')
				// s_or_u += ''
				// eprintln(s_or_u)
				// }

				// kind = msplit[0] + ' ' + msplit[1]
				// name = msplit[2]
				embedded_structs := p.parse_struct([s_or_u])!
				if embedded_structs.len > 0 {
					embedded_struct = embedded_structs[0]
				}
				c_id++
			}

			mut comment := '' // last_comment

			// last_comment = ''
			if msplit.len > c_id {
				comment = msplit[c_id]
			}
			if i + 1 < members.len {
				peep := members[i + 1]
				psplit := peep.split(' ')
				if psplit[0].starts_with('/*') {
					comment += peep
					skip = 1
				}
			}

			if _ := parser.keywords[name] {
				name = '@' + name // rewrite
			}

			fields << CField{
				raw: member
				kind: kind
				name: name
				comment_above: comment_above
				comment: comment
				embedded_struct: embedded_struct
			}

			if comment_above != '' {
				comment_above = ''
			}
		}
	}

	mut c_structs := []CStruct{}
	// eprintln(members)
	for struct_id in raw_struct_ids {
		// struct_id
		if !is_typedef {
			if alias := p.aliases[struct_id] {
				if alias.typ == ._struct {
					is_typedef = true
				}
			}
		}

		c_struct := CStruct{
			raw: raw
			name: struct_id
			prefix: p.conf.struct_id_prefix
			is_typedef: is_typedef
			is_union: is_union
			fields: fields
		}

		c_structs << c_struct
	}

	return c_structs
}

fn is_valid_struct_field_name(str string) bool {
	if str == '' {
		return false
	}
	for b in str {
		if !(b.is_alnum() || b == `_` || b == `@`) {
			// eprintln('$b.ascii_str() in $str is not valid')
			return false
		}
	}
	return true
}

fn is_valid_struct_field_type(str string) bool {
	if str == '' {
		return false
	}
	for b in str {
		if !(b.is_alnum() || b == `&` || b == `_` || b == `.`) {
			// eprintln('$b.ascii_str() in $str is not valid')
			return false
		}
	}
	return true
}

fn (p Parser) gen_v_struct_def(strct CStruct) !string {
	mut v_code := ''

	mut st := strct
	/*
	v_code += '// NOTE\n'
	v_code += '/'+'*'
	v_code += st.raw+'\n'
	//v_code += '$st\n'
	v_code += '*'+'/'
	*/

	if st.name == '' {
		return '/' + '*' + '\nPARSE ERROR:\n' + st.raw + '\n' + '*' + '/'
	}

	v_name := st.v_name()!

	if st.is_typedef {
		v_code += '[typedef]\n'
	}

	type_keyword := if st.is_union { 'union' } else { 'struct' }

	v_code += 'pub ${type_keyword} C.${st.name} {'

	if st.fields.len > 0 {
		v_code += '\npub mut:\n'
	}

	mut all_todo := true
	mut written_field_names := []string{}
	for field in st.fields {
		// mut kind_clean := field.kind.replace('*','').replace('const', '').trim(' ')

		if field.kind in ['struct', 'union'] {
			// v_code += '\n/' + '*\n' + field.embedded_struct.str() + '\n*' + '/\n'
			es_lines := field.embedded_struct.raw.split('\n')
			v_code += '\n// TODO'
			for ln in es_lines {
				v_code += '// ' + ln + '\n'
			}
			continue
		}

		mut kind := p.c_to_v_type_name(field.kind)

		mut name := field.name

		if name in written_field_names {
			continue
		}

		skip := kind in p.conf.skip_typedefs

		mut is_fn_callback_sig := false
		if field.raw.count('(') > 0 {
			if field.raw.count('(') > 1 {
				fnts := parse_typedef_fn_callback([field.raw])
				kind = p.gen_v_fn_callback_field_def(fnts)
				is_fn_callback_sig = true
				name = name.all_after('(').trim('* ')
				// sokol special??
				if name.contains(')') {
					name = name.all_before(')')
					kind = 'fn' + kind.all_after('fn')
				}
				// println('name: "$name" kind: "$kind"')
			} else {
				v_code += '\t// TODO ${field.raw}\n'
				continue
			}
		}

		// NOTE remember: name = c_to_v_var_name( name ) // Don't mangle field names

		if field.name.contains('[') {
			name = field.name.all_before('[')
			kind = '[' + field.name.all_after('[') + kind
		}

		/*
		if field.name.starts_with('*') {
			name = field.name.all_after_last('*')
			kind = '&'.repeat(field.name.count('*')) + kind
		}*/

		mut comment := field.comment
		if comment != '' {
			comment = '// ' +
				comment.replace('\n', ' ').replace('/*', '').replace('*/', '').replace('*<', '').trim(' ')
			comment = comment.replace(r'* \brief', '').replace(r'\brief', '')
			comment = comment.replace('   ', '').replace('  ', '').replace('  ', ' ')
		}

		mut init_value := ''
		if kind.starts_with('&') {
			init_value = '= unsafe { nil }'
		}

		mut comment_above := field.comment_above
		if comment_above != '' {
			ca_sp := comment_above.split('\n')
			comment_above = ''
			for ca in ca_sp {
				mut cleaned := ca.replace('/*', '').replace('*/', '').replace('*<', '').trim(' ')
				cleaned = cleaned.replace(r'* \brief', '').replace(r'\brief', '')
				cleaned = cleaned.replace('   ', '').replace('  ', '').replace('  ', ' ')
				comment_above += '// ' + cleaned + '\n'
			}
		}

		mut field_v_code := '\t'
		if comment_above != '' {
			field_v_code += '${comment_above}\n\t'
		}
		field_v_code += '${name} ${kind}'
		if init_value != '' {
			field_v_code += ' ${init_value}'
		}
		if comment != '' {
			field_v_code += ' ${comment}'
		}
		field_v_code += '\n'

		if skip {
			v_code += '// TODO ' + field_v_code
		} else if is_fn_callback_sig
			|| (is_valid_struct_field_name(name) && is_valid_struct_field_type(kind)) {
			v_code += field_v_code
			all_todo = false
		} else if kind.contains('[') {
			const_value := kind.all_after('[').all_before(']')
			c_type := kind.all_after(']')
			v_type := p.c_to_v_type_name(c_type)
			mut rr := ''
			for _, define in p.defines {
				define.valid() or { continue }
				if define.name == const_value {
					rr = define.v_name() or { '' }
				}
			}
			if v_type.starts_with('C.') {
				rr = ''
			}
			if rr != '' {
				all_todo = false
				v_code += field_v_code.replace(const_value, rr)
			} else {
				v_code += '// TODO ' + field_v_code
			}
		} else {
			v_code += '// TODO ' + field_v_code
		}
		written_field_names << name
	}
	if all_todo {
		v_code = v_code.replace('\npub mut:', '')
	}
	if fields := p.conf.fields_structs[v_name] {
		for field in fields {
			v_code += '${field} // NOTE Added from chew config\n'
		}
	}
	v_code += '}\n'

	v_code += 'pub type ${v_name} = C.${st.name}'

	if v_name in p.conf.skip_typedefs {
		return '/' + '* TODO \n' + v_code + '*' + '/'
	}

	return v_code
}

fn parse_typedef_alias(line string) !CAlias {
	raw := '${line}'

	normalized := raw.replace(' *', '* ')

	mut split := normalized.all_after('typedef ').all_before(';').trim(' ').split(' ')
	split = split.filter(it != '')
	if split.len == 2 {
		name := split[0].trim_space()
		alias := split[1].trim_space()
		return CAlias{
			raw: raw
			name: name
			alias: alias
			typ: .primitive
		}
	}
	if split.len == 3 {
		typ := split[0].trim_space()
		name := split[1].trim_space()
		alias := split[2].trim_space()
		if typ == 'struct' {
			return CAlias{
				raw: raw
				name: name
				alias: alias
				typ: ._struct
			}
		}
	}
	return error('could not parse C alias "${raw}"')
}

fn parse_typedef_fn_callback(lines []string) CFnCallbackSig {
	raw := '${lines.join('\n')}'

	normalized := raw.replace(' *', '* ')

	return_type := normalized.all_after('typedef').all_before('(').trim(' ')
	name := normalized.all_after('(').all_before(')').trim(' ').all_after('*').trim(' ')

	mut raw_args := normalized.all_after(')').all_after('(')
	raw_args = raw_args.all_before_last(')')

	// eprintln('Raw args to function `$fn_name`: `$raw_args`')
	mut raws := raw_args.split(',')
	if raw_args.contains('(') && raw_args.contains(',') {
		raws = preprocess_c_args(raw_args) or { panic(err) }
	}

	raws = raws.filter(it != '')

	mut args := []CArg{}
	for raw_arg in raws {
		args << process_c_args(raw_arg)
	}

	return CFnCallbackSig{
		raw: raw
		return_type: return_type
		name: name
		args: args
	}
}

fn (p Parser) gen_v_fn_callback_def(cbfn CFnCallbackSig) string {
	// `typedef void (SDLCALL * SDL_AudioCallback) (void *userdata, Uint8 * stream)`
	// pub type AudioCallback = fn (userdata voidptr, stream &u8)

	cb_name := c_to_v_struct_name(cbfn.name, p.conf.struct_id_prefix)

	mut args := ''
	for pair in cbfn.args {
		name, kind := p.gen_vc_arg_pair(pair)
		if name != '' && kind != '' {
			args += name + ' ' + kind + ', '
		} else if name == '' && kind != '' {
			args += kind + ', '
		}
	}
	args = args.trim_right(', ')

	mut v_code := ''
	mut comment_code := c_to_v_comment(cbfn.comment, cb_name)

	if comment_code == '' {
		comment_code = '// ${cb_name} is currently undocumented\n'
	}
	v_code += comment_code
	v_code += '// C: ' + cbfn.raw + '\n'
	v_code += 'pub type ${cb_name} = fn (${args}) ' + p.c_to_v_type_name(cbfn.return_type).trim(' ')
	return v_code
}

fn (p Parser) gen_v_fn_callback_field_def(cbfn CFnCallbackSig) string {
	// typedef struct {
	// void (* onSignal)(ma_async_notification* pNotification);

	cb_name := cbfn.name

	mut args := ''
	for pair in cbfn.args {
		name, kind := p.gen_vc_arg_pair(pair)
		if name != '' && kind != '' {
			args += name + ' ' + kind + ', '
		} else if name == '' && kind != '' {
			args += kind + ', '
		}
	}
	args = args.trim_right(', ')

	mut v_code := ''
	// mut comment_code := c_to_v_comment(cbfn.comment, cb_name)

	// if comment_code == '' {
	//	comment_code = '// $cb_name is currently undocumented\n'
	//}
	// v_code += comment_code
	// v_code += '// C: ' + cbfn.raw + '\n'
	v_code += '${cb_name} fn (${args}) ' + p.c_to_v_type_name(cbfn.return_type).trim(' ')
	return v_code
}

fn (p Parser) parse_fn_def(lines []string) CFnSig {
	lns := lines.clone().join(' ')

	api_inline := p.conf.api_inline

	if lines.any(it.contains('...')) {
		return CFnSig{
			raw: lns
		}
	}

	mut sig := lns.all_before(';')
	if lns.contains(api_inline) { // if lns.contains('SDL_FORCE_INLINE ') {
		sig = lns.all_before_last('{')
	}

	mut clean_sig := sig //.all_after('DECLSPEC ')

	if sig.starts_with(api_inline) {
		clean_sig = sig.all_after(api_inline).trim_space()
	}
	mut c_sig := p.c_signature(clean_sig)
	c_sig.raw = lns.replace('  ', '').trim(' ;')

	return c_sig
}

fn (p Parser) c_signature(c_sig string) CFnSig {
	sig := c_sig.replace(' *', '* ') // Normalize pointer positions
	// eprintln('C signature: `$sig`')

	api_inline := p.conf.api_inline
	api_export := p.conf.api_export

	mut return_type_and_fn_name := sig.all_before('(')
	// return_type_and_fn_name = return_type_and_fn_name.replace('SDLCALL', '')
	return_type_and_fn_name = return_type_and_fn_name.replace(api_export, '')
	// if sig.contains('SDL_FORCE_INLINE') {
	if sig.contains(api_inline) {
		return_type_and_fn_name = return_type_and_fn_name.replace(api_inline, '')
		// println(return_type_and_fn_name)
	}

	mut rtafn_sp := return_type_and_fn_name.split(' ')
	rtafn_sp = rtafn_sp.filter(it != '')

	return_type := rtafn_sp[..rtafn_sp.len - 1].join(' ').trim(' ')
	fn_name := rtafn_sp.last().trim(' ')

	mut raw_args := sig.all_after('(')
	raw_args = raw_args.all_before_last(')')

	// eprintln('Raw args to function `$fn_name`: `$raw_args`')
	mut raws := raw_args.split(',')
	if raw_args.contains('(') && raw_args.contains(',') {
		raws = preprocess_c_args(raw_args) or { panic(err) }
	}

	raws = raws.filter(it != '')

	mut args := []CArg{}
	for raw_arg in raws {
		args << process_c_args(raw_arg)
	}

	return CFnSig{c_sig, return_type, fn_name, args, ''}
}

fn preprocess_c_args(arg string) ![]string {
	eprintln('Preprocessing `${arg}`')
	mut out := []string{}
	mut buf := ''
	mut open := false
	for ch in arg {
		if ch == `(` {
			open = true
		} else if ch == `)` {
			open = false
		}
		if !open && ch == `,` {
			out << buf
			buf = ''
			continue
		}
		buf += ch.ascii_str()
	}
	if open {
		return error(@FN + ': could not parse `${arg}`, missing closing `)` delimiter')
	}
	out << buf
	//@ eprintln('Preprocessed `$out`')
	return out
}

fn preprocess_c_arg_part(arg string) ![]string {
	mut out := []string{}
	mut buf := ''
	mut open := false
	for ch in arg {
		if ch == `(` {
			open = true
		} else if ch == `)` {
			open = false
		}
		if !open && ch == ` ` {
			out << buf
			buf = ''
			continue
		}
		buf += ch.ascii_str()
	}
	if open {
		return error(@FN + ': could not parse `${arg}`, missing closing `)` delimiter')
	}
	out << buf
	//@ eprintln('Preprocessed `$out`')
	return out
}

fn process_c_args(arg string) CArg {
	// eprintln('Processing `$arg`')
	mut a := arg.trim(' ')
	// eprintln('Processing `$arg`')
	if a == 'void' {
		return CArg{a, 'void', 'void', false}
	}
	if a == '...' {
		return CArg{a, '...', '...', false}
	}

	a = a.replace('volatile', '')
	// eprintln(a)

	mut parts := a.split(' ')
	// parts = parts.map(fn (a string) string {
	//	return a.trim(' ')
	//})
	if parts.len == 1 {
		// E.g. SDL_AssertData* , const char*, const char* , int)
		return CArg{a, 'void', 'void', false}
	}
	if a.contains('(') && a.contains(' ') {
		parts = preprocess_c_arg_part(a) or {
			return CArg{a, '...', '...', false}
			// panic(err)
		}
	}

	parts = parts.filter(it != '')
	// eprintln('Parts: $parts')
	if parts.len == 0 {
		panic('Error getting C type from `${arg}`')
	}
	mut c_type := parts[..parts.len - 1].join(' ').trim(' ')

	if c_type == '' {
		pts := parts[..parts.len - 1]
		c_type = pts[parts.len - 1].trim(' ')
	}

	// eprintln('C type: $c_type')

	is_const := c_type.contains('const')

	kind := c_type

	name_part := parts[parts.len - 1..]
	if name_part.len == 0 {
		panic('Error getting name from `${arg}`')
	}

	name := name_part[0].trim(' ')

	//@ eprintln('name: `$name`, kind: `$kind` from: "$a"')

	return CArg{a, kind, name, is_const}
}

// gen_vc_fn_sig generates a V C function signature from `sig`.
// E.g. `fn C.malloc(int) &u8`
fn (p Parser) gen_vc_fn_sig(sig CFnSig) string {
	mut v_c_sig := 'fn C.${sig.name}('

	mut args := ''
	for pair in sig.args {
		mut name, mut kind := p.gen_vc_arg_pair(pair)
		is_array := name.count('[]') > 0
		name = name.replace('[]', '')
		kind = if is_array { 'voidptr' } else { kind }

		if name != '' && kind != '' {
			args += name + ' ' + kind + ', '
		} else if name == '' && kind != '' {
			args += kind + ', '
		}
	}
	args = args.trim_right(', ')

	r := v_c_sig + args + ') ' + p.c_to_v_type_name(sig.return_type)
	return r.trim(' ')
}

// gen_vc_fn_call_sig generates a V C function call signature from `sig`.
// E.g. `C.malloc(<sig.args>)`
fn (p Parser) gen_vc_fn_call_sig(sig CFnSig) string {
	mut v_c_sig := 'C.${sig.name}('

	mut args := ''
	for arg in sig.args {
		mut n, _ := p.gen_vc_arg_pair(arg)
		if n != 'void' {
			is_array := n.count('[]') > 0
			dot_data := if is_array { '.data' } else { '' }
			n = n.replace('[]', '')
			if !is_array && p.c_to_v_type_name_is_enum(arg.kind) {
				// TODO
				mut kind := arg.kind.replace('const', '').trim(' ')
				ptr_count := arg.kind.count('*')
				kind = kind.replace('*', '')
				// NOTE pointer to enum is possible in C as pointer writing:
				// E.g.: ... ma_data_source_get_data_format(..., ma_format* pFormat, ...) - where ma_format is an enum
				// TODO figure this out for pointer writes
				// cast_type := if ptr_count > 0 { 'voidptr' } else { 'int' }
				// n = '&'.repeat(ptr_count)+'C.'+kind+'('+cast_type+'('+n+'))'
				n = '&'.repeat(ptr_count) + n
			}
			args += n + dot_data + ', '
		}
	}
	args = args.trim_right(', ')

	r := v_c_sig + args + ')'
	return r.trim(' ')
}

fn (p Parser) gen_vc_arg_pair(c_arg CArg) (string, string) {
	mut out := ''
	mut kind := p.c_to_v_type_name(c_arg.kind)
	mut name := c_to_v_var_name(c_arg.name)

	if _ := parser.keywords[name] {
		name = '@' + name // rewrite
	}

	out = name + ' ' + kind
	if out.contains('...') {
		return name, '/*TODO*/'
	}

	if c_arg.is_const {
		name = 'const_' + name
	}

	return name, kind
}

fn (p Parser) gen_v_wrapper(sig CFnSig) (string, string) {
	// mut v_type := ''
	// mut c_type := ''
	// mut ptr := false

	mut v_wrap_sig := 'pub fn '

	mut fn_name := ''
	// mut first := ''
	// if v_type != '' {
	//	first = c_to_v_var_name(sig.args[0].name)
	//	fn_name = v_fn_name(sig.name.all_after(c_type))
	//	if fname := keywords[fn_name] {
	//		fn_name = fname
	//	}
	//	v_wrap_sig += '(mut $first $v_type) ' + fn_name + '('
	//} else {
	fn_name = p.v_fn_name(sig.name)
	v_wrap_sig += fn_name + '('
	//}

	mut args := ''
	for _, arg in sig.args {
		// if v_type != '' && i == 0 {
		//	continue
		//}

		var_name, kind := p.gen_vc_arg_pair(arg)
		if var_name != '' && kind != '' {
			args += var_name + ' ' + kind + ', '
		} else if var_name == '' && kind != '' {
			args += kind + ', '
		}
	}
	args = args.trim_right(', ')

	v_wrap_sig += args + ') ' + p.c_to_v_type_name(sig.return_type)

	mut fn_body := v_wrap_sig.trim(' ')
	// Gen function body
	fn_body += '{\n'
	fn_body += '\t'
	if sig.return_type != 'void' {
		fn_body += 'return'
	}

	/*
	TODO support ENUM casts
	is_array := sig.return_type.count('[]') > 0
	return_kind = sig.return_type.replace('[]', '')
	if !is_array && p.c_to_v_type_name_is_enum(sig.return_type) {
		// TODO
		mut kind := arg.kind.replace('const', '').trim(' ')
		ptr_count := arg.kind.count('*')
		kind = kind.replace('*', '')
		// NOTE pointer to enum is possible in C as pointer writing:
		// E.g.: ... ma_data_source_get_data_format(..., ma_format* pFormat, ...) - where ma_format is an enum
		// TODO figure this out for pointer writes
		cast_type := if ptr_count > 0 { 'voidptr' } else { 'int' }
		n = '&'.repeat(ptr_count)+'C.'+kind+'('+cast_type+'('+n+'))'
	}*/

	call_sig := p.gen_vc_fn_call_sig(sig) + '\n'
	fn_body += ' ' + call_sig
	fn_body += '}'

	return fn_body.trim(' '), fn_name
}

fn (p Parser) v_fn_name(c_fn_name string) string {
	c_fn_name_sanitized := c_fn_name.replace(p.conf.fn_id_prefix, '')

	mut si := 0
	mut parts := []string{}
	for i, ch in c_fn_name_sanitized {
		if ch.is_capital() {
			parts << c_fn_name_sanitized[si..i].trim('_')
			si = i
		}
		if i == c_fn_name_sanitized.len - 1 {
			parts << c_fn_name_sanitized[si..].trim('_')
		}
	}
	parts = parts.filter(it != '')
	//@ eprintln('$c_fn_name_sanitized : $parts')
	mut v_fn_name := ''
	for i, str in parts {
		if str.len == 1 && str.is_upper() {
			v_fn_name += str.to_lower()
			if i + 1 < parts.len {
				if parts[i + 1].len > 1 {
					v_fn_name += '_'
				}
			}
		} else {
			v_fn_name += str.to_lower() + '_'
		}
	}
	v_fn_name = v_fn_name.trim_right('_').trim_left('_')
	//@ eprintln('Function name: $c_fn_name -> $v_fn_name')
	return v_fn_name
}

fn c_to_v_var_name(c_var_name string) string {
	mut si := 0
	mut parts := []string{}
	for i, ch in c_var_name {
		if ch.is_capital() {
			parts << c_var_name[si..i]
			si = i
		}

		if i == c_var_name.len - 1 {
			parts << c_var_name[si..]
		}
	}
	// eprintln('$c_fn_name : $parts')
	mut v_var_name := ''
	for i, str in parts {
		if str.len == 1 && str.is_upper() {
			v_var_name += str.to_lower()
			if i + 1 < parts.len {
				if parts[i + 1].len > 1 {
					v_var_name += '_'
				}
			}
		} else {
			v_var_name += str.to_lower() + '_'
		}
	}
	v_var_name = v_var_name.trim_right('_')
	// v_var_name = v_var_name.replace('ma_', '')
	// eprintln('$c_fn_name -> $v_var_name')
	return v_var_name.trim_left('_')
}

fn (p Parser) c_to_v_type_name_is_enum(typ string) bool {
	mut kind := typ.replace('const', '').trim(' ')
	kind = kind.replace('*', '')

	if _ := p.enums[kind] {
		return true
	}
	return false
}

// c_to_v_type_name translates a C type to a V type.
// E.g. `float` -> `f32`. If the type isn't a known primitive type
// it will be returned with a `C.` prefix.
fn (p Parser) c_to_v_type_name(typ string) string {
	mut kind := typ.replace('const', '').trim(' ')

	mut ptr := ''
	ptr_count := kind.count('*')
	if ptr_count >= 1 {
		ptr = '&'.repeat(ptr_count)
		kind = kind.replace('*', '')
	}

	if enu := p.enums[kind] {
		return ptr + enu.v_name() or { ptr + kind }
	}
	if strct := p.structs[kind] {
		return ptr + strct.v_name() or { ptr + kind }
	}

	// translate aliases E.g: `typedef ma_uint8 ma_channel;`
	if alias := p.aliases[kind] {
		a_kind := alias.name
		// println('$typ is alias $alias.name -> $alias.alias')

		if a_kind == 'void' {
			if ptr != '' {
				return 'voidptr'
			}
			return ''
		}

		if found := parser.c_to_v_type_map[a_kind] {
			return ptr + found
		}

		if found := p.conf.primitives_map[a_kind] {
			return ptr + found
		}
	}

	if kind == 'void' {
		if ptr != '' {
			return 'voidptr'
		}
		return ''
	}

	if found := parser.c_to_v_type_map[kind] {
		return ptr + found
	}

	if found := p.conf.primitives_map[kind] {
		return ptr + found
	}

	return ptr + 'C.' + kind
}

fn c_to_v_comment(comment_str string, fn_name string) string {
	comment := comment_str.split('\n')
	mut comment_code := ''
	mut comment_mark := '//'
	for i, line in comment {
		mut cleaned_line := line.all_after('*')

		if cleaned_line.count('**') > 2 {
			continue
		}

		if cleaned_line == '' && i == comment.len - 1 {
			continue
		}
		if cleaned_line.ends_with('*/') && i < comment.len - 1 {
			continue
		}
		if cleaned_line.contains(r'\code') {
			comment_mark = ''
			if cleaned_line.contains(r'\endcode') {
				comment_mark = '//'
				cleaned_line = cleaned_line.replace_each([r'\code', '`', r'\endcode', '`'])
			} else {
				cleaned_line = cleaned_line.replace(r'\code', '/*\n```')
			}
		} else if cleaned_line.contains(r'\endcode') {
			comment_mark = '//'
			cleaned_line = cleaned_line.replace(r'\endcode', '```\n*/')
		}

		// cleaned_line = cleaned_line
		mut handled_plural := false
		if i == 0 {
			mut csp := cleaned_line.trim(' ').replace('\\brief', '').trim(' ').split(' ')
			if csp.len > 1 {
				mut first_word := csp[0].to_lower()
				if !first_word.ends_with('s') {
					first_word += 's'
				}
				csp[0] = ' ${fn_name} ' + first_word
				comment_code += comment_mark + csp.join(' ') + '\n'
				handled_plural = true
			}
		} else if i == 1 {
			if !handled_plural {
				mut csp := cleaned_line.trim(' ').replace('\\brief', '').trim(' ').split(' ')
				if csp.len > 1 {
					mut first_word := csp[0].to_lower()
					if !first_word.ends_with('s') {
						first_word += 's'
					}
					csp[0] = ' ${fn_name} ' + first_word
					comment_code += comment_mark + csp.join(' ') + '\n'
					handled_plural = true
				}
			} else {
				comment_code += comment_mark + cleaned_line + '\n'
			}
		} else {
			comment_code += comment_mark + cleaned_line + '\n'
		}
	}
	comment_code = comment_code.trim_string_right('//\n')
	comment_code = comment_code.trim_string_left('//\n')

	/*
	comment_code = comment_code.replace('///\n', '')
	comment_code = comment_code.replace(' \\warning ', ' WARNING ')
	comment_code = comment_code.replace(' \\note ', ' NOTE ')
	comment_code = comment_code.replace(' \\return ', ' returns ')
	comment_code = comment_code.replace(' \\li ', ' * ')
	comment_code = comment_code.replace(' \\sa ', ' See also: ')

	// comment_code = comment_code.replace('\\code','/'+'* ```')
	// comment_code = comment_code.replace('\\endcode','``` *'+'/')
	comment_code = comment_code.replace_each(['[in]', '', '[out]', '', '[in,out]', ''])
	*/

	/*
	$if prod {
		mut re := regex_params_in_comment
		comment_code = re.replace(comment_code, r'`\0`\1')

		re = regex_c_in_comment
		comment_code = re.replace(comment_code, r'`\0`\1')

		re = regex_cs_triple_in_comment
		comment_code = re.replace(comment_code, r'\0')

		comment_code = comment_code.replace(' \\param ', '') // TODO - still a few whoopies left
	}*/
	return comment_code
}

fn c_to_v_comment_any(comment_str string) string {
	comment := comment_str.split('\n')
	mut comment_code := ''
	mut comment_mark := '//'
	for i, line in comment {
		mut cleaned_line := line.all_after('*')

		if cleaned_line.count('**') > 2 {
			continue
		}

		cleaned_line = cleaned_line.trim(' ')

		if cleaned_line == '' && (i == comment.len - 1 || i == 0) {
			continue
		}
		if cleaned_line.ends_with('*/') && i < comment.len - 1 {
			continue
		}
		// SDL specific
		if cleaned_line.contains(r'\code') {
			comment_mark = ''
			if cleaned_line.contains(r'\endcode') {
				comment_mark = '//'
				cleaned_line = cleaned_line.replace_each([r'\code', '`', r'\endcode', '`'])
			} else {
				cleaned_line = cleaned_line.replace(r'\code', '/*\n```')
			}
		} else if cleaned_line.contains(r'\endcode') {
			comment_mark = '//'
			cleaned_line = cleaned_line.replace(r'\endcode', '```\n*/')
		}

		// cleaned_line = cleaned_line
		if cleaned_line == '' {
			comment_code += comment_mark + '\n'
		} else {
			comment_code += comment_mark + ' ' + cleaned_line + '\n'
		}
	}
	comment_code = comment_code.trim_string_right('//\n')
	comment_code = comment_code.trim_string_left('//\n')

	comment_code = comment_code.trim_string_right('// \n')
	comment_code = comment_code.trim_string_left('// \n')

	// comment_code = comment_code.replace_once('// \n', '')
	comment_code = comment_code.replace('///\n', '')
	comment_code = comment_code.replace(' \\brief ', ' ')
	comment_code = comment_code.replace(' \\warning ', ' WARNING ')
	comment_code = comment_code.replace(' \\note ', ' NOTE ')
	comment_code = comment_code.replace(' \\return ', ' returns ')
	comment_code = comment_code.replace(' \\returns ', ' returns ')
	comment_code = comment_code.replace(' \\li ', ' * ')
	comment_code = comment_code.replace(' \\sa ', ' See also: ')

	// comment_code = comment_code.replace('\\code','/'+'* ```')
	// comment_code = comment_code.replace('\\endcode','``` *'+'/')
	// comment_code = comment_code.replace_each(['[in]', '', '[out]', '', '[in,out]', ''])

	/*
	$if prod {
		mut re := regex_params_in_comment
		comment_code = re.replace(comment_code, r'`\0`\1')

		re = regex_c_in_comment
		comment_code = re.replace(comment_code, r'`\0`\1')

		re = regex_cs_triple_in_comment
		comment_code = re.replace(comment_code, r'\0')

		comment_code = comment_code.replace(' \\param ', '') // TODO - still a few whoopies left
	}*/
	return comment_code
}
