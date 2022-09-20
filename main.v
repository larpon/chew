// Copyright(C) 2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module main

import os
import chew.parser as chep

fn main() {
	input_path := os.args[1]
	output_path := os.args[2]
	config_path := os.args[3]

	if !os.exists(output_path) {
		os.mkdir_all(output_path) or { panic(err) }
	}

	mut c_headers := []string{}
	if os.is_file(input_path) {
		c_headers << input_path
	} else {
		c_headers = os.walk_ext(input_path, '.h')
	}

	conf := chep.config_from_toml(config_path)
	mut parser := chep.Parser{
		conf: conf
	}
	for c_header in c_headers {
		parser.parse_file(c_header)
	}

	lib_name := conf.lib_name
	for file in parser.files {
		mut v_code := ''
		mut file_name := os.file_name(file.path).all_before_last('.').to_lower()
		if c_headers.len > 1 {
			prefix_id := conf.struct_id_prefix.to_lower()
			file_name += file_name.all_after(prefix_id)
			file_name = '${lib_name}.$file_name'
		}

		v_code += parser.file_to_v_code(file)!

		// Write file to disk before fmt
		tmp_path := os.temp_dir()
		os.write_file(os.real_path(os.join_path(tmp_path, '${file_name}.auto.pre-fmt.c.v')),
			v_code) or { panic(err) }

		// v_code = chep.vfmt(v_code) // or {	}
		os.write_file(os.real_path(os.join_path(output_path, '${file_name}.auto.c.v')),
			v_code) or { panic(err) }
	}
}
