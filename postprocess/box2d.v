// Copyright(C) 2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module main

import os

fn main() {
	input_path := os.args[1]

	// eprintln(input_path)
	mut files := []string{}
	files = os.walk_ext(input_path, '.c.v')
	// eprintln(files)
	for v_file in files {
		file_name := os.file_name(v_file)
		new_name := file_name.all_after('box2d.').replace('.auto', '')
		base_path := os.dir(v_file)
		new_file := os.join_path(base_path, new_name)
		if os.is_file(new_file) {
			eprintln('removing ${new_file} from last run')
			os.rm(new_file)!
		}
	}

	files = os.walk_ext(input_path, '.c.v')
	for v_file in files {
		// eprintln(v_file)
		fix_all_pre(v_file)!
		file_name := os.file_name(v_file)
		if file_name.contains('.types.') {
			fix_types(v_file)!
		}
		if file_name.contains('.base.') {
			fix_base(v_file)!
		}
		if file_name.contains('.collision.') {
			fix_collision(v_file)!
		}
		if file_name.contains('.box2d.auto.') {
			fix_box2d(v_file)!
		}
		fix_all(v_file)!
		fix_all_c_marks(v_file)!
		fix_struct_space(v_file)!
	}

	for v_file in files {
		file_name := os.file_name(v_file)
		new_name := file_name.all_after('box2d.').replace('.auto', '')
		base_path := os.dir(v_file)
		new_file := os.join_path(base_path, new_name)
		if os.is_file(new_file) {
			os.rm(new_file)!
		}
		eprintln('${v_file} -> ${new_file}')
		os.mv(v_file, new_file) or { eprintln('failed moving ${v_file}: ${err.msg()}') }
	}
	eprintln('done')
}

