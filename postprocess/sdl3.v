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
		// eprintln(v_file)
		file_name := os.file_name(v_file)
		if file_name.contains('sdl_clipboard') {
			fix_clipboard(v_file)!
		} else if file_name.contains('sdl_atomic') {
			fix_atomic(v_file)!
		} else if file_name.contains('sdl_audio') {
			fix_audio(v_file)!
		} else if file_name.contains('sdl_error') {
			fix_error(v_file)!
		} else if file_name.contains('sdl_events') {
			fix_events(v_file)!
		} else if file_name.contains('sdl_gamepad') {
			fix_gamepad(v_file)!
		} else if file_name.contains('sdl_gpu') {
			fix_gpu(v_file)!
		} else if file_name.contains('sdl_init') {
			fix_init(v_file)!
		} else if file_name.contains('sdl_iostream') {
			fix_iostream(v_file)!
		} else if file_name.contains('sdl_joystick') {
			fix_joystick(v_file)!
		} else if file_name.contains('sdl_mutex') {
			fix_mutex(v_file)!
		} else if file_name.contains('sdl_log') {
			fix_log(v_file)!
		} else if file_name.contains('sdl_stdinc') {
			fix_stdinc(v_file)!
		} else if file_name.contains('sdl_render') {
			fix_render(v_file)!
		} else if file_name.contains('sdl_storage') {
			fix_storage(v_file)!
		} else if file_name.contains('sdl_vulkan') {
			fix_vulkan(v_file)!
		} else if file_name.contains('sdl_version') {
			fix_version(v_file)!
		} else if file_name.contains('sdl_revision') {
			fix_revision(v_file)!
		} else if file_name.contains('sdl_hidapi') {
			fix_hidapi(v_file)!
		} else if file_name.contains('sdl_haptic') {
			fix_haptic(v_file)!
		}

		fix_all_c_marks(v_file)!

		fix_all(v_file)!
	}

	for v_file in files {
		file_name := os.file_name(v_file)
		new_name := file_name.all_after('sdl.sdl_').replace('.auto', '')
		base_path := os.dir(v_file)
		new_file := os.join_path(base_path, new_name)
		eprintln('${v_file} -> ${new_file}')
		os.mv(v_file, new_file) or { eprintln('failed moving ${v_file}: ${err.msg()}') }
	}
	eprintln('done')
}

fn fix_clipboard(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('const_*mime_types &char', 'const_mime_types &&char')
	os.write_file(path, file_contents)!
}

fn fix_atomic(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('pub const compilerbarrier() = __asm__', '// TODO: pub const compilerbarrier() = __asm__')
	file_contents = file_contents.replace('pub const memorybarrier', '// TODO: pub const memorybarrier')
	file_contents = file_contents.replace('*a voidptr', 'a &voidptr')
	os.write_file(path, file_contents)!
}

fn fix_audio(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('*audio_buf &u8', 'audio_buf &&u8')
	file_contents = file_contents.replace('*dst_data &u8', 'dst_data &&u8')

	os.write_file(path, file_contents)!
}

fn fix_error(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('pub const unsupported()', '// TODO: pub const unsupported()')
	file_contents = file_contents.replace('pub const invalidparamerror(param)', '// TODO: pub const invalidparamerror(param)')

	os.write_file(path, file_contents)!
}

fn fix_events(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('*userdata voidptr', 'userdata &voidptr')

	os.write_file(path, file_contents)!
}

fn fix_gamepad(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('// TODO// union {
//  SDL_GamepadButton button; struct {
//  SDL_GamepadAxis axis; int axis_min; int axis_max; } axis; } output
}',
		'}
// TODO: BELONGS ABOVE // union {
//  SDL_GamepadButton button; struct {
//  SDL_GamepadAxis axis; int axis_min; int axis_max; } axis; } output
')

	os.write_file(path, file_contents)!
}

fn fix_gpu(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('*swapchain_texture &GPUTexture', 'swapchain_texture &&GPUTexture')
	os.write_file(path, file_contents)!
}

fn fix_init(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('*appstate voidptr', 'appstate &voidptr')
	file_contents = file_contents.replace('argv[] &char', 'argv &&char')
	os.write_file(path, file_contents)!
}

fn fix_render(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace(' *window &Window', ' window &&Window')
	file_contents = file_contents.replace('*renderer &Renderer', 'renderer &&Renderer')
	file_contents = file_contents.replace(' *pixels voidptr', ' pixels &voidptr')
	file_contents = file_contents.replace(' *surface &Surface', ' surface &&Surface')
	os.write_file(path, file_contents)!
}

fn fix_storage(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('SDLCALL close fn (', 'close fn (')
	file_contents = file_contents.replace('SDLCALL ready fn (', 'ready fn (')
	file_contents = file_contents.replace('SDLCALL enumerate fn (', 'enumerate fn (')
	file_contents = file_contents.replace('SDLCALL info fn (', 'info fn (')
	file_contents = file_contents.replace('SDLCALL read_file fn (', 'read_file fn (')
	file_contents = file_contents.replace('SDLCALL write_file fn (', 'write_file fn (')
	file_contents = file_contents.replace('SDLCALL mkdir fn (', 'mkdir fn (')
	file_contents = file_contents.replace('SDLCALL remove fn (', 'remove fn (')
	file_contents = file_contents.replace('SDLCALL rename fn (', 'rename fn (')
	file_contents = file_contents.replace('SDLCALL copy fn (', 'copy fn (')
	file_contents = file_contents.replace('SDLCALL space_remaining fn (', 'space_remaining fn (')
	os.write_file(path, file_contents)!
}

fn fix_vulkan(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('const_allocator &C.struct VkAllocationCallbacks',
		'const_allocator VkAllocationCallbacks')
	os.write_file(path, file_contents)!
}

fn fix_revision(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace("pub const revision = 'release-3.2.0-0-g535d80bad (",
		"// TODO: pub const revision = 'release-3.2.0-0-g535d80bad (")
	os.write_file(path, file_contents)!
}

fn fix_hidapi(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}',
		'}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn fix_haptic(path string) ! {
	eprintln('Fixing ${path}...')
	lines := os.read_lines(path) or { panic(err) }
	mut new_lines := []string{}
	for line in lines {
		mut new_line := line
		if new_line.contains(' C.if') {
			new_line = '// TODO: ${new_line}'
		}
		new_lines << new_line
	}
	mut file_contents := new_lines.join('\n')
	// file_contents := os.read_file(path)!
	// file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn fix_version(path string) ! {
	eprintln('Fixing ${path}...')
	lines := os.read_lines(path) or { panic(err) }
	mut new_lines := []string{}
	for line in lines {
		mut new_line := line
		// if new_line.contains(' C.if') {
		//   new_line = '// TODO: ${new_line}'
		// }
		new_lines << new_line
	}
	mut file_contents := new_lines.join('\n')
	// file_contents := os.read_file(path)!
	// file_contents = file_contents.replace('// TODO// struct SDL_hid_device_info*; next\n}','}\n// TODO belongs OVER // struct SDL_hid_device_info*; next')
	os.write_file(path, file_contents)!
}

fn fix_log(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('*userdata voidptr', 'userdata &voidptr')
	os.write_file(path, file_contents)!
}