fn fix_types(path string) ! {
	eprintln('Fixing ${path}...')
	lines := os.read_lines(path) or { panic(err) }
	prelude := ''
	// "// Prototype for a contact filter callback.
	// // This is called when a contact pair is considered for collision. This allows you to
	// // perform custom logic to prevent collision between shapes. This is only called if
	// // one of the two shapes has custom filtering enabled.
	// // Notes:
	// // - this function must be thread-safe
	// // - this is only called if one of the two shapes has enabled custom filtering
	// // - this is called only for awake dynamic bodies
	// // Return false if you want to disable the collision
	// // @see b2ShapeDef
	// // @warning Do not attempt to modify the world inside this callback
	// // @ingroup world
	// // @C: `typedef bool b2CustomFilterFcn( b2ShapeId shapeIdA, b2ShapeId shapeIdB, void* context );`
	// pub type CustomFilterFcn =  fn (shapeIdA ShapeId, shapeIdB ShapeId, context voidptr) bool
	//
	// // Prototype for a pre-solve callback.
	// // This is called after a contact is updated. This allows you to inspect a
	// // contact before it goes to the solver. If you are careful, you can modify the
	// // contact manifold (e.g. modify the normal).
	// // Notes:
	// // - this function must be thread-safe
	// // - this is only called if the shape has enabled pre-solve events
	// // - this is called only for awake dynamic bodies
	// // - this is not called for sensors
	// // - the supplied manifold has impulse values from the previous step
	// // Return false if you want to disable the contact this step
	// // @warning Do not attempt to modify the world inside this callback
	// // @ingroup world
	// // @C: `typedef bool b2PreSolveFcn( b2ShapeId shapeIdA, b2ShapeId shapeIdB, b2Manifold* manifold, void* context );`
	// pub type PreSolveFcn = fn (shapeIdA ShapeId, shapeIdB ShapeId, manifold &Manifold, context voidptr) bool
	//
	// // Prototype callback for overlap queries.
	// // Called for each shape found in the query.
	// // @see b2World_OverlapABB
	// // @return false to terminate the query.
	// // @ingroup world
	// // @C: `typedef bool b2OverlapResultFcn( b2ShapeId shapeId, void* context );
	// pub type OverlapResultFcn = fn (shapeId ShapeId, context voidptr) bool
	//
	// // Prototype callback for ray casts.
	// // Called for each shape found in the query. You control how the ray cast
	// // proceeds by returning a float:
	// // return -1: ignore this shape and continue
	// // return 0: terminate the ray cast
	// // return fraction: clip the ray to this point
	// // return 1: don't clip the ray and continue
	// // @param shapeId the shape hit by the ray
	// // @param point the point of initial intersection
	// // @param normal the normal vector at the point of intersection
	// // @param fraction the fraction along the ray at the point of intersection
	// // @param context the user context
	// // @return -1 to filter, 0 to terminate, fraction to clip the ray for closest hit, 1 to continue
	// // @see b2World_CastRay
	// // @ingroup world
	// // @C: `typedef float b2CastResultFcn( b2ShapeId shapeId, b2Vec2 point, b2Vec2 normal, float fraction, void* context );`
	// pub type CastResultFcn = fn (shapeId ShapeId, point Vec2, normal Vec2, fraction f32, context voidptr) f32
	// "
	mut new_lines := []string{}
	for line in lines {
		mut new_line := line
		if new_line.contains('\t = C.\t') {
			new_line = new_line.replace('\t = C.\t', '')
		}
		if new_line.contains(' &C. ') {
			if new_line.contains('b2EnqueueTaskCallback') {
				new_line = new_line.replace('&C. ', '').replace('b2EnqueueTaskCallback',
					'EnqueueTaskCallback')
			}
			if new_line.contains('b2FinishTaskCallback') {
				new_line = new_line.replace('&C. ', '').replace('b2FinishTaskCallback',
					'FinishTaskCallback')
			}
		}
		// if new_line.contains('module box2d') {
		// 	new_line = new_line + '\n' + prelude
		// }
		new_lines << new_line
	}
	mut file_contents := new_lines.join('\n')
	// file_contents := os.read_file(path)!
	// file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn fix_base(path string) ! {
	eprintln('Fixing ${path}...')
	lines := os.read_lines(path) or { panic(err) }
	mut new_lines := []string{}
	for line in lines {
		mut new_line := line
		if new_line.contains(' &C.') {
			if new_line.contains('b2AllocFcn') {
				new_line = new_line.replace('&C.', '').replace('b2AllocFcn', 'AllocFcn')
			}
			if new_line.contains('b2FreeFcn') {
				new_line = new_line.replace('&C.', '').replace('b2FreeFcn', 'FreeFcn')
			}
			if new_line.contains('b2AssertFcn') {
				new_line = new_line.replace('&C.', '').replace('b2AssertFcn', 'AssertFcn')
			}
		}
		new_lines << new_line
	}

	mut file_contents := new_lines.join('\n')
	// file_contents := os.read_file(path)!
	// file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn fix_box2d(path string) ! {
	eprintln('Fixing ${path}...')
	lines := os.read_lines(path) or { panic(err) }
	mut new_lines := []string{}
	for line in lines {
		mut new_line := line
		if new_line.contains(' &C.') {
			dump(line)
			if new_line.contains('b2OverlapResultFcn') {
				new_line = new_line.replace_once('&C. ', '')
				new_line = new_line.replace('b2OverlapResultFcn', 'OverlapResultFcn')
			}
			if new_line.contains('b2CastResultFcn') {
				new_line = new_line.replace_once('&C. ', '')
				new_line = new_line.replace('b2CastResultFcn', 'CastResultFcn')
			}
			if new_line.contains('b2CustomFilterFcn') {
				new_line = new_line.replace_once('&C. ', '')
				new_line = new_line.replace('b2CustomFilterFcn', 'CustomFilterFcn')
			}
			if new_line.contains('b2PreSolveFcn') {
				new_line = new_line.replace_once('&C. ', '')
				new_line = new_line.replace('b2PreSolveFcn', 'PreSolveFcn')
			}
			if new_line.contains('b2FrictionCallback') {
				new_line = new_line.replace_once('&C. ', '')
				new_line = new_line.replace('b2FrictionCallback', 'FrictionCallback')
			}
			if new_line.contains('b2RestitutionCallback') {
				new_line = new_line.replace_once('&C. ', '')
				new_line = new_line.replace('b2RestitutionCallback', 'RestitutionCallback')
			}
			if new_line.contains(' void') && !new_line.contains('voidptr') {
				new_line = new_line.replace_once('&C. ', '')
				new_line = new_line.replace(' void', ' voidptr')
			}
			// if new_line.contains(' &C .void') {
			// 	new_line = new_line.replace('&C. ', '')
			// 	new_line = new_line.replace(' &C. void', ' voidptr')
			// }
			if new_line.contains('b2CastResultFcn') {
				new_line = new_line.replace_once('&C. ', '')
				new_line = new_line.replace('b2CastResultFcn', 'CastResultFcn')
			}
		}
		new_lines << new_line
	}

	mut file_contents := new_lines.join('\n')
	// file_contents := os.read_file(path)!
	// file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn fix_collision(path string) ! {
	eprintln('Fixing ${path}...')
	lines := os.read_lines(path) or { panic(err) }
	mut new_lines := []string{}
	for line in lines {
		mut new_line := line
		// println('l: "${line}"')
		// if new_line.contains(' &C. ') {
		//     // println('OOOOOOOOOOOOOOOO')
		// 	new_line = new_line.replace(' &C. ', ' &C.')
		// }
		if new_line.contains(' &C. ') {
			if new_line.contains('b2TreeQueryCallbackFcn') {
				// println('OOOOOOOOOOOOOOOO')
				new_line = new_line.replace('&C. ', '')
				new_line = new_line.replace('b2TreeQueryCallbackFcn', 'TreeQueryCallbackFcn')
			}
			if new_line.contains('b2TreeRayCastCallbackFcn') {
				new_line = new_line.replace('&C. ', '')
				new_line = new_line.replace('b2TreeRayCastCallbackFcn', 'TreeRayCastCallbackFcn')
			}
			if new_line.contains('b2TreeShapeCastCallbackFcn') {
				new_line = new_line.replace('&C. ', '')
				new_line = new_line.replace('b2TreeShapeCastCallbackFcn', 'TreeShapeCastCallbackFcn')
			}
		}
		new_lines << new_line
	}

	mut file_contents := new_lines.join('\n')
	// file_contents := os.read_file(path)!
	// file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn fix_struct_space(path string) ! {
	eprintln('All fixing ${path}...')
	lines := os.read_lines(path) or { panic(err) }
	mut new_lines := []string{}
	mut inside_struct := false
	for i, line in lines {
		mut new_line := line
		prev_line := lines[i - 1] or { 'NONONO' }
		next_line := lines[i + 1] or { 'NONONO' }

		if !inside_struct {
			if new_line.starts_with('pub struct') && new_line.count('{') == 1 {
				inside_struct = true
				// println('INSIDE: ${new_line}')
			}
		}
		if inside_struct && new_line.trim(' \t') == '}' {
			inside_struct = false
			// println('OUTSIDE: ${prev_line}')
		}

		if inside_struct && prev_line != 'NONONO' {
			// println(' IN SNOOP: "${new_line}"<XXX>"${prev_line}"')
			if new_line.trim(' ') == '' {
				if prev_line.trim(' \t').starts_with('// ') {
					// println(' TRIGGER: "${new_line}"<XXX>"${prev_line}"')
					continue
				}
				// if prev_line.trim(' \t') == '//' {
				//    println(' TRIGGER-BOB: "${new_line}"<XXX>"${prev_line}"')
				//    continue
				//  }
			}
		}

		// Peek
		if next_line != 'NONONO' {
			if new_line.trim_right(' ') == '//' && next_line.starts_with('pub fn ') {
				continue
			}
		}
		new_lines << new_line
	}
	mut file_contents := new_lines.join('\n')
	// file_contents := os.read_file(path)!
	// file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn fix_all(path string) ! {
	eprintln('All fixing ${path}...')
	lines := os.read_lines(path) or { panic(err) }
	mut new_lines := []string{}
	for i, line in lines {
		mut new_line := line
		next_line := lines[i + 1] or { 'NONONO' }

		if new_line.starts_with('// NOTE this file is auto-generated by ') {
			new_line = '// Copyright(C) 2025 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.'
		}
		if new_line.starts_with('import box2d.c') {
			continue
		}
		if new_line.starts_with('pub const used_import') {
			continue
		}
		if new_line.starts_with('// TODO Non-numerical: #define') {
			new_line = rewrite_define_if_possible(new_line)
		}
		if new_line.starts_with('// TODO Function: #define') {
			new_line = rewrite_define_if_possible(new_line)
		}
		if new_line.starts_with('// ') && new_line.contains(' //s ') {
			new_line = new_line.replace('//s', ':')
		}
		if new_line.starts_with('// @C: ') && new_line.count('\t') > 0 {
			new_line = new_line.replace('\t', '')
		}
		if new_line.starts_with('pub fn ') && new_line.count('\t') > 0 {
			new_line = new_line.replace('\t', '')
		}
		if new_line.starts_with('fn ') && new_line.count('\t') > 0 {
			new_line = new_line.replace('\t', '')
		}
		if new_line.starts_with('//// ') {
			new_line = new_line.replace('//// ', '// ')
		}
		if new_line.starts_with('// //') {
			new_line = new_line.replace('// //', '//')
		}
		if new_line.contains('// / ') {
			new_line = new_line.replace('// / ', '// ')
		}
		if new_line.starts_with('// / ') {
			new_line = new_line.replace('// / ', '// ')
		}
		if new_line.starts_with('// TODO \t// /') {
			new_line = new_line.replace('// TODO \t// /', '// ')
		}
		if new_line.starts_with('// /\t') {
			new_line = new_line.replace('// /\t', '// ')
		}
		if new_line.contains('[B2_MAX_POLYGON_VERTICES]') {
			new_line = new_line.replace('[B2_MAX_POLYGON_VERTICES]', '[max_polygon_vertices]')
		}
		if new_line.starts_with('pub const max_polygon_vertices = C.B2_MAX_POLYGON_VERTICES // 8') {
			new_line = new_line.replace('pub const max_polygon_vertices = C.B2_MAX_POLYGON_VERTICES // 8',
				'pub const max_polygon_vertices = 8 // C.B2_MAX_POLYGON_VERTICES // 8')
		}
		if new_line.contains('// @return ') {
			new_line = new_line.replace('// @return ', '// returns ')
		}
		if new_line.contains('// @param ') {
			param_name := new_line.all_after('@param ').all_before(' ')
			new_line = new_line.replace('// @param ', '// `${param_name}` ')
		}
		if new_line.contains('// @see ') {
			new_line = new_line.replace('// @see ', '// See also: ')
		}
		if new_line.contains(' @see ') {
			new_line = new_line.replace(' @see ', ' See also: ')
		}
		if new_line.contains(' @note ') {
			new_line = new_line.replace(' @note ', ' NOTE: ')
		}
		if new_line.contains(' @warning ') {
			new_line = new_line.replace(' @warning ', ' WARNING: ')
		}
		if new_line.contains(' C.int') {
			new_line = new_line.replace(' C.int', ' int')
		}
		if new_line.contains(' &C.void') {
			new_line = new_line.replace(' &C.void', ' voidptr')
		}
		if new_line.contains(' &C .void') {
			new_line = new_line.replace(' &C. void', ' voidptr')
		}
		if new_line.contains(' @code{.cpp}') {
			new_line = new_line.replace(' @code{.cpp}', ' ```cpp')
		}
		if new_line.contains(' @code{.c}') {
			new_line = new_line.replace(' @code{.c}', ' ```c')
		}
		if new_line.contains(' @endcode') {
			new_line = new_line.replace(' @endcode', ' ```')
		}
		if new_line.starts_with('//') && new_line.contains(' : @return') {
			new_line = new_line.replace(' : @return', ' : returns')
		}
		if new_line.starts_with('//') && new_line.contains(' : @param') {
			param_name := new_line.all_after('@param ').all_before(' ')
			new_line = new_line.replace(' : @param', ' : `${param_name}`')
		}
		if new_line.contains('// @returns') {
			new_line = new_line.replace(' @returns', ' returns')
		}

		if new_line.contains('TODO Function') {
			if new_line.contains('define B2_IS_NULL') {
				new_line = new_line.replace('TODO Function: ', '@C: ') +
					'
fn C.B2_IS_NULL(id WorldId) bool
pub fn is_null(id WorldId) bool { return C.B2_IS_NULL(id) }'
			}
			if new_line.contains('define B2_IS_NON_NULL') {
				new_line = new_line.replace('TODO Function: ', '@C: ') +
					'
fn C.B2_IS_NON_NULL(id WorldId) bool
pub fn is_non_null(id WorldId) bool { return C.B2_IS_NON_NULL(id) }'
			}
			if new_line.contains('define B2_ID_EQUALS') {
				new_line = new_line.replace('TODO Function: ', '@C: ') +
					'
fn C.B2_ID_EQUALS(id1 WorldId, id2 WorldId) bool
pub fn id_equals(id1 WorldId, id2 WorldId) bool { return C.B2_ID_EQUALS(id1,id2) }'
			}
		}

		// Peek
		if next_line != 'NONONO' {
			if new_line.trim_right(' ') == '//' && next_line.starts_with('pub fn ') {
				continue
			}
		}
		new_lines << new_line
	}
	mut file_contents := new_lines.join('\n')
	// file_contents := os.read_file(path)!
	// file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn fix_all_pre(path string) ! {
	// eprintln('All-PRE fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	// mut new_lines := []string{}
	// for i, line in lines {
	// 	mut new_line := line
	// 	next_line := lines[i + 1] or { 'NONONO' }
	//
	// 	if new_line.contains(' fn ') && new_line.contains('C. ') {
	// 		println('OOOOO')
	// 		// new_line = new_line.replace(' C.int', ' int')
	// 	}
	// 	// Peek
	// 	if next_line != 'NONONO' {
	// 		if new_line.trim_right(' ') == '//' && next_line.starts_with('pub fn ') {
	// 			continue
	// 		}
	// 	}
	// 	new_lines << new_line
	// }
	// mut file_contents := new_lines.join('\n')
	// // file_contents := os.read_file(path)!
	// // file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	// os.write_file(path, file_contents)!
}