fn fix_stdinc(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('pub const prilld = SDL_PRILL_PREFIX', '// TODO: pub const prilld = SDL_PRILL_PREFIX')
	file_contents = file_contents.replace('pub const prillu = SDL_PRILL_PREFIX', '// TODO: pub const prillu = SDL_PRILL_PREFIX')
	file_contents = file_contents.replace('pub const prillx = SDL_PRILL_PREFIX', '// TODO: pub const prillx = SDL_PRILL_PREFIX')
	file_contents = file_contents.replace('pub fn malloc(size usize) &C.SDL_MALLOC void{',
		'pub fn malloc(size usize) &C.SDL_MALLOC { // TODO: void ??')
	file_contents = file_contents.replace('pub fn aligned_alloc(alignment usize, size usize) &C.SDL_MALLOC void{',
		'pub fn aligned_alloc(alignment usize, size usize) &C.SDL_MALLOC { // TODO: void ??')
	file_contents = file_contents.replace('fn C.SDL_memcpy(dst &C.SDL_', '// TODO: fn C.SDL_memcpy(dst &C.SDL_')

	file_contents = file_contents.replace('pub fn memcpy(dst &C.SDL_OUT_BYTECAP(len) void, const_src &C.SDL_IN_BYTECAP(len)  void, len usize) voidptr{',
		'// TODO: pub fn memcpy(dst &C.SDL_OUT_BYTECAP(len) void, const_src &C.SDL_IN_BYTECAP(len)  void, len usize) voidptr{
pub fn memcpy(dst voidptr, const_src voidptr, len usize) voidptr{')

	file_contents = file_contents.replace('fn C.SDL_memmove(dst &C.SDL_OUT_BYTECAP(len) void, const_src &C.SDL_IN_BYTECAP(len)  void, len usize) voidptr',
		'fn C.SDL_memmove(dst voidptr, const_src voidptr, len usize) voidptr')

	file_contents = file_contents.replace('pub fn memmove(dst &C.SDL_OUT_BYTECAP(len) void, const_src &C.SDL_IN_BYTECAP(len)  void, len usize) voidptr{',
		'// TODO: pub fn memmove(dst &C.SDL_OUT_BYTECAP(len) void, const_src &C.SDL_IN_BYTECAP(len)  void, len usize) voidptr{
pub fn memmove(dst voidptr, const_src voidptr, len usize) voidptr{')

	file_contents = file_contents.replace('fn C.SDL_memset(dst &C.SDL_OUT_BYTECAP(len) void, c int, len usize) voidptr',
		'fn C.SDL_memset(dst voidptr, c int, len usize) voidptr')

	file_contents = file_contents.replace('pub fn memset(dst &C.SDL_OUT_BYTECAP(len) void, c int, len usize) voidptr{',
		'pub fn memset(dst voidptr, c int, len usize) voidptr{')

	file_contents = file_contents.replace('pub fn wcslcpy(dst &C.SDL_OUT_Z_CAP(maxlen) wchar_t, const_src &C.wchar_t, maxlen usize) usize{',
		'// TODO: pub fn wcslcpy(dst &C.SDL_OUT_Z_CAP(maxlen) wchar_t, const_src &C.wchar_t, maxlen usize) usize{
pub fn wcslcpy(dst wchar_t, const_src &C.wchar_t, maxlen usize) usize{')

	file_contents = file_contents.replace('pub fn wcslcat(dst &C.SDL_INOUT_Z_CAP(maxlen) wchar_t, const_src &C.wchar_t, maxlen usize) usize{',
		'// TODO: pub fn wcslcat(dst &C.SDL_INOUT_Z_CAP(maxlen) wchar_t, const_src &C.wchar_t, maxlen usize) usize{
pub fn wcslcat(dst wchar_t, const_src &C.wchar_t, maxlen usize) usize{')

	file_contents = file_contents.replace(' *endp &C.wchar_t,', ' endp &&C.wchar_t,')

	file_contents = file_contents.replace('pub fn strlcpy(dst &C.SDL_OUT_Z_CAP(maxlen) char, const_src &char, maxlen usize) usize{',
		'// TODO: pub fn strlcpy(dst &C.SDL_OUT_Z_CAP(maxlen) char, const_src &char, maxlen usize) usize{
pub fn strlcpy(dst char, const_src &char, maxlen usize) usize{')

	file_contents = file_contents.replace('pub fn utf8strlcpy(dst &C.SDL_OUT_Z_CAP(dst_bytes) char, const_src &char, dst_bytes usize) usize{',
		'// TODO: pub fn utf8strlcpy(dst &C.SDL_OUT_Z_CAP(dst_bytes) char, const_src &char, dst_bytes usize) usize{
pub fn utf8strlcpy(dst char, const_src &char, dst_bytes usize) usize{')

	file_contents = file_contents.replace('pub fn strlcat(dst &C.SDL_INOUT_Z_CAP(maxlen) char, const_src &char, maxlen usize) usize{',
		'// TODO: pub fn strlcat(dst &C.SDL_INOUT_Z_CAP(maxlen) char, const_src &char, maxlen usize) usize{
pub fn strlcat(dst char, const_src &char, maxlen usize) usize{')

	file_contents = file_contents.replace(') &C.SDL_MALLOC char{', ') &char{')
	file_contents = file_contents.replace('*saveptr &char', 'saveptr &&char')
	file_contents = file_contents.replace('*endp &char', 'endp &&char')
	file_contents = file_contents.replace('const_*pstr &char', 'const_pstr &&char')
	file_contents = file_contents.replace('const_*inbuf &char', 'const_inbuf &&char')
	file_contents = file_contents.replace('*outbuf &char', 'outbuf &&char')
	file_contents = file_contents.replace('pub const iconv_utf8_locale(s) = SDL_iconv_string(',
		'// TODO: pub const iconv_utf8_locale(s) = SDL_iconv_string(')
	file_contents = file_contents.replace('pub const iconv_utf8_ucs2(s) = (Uint16 *)SDL_iconv_string(',
		'// TODO: pub const iconv_utf8_ucs2(s) = (Uint16 *)SDL_iconv_string(')
	file_contents = file_contents.replace('pub const iconv_utf8_ucs4(s) = (Uint32 *)SDL_iconv_string(',
		'// TODO: pub const iconv_utf8_ucs4(s) = (Uint32 *)SDL_iconv_string(')
	file_contents = file_contents.replace('pub const iconv_wchar_utf8(s) = SDL_iconv_string(',
		'// TODO: pub const iconv_wchar_utf8(s) = SDL_iconv_string(')
	file_contents = file_contents.replace('pub type FunctionPointer = voidptr', '')

	file_contents = file_contents.replace('// FunctionPointer is currently undocumented
// @C: typedef void (*SDL_FunctionPointer)(void);
pub type FunctionPointer = fn () ',
		'')

	os.write_file(path, file_contents)!
}

fn fix_iostream(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!

	file_contents = file_contents.replace('SDLCALL size fn', 'size fn')
	file_contents = file_contents.replace('SDLCALL seek fn', 'seek fn')
	file_contents = file_contents.replace('SDLCALL read fn', 'read fn')
	file_contents = file_contents.replace('SDLCALL write fn', 'write fn')
	file_contents = file_contents.replace('SDLCALL flush fn', 'flush fn')
	file_contents = file_contents.replace('SDLCALL close fn', 'close fn')
	os.write_file(path, file_contents)!
}

fn fix_joystick(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('(... /*TODO*/){', '() {\n// TODO HAS ... ARGS')
	file_contents = file_contents.replace('(... /*TODO*/)', '() // TODO HAS ... ARGS')
	// file_contents = file_contents.replace('fn C.SDL_LockJoysticks(...', '// TODO: fn C.SDL_LockJoysticks(...')
	// file_contents = file_contents.replace('fn C.SDL_UnlockJoysticks(...', '// TODO: fn C.SDL_UnlockJoysticks(...')
	file_contents = file_contents.replace('pub fn lock_joysticks(... /*TODO*/', 'pub fn lock_joysticks(')
	file_contents = file_contents.replace('C.SDL_LockJoysticks(...)', 'C.SDL_LockJoysticks() // TODO: fixme HAS ARGS')
	file_contents = file_contents.replace('C.SDL_UnlockJoysticks(...)', 'C.SDL_UnlockJoysticks() // TODO: fixme HAS ARGS')
	// file_contents = file_contents.replace('pub fn unlock_joysticks(... /*TODO*/','pub fn unlock_joysticks(')
	file_contents = file_contents.replace('	SDLCALL ', '\t')
	os.write_file(path, file_contents)!
}

fn fix_mutex(path string) ! {
	eprintln('Fixing ${path}...')
	// lines := os.read_lines(path) or { panic(err) }
	mut file_contents := os.read_file(path)!
	file_contents = file_contents.replace('(... /*TODO*/){', '() {\n// TODO HAS ... ARGS')
	file_contents = file_contents.replace('(... /*TODO*/)', '() // TODO HAS ... ARGS')
	file_contents = file_contents.replace('C.SDL_LockMutex(...)', 'C.SDL_LockMutex() // TODO: fixme HAS ARGS')
	file_contents = file_contents.replace('C.SDL_UnlockMutex(...)', 'C.SDL_UnlockMutex() // TODO: fixme HAS ARGS')
	file_contents = file_contents.replace('C.SDL_LockRWLockForReading(...)', 'C.SDL_LockRWLockForReading() // TODO: fixme HAS ARGS')
	file_contents = file_contents.replace('C.SDL_UnlockRWLockForReading(...)', 'C.SDL_UnlockRWLockForReading() // TODO: fixme HAS ARGS')
	file_contents = file_contents.replace('C.SDL_LockRWLockForWriting(...)', 'C.SDL_LockRWLockForWriting() // TODO: fixme HAS ARGS')
	file_contents = file_contents.replace('C.SDL_UnlockRWLockForWriting(...)', 'C.SDL_UnlockRWLockForWriting() // TODO: fixme HAS ARGS')
	file_contents = file_contents.replace('C.SDL_LockRWLock(...)', 'C.SDL_LockRWLock() // TODO: fixme HAS ARGS')
	file_contents = file_contents.replace('C.SDL_UnlockRWLock(...)', 'C.SDL_UnlockRWLock() // TODO: fixme HAS ARGS')
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
		if new_line.starts_with('import sdl.c') {
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

		if new_line.contains(r'// \returns ') {
			new_line = new_line.replace(r'// \returns ', '// returns ')
		}
		if new_line.contains(r'// \return ') {
			new_line = new_line.replace(r'// \return ', '// returns ')
		}
		if new_line.contains(r'// \since ') {
			new_line = new_line.replace(r'// \since ', '// NOTE: ')
		}
		if new_line.contains(r'// \sa ') {
			new_line = new_line.replace(r'// \sa ', '// See also: ')
			c_fn_name := new_line.all_after('also: ').trim(' ')
			if c_fn_name != '' {
				new_line = new_line.replace(c_fn_name, v_fn_name(c_fn_name) + ' (${c_fn_name})')
			}
		}
		if new_line.contains(r'// \treadsafety ') {
			new_line = new_line.replace(r'// \treadsafety ', '// NOTE: (thread safety) ')
		}
		if new_line.contains(r'// \threadsafety ') {
			new_line = new_line.replace(r'// \threadsafety ', '// NOTE: (thread safety) ')
		}
		if new_line.contains(r'// \param ') {
			param_name := new_line.all_after(r'// \param ').all_before(' ')
			new_line = new_line.replace(r'// \param ', '// `${c_to_v_var_name(param_name)}` ')
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
			if next_line != 'NONONO' {
				if next_line.starts_with('fn C.') {
					c_fn_name := next_line.all_after('fn C.').all_before('(')
					new_line = '// C.${c_fn_name} [official documentation](https://wiki.libsdl.org/SDL3/${c_fn_name})'
				}
				if next_line.starts_with('pub type ') {
					c_typ_name := 'SDL_' + next_line.all_after('pub type ').all_before(' =')
					new_line = '// [Official documentation](https://wiki.libsdl.org/SDL3/${c_typ_name})'
				}
			}
			if new_line.starts_with('// @C: ``') {
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

fn rewrite_define_if_possible(line string) string {
	after_define := line.all_after('#define ').trim(' ')
	if after_define.starts_with('SDL_') && after_define.ends_with('_h_') {
		return ''
	}
	ident_and_rest := after_define.all_after('SDL_')
	ident := ident_and_rest.all_before(' ')
	ident_low := ident_and_rest.all_before(' ').to_lower()
	value := ident_and_rest.all_after(' ').trim(' ')

	if ident_low.contains('(') || ident_low.contains(')') {
		eprintln('Skipping function: ${line}')
		return line
	}

	if after_define.starts_with('SDL_INIT_') || after_define.starts_with('SDL_TRAYENTRY_')
		|| after_define.starts_with('SDL_WINDOWPOS_') || after_define.starts_with('SDL_SURFACE_')
		|| after_define.starts_with('SDL_STANDARD_') || after_define.starts_with('SDL_ALPHA_')
		|| after_define.starts_with('SDL_SCANCODE_') || after_define.starts_with('SDLK_')
		|| after_define.starts_with('SDL_KMOD_') || after_define.starts_with('SDL_NS_PER_')
		|| after_define.starts_with('SDL_MESSAGEBOX_') || after_define.starts_with('SDL_BLENDMODE_')
		|| after_define.starts_with('SDL_TOUCH_') || after_define.starts_with('SDL_MOUSE_')
		|| after_define.starts_with('SDL_PEN_') || after_define.starts_with('SDL_MAX_')
		|| after_define.starts_with('SDL_MIN_') || after_define.starts_with('SDL_ICONV_')
		|| after_define.starts_with('SDL_AUDIO_MASK_') || after_define.starts_with('SDL_PI_')
		|| after_define.starts_with('SDL_GPU_') || after_define.starts_with('SDL_HAT_')
		|| after_define.starts_with('SDL_WINAPI_FAMILY_') || after_define.starts_with('SDL_HAPTIC_')
		|| after_define.starts_with('SDL_RENDERER_VSYNC_')
		|| after_define.starts_with('SDL_PROP_GAMEPAD_') || after_define.starts_with('SDL_BUTTON_')
		|| after_define.starts_with('SDL_WINDOW_') {
		// ||  after_define.starts_with('SDL_PIXELFORMAT_')
		// || after_define.starts_with('')

		mut v_value := 'C.SDL_${ident} // ${value}'
		if after_define.starts_with('SDL_INIT_') {
			v_value = 'u32(C.SDL_${ident}) // ${value}'
			return 'pub const ${ident_low} = ${v_value}'
		}
		return 'pub const ${ident_low} = ${v_value}'
	}
	// eprintln(after_define)
	return line
}

fn v_fn_name(c_fn_name string) string {
	c_fn_name_sanitized := c_fn_name.replace('SDL_', '')

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