fn fix_all_c_marks(path string) ! {
	eprintln('All C mark fixing ${path}...')
	lines := os.read_lines(path) or { panic(err) }
	mut new_lines := []string{}
	for i, line in lines {
		mut new_line := line
		next_line := lines[i + 1] or { 'NONONO' }
		if new_line.trim(' ') == '//' {
			new_line = '//'
		}
		if new_line.contains('// @C: ') {
			// Peek
			// if next_line != 'NONONO' {
			// 	if next_line.starts_with('fn C.') {
			// 		c_fn_name := next_line.all_after('fn C.').all_before('(')
			// 		new_line = '// C.${c_fn_name} [official documentation](https://wiki.libsdl.org/SDL3/${c_fn_name})'
			// 	}
			// 	if next_line.starts_with('pub type ') {
			// 		c_typ_name := 'SDL_' + next_line.all_after('pub type ').all_before(' =')
			// 		new_line = '// [Official documentation](https://wiki.libsdl.org/SDL3/${c_typ_name})'
			// 	}
			// }
			// if new_line.starts_with('// @C: ``') {
			// 	continue
			// }
		}
		// println('l: "${new_line}"')
		if new_line == '//' {
			continue
		}
		new_lines << new_line
	}
	mut file_contents := new_lines.join('\n')
	// file_contents := os.read_file(path)!
	// file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn rewrite_define_if_possible(line string) string {
	after_define := line.all_after('#define ').trim(' ')
	// if after_define.starts_with('B2_') && after_define.ends_with('_h_') {
	// 	return ''
	// }
	ident_and_rest := after_define.all_after('B2_')
	ident := ident_and_rest.all_before(' ')
	ident_low := ident_and_rest.all_before(' ').to_lower()
	value := ident_and_rest.all_after(' ').trim(' ')

	if ident_low.contains('(') || ident_low.contains(')') {
		eprintln('Skipping function: ${line}')
		return line
	}

	if after_define.starts_with('B2_DEFAULT_') {
		mut v_value := 'C.B2_${ident} // ${value}'
		if after_define.starts_with('SDL_INIT_') {
			v_value = 'u32(C.SDL_${ident}) // ${value}'
			return 'pub const ${ident_low} = ${v_value}'
		}
		return 'pub const ${ident_low} = ${v_value}'
	}
	// eprintln(after_define)
	return line
}

//
// fn v_fn_name(c_fn_name string) string {
// 	c_fn_name_sanitized := c_fn_name.replace('SDL_', '')
//
// 	mut si := 0
// 	mut parts := []string{}
// 	for i, ch in c_fn_name_sanitized {
// 		if ch.is_capital() {
// 			parts << c_fn_name_sanitized[si..i].trim('_')
// 			si = i
// 		}
// 		if i == c_fn_name_sanitized.len - 1 {
// 			parts << c_fn_name_sanitized[si..].trim('_')
// 		}
// 	}
// 	parts = parts.filter(it != '')
// 	//@ eprintln('$c_fn_name_sanitized : $parts')
// 	mut v_fn_name := ''
// 	for i, str in parts {
// 		if str.len == 1 && str.is_upper() {
// 			v_fn_name += str.to_lower()
// 			if i + 1 < parts.len {
// 				if parts[i + 1].len > 1 {
// 					v_fn_name += '_'
// 				}
// 			}
// 		} else {
// 			v_fn_name += str.to_lower() + '_'
// 		}
// 	}
// 	v_fn_name = v_fn_name.trim_right('_').trim_left('_')
// 	//@ eprintln('Function name: $c_fn_name -> $v_fn_name')
// 	return v_fn_name
// }
//
// fn c_to_v_var_name(c_var_name string) string {
// 	mut si := 0
// 	mut parts := []string{}
// 	for i, ch in c_var_name {
// 		if ch.is_capital() {
// 			parts << c_var_name[si..i]
// 			si = i
// 		}
//
// 		if i == c_var_name.len - 1 {
// 			parts << c_var_name[si..]
// 		}
// 	}
// 	// eprintln('$c_fn_name : $parts')
// 	mut v_var_name := ''
// 	for i, str in parts {
// 		if str.len == 1 && str.is_upper() {
// 			v_var_name += str.to_lower()
// 			if i + 1 < parts.len {
// 				if parts[i + 1].len > 1 {
// 					v_var_name += '_'
// 				}
// 			}
// 		} else {
// 			v_var_name += str.to_lower() + '_'
// 		}
// 	}
// 	v_var_name = v_var_name.trim_right('_')
// 	// v_var_name = v_var_name.replace('ma_', '')
// 	// eprintln('$c_fn_name -> $v_var_name')
// 	return v_var_name.trim_left('_')
// }
