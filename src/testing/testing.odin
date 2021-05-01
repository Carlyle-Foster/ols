package ols_testing

import "core:testing"
import "core:mem"
import "core:fmt"
import "core:strings"

import "shared:server"
import "shared:index"
import "shared:common"

Package_Source :: struct {
	pkg_name: string,
	source:   string,
}

Source :: struct {
	main:            string,
	source_packages: Package_Source,
	document:        ^server.Document,
	collections:     map[string]string,
	config:          common.Config,
	position:        common.Position,
}

@(private)
setup :: proc(src: ^Source) {

	src.main = strings.clone(src.main);
	src.document = new(server.Document, context.temp_allocator);
	src.document.uri = common.create_uri("test/test.odin", context.temp_allocator);
	src.document.client_owned = true;
	src.document.text = transmute([]u8)src.main;
	src.document.used_text = len(src.document.text);
	src.document.allocator = new(common.Scratch_Allocator);
	src.document.package_name = "test";

	common.scratch_allocator_init(src.document.allocator, mem.kilobytes(20), context.temp_allocator);

	server.document_refresh(src.document, &src.config, nil);

	//no unicode in tests currently
	current, last:                   u8;
	current_line, current_character: int;

	for current_index := 0; current_index < len(src.main); current_index += 1 {
		current = src.main[current_index];

		if last == '\r' {
			current_line += 1;
			current_character = 0;
		} else if current == '\n' {
			current_line += 1;
			current_character = 0;
		} else if current == '*' {
			dst_slice := transmute([]u8)src.main[current_index:];
			src_slice := transmute([]u8)src.main[current_index + 1:];
			copy(dst_slice, src_slice);
			src.position.character = current_character;
			src.position.line = current_line;
			break;
		} else {
			current_character += 1;
		}

		last = current;
	}

}

expect_signature_labels :: proc(t: ^testing.T, src: ^Source, expect_labels: []string) {
	setup(src);

	help, ok := server.get_signature_information(src.document, src.position);

	if !ok {
		testing.error(t, "Failed get_signature_information");
	}

	if len(expect_labels) == 0 && len(help.signatures) > 0 {
		testing.errorf(t, "Expected empty signature label, but received %v", help.signatures);
	}

	flags := make([]int, len(expect_labels));

	for expect_label, i in expect_labels {
		for signature, j in help.signatures {
			if expect_label == signature.label {
				flags[i] += 1;
			}
		}
	}

	for flag, i in flags {
		if flag != 1 {
			testing.errorf(t, "Expected signature label %v, but received %v", expect_labels[i], help.signatures);
		}
	}

}

expect_completion_details :: proc(t: ^testing.T, src: ^Source, trigger_character: string, expect_details: []string) {
	setup(src);

	completion_context := server.CompletionContext {
		triggerCharacter = trigger_character,
	};

	completion_list, ok := server.get_completion_list(src.document, src.position, completion_context);

	if !ok {
		testing.error(t, "Failed get_completion_list");
	}

	if len(expect_details) == 0 && len(completion_list.items) > 0 {
		testing.errorf(t, "Expected empty completion label, but received %v", completion_list.items);
	}

	flags := make([]int, len(expect_details));

	for expect_detail, i in expect_details {
		for completion, j in completion_list.items {
			if expect_detail == completion.detail {
				flags[i] += 1;
			}
		}
	}

	for flag, i in flags {
		if flag != 1 {
			testing.errorf(t, "Expected completion label %v, but received %v", expect_details[i], completion_list.items);
		}
	}

}

expect_hover :: proc(t: ^testing.T, src: ^Source, expect_hover_string: string) {
	setup(src);

	hover, ok := server.get_hover_information(src.document, src.position);

	if !ok {
		testing.error(t, "Failed get_hover_information");
	}

	if expect_hover_string == "" && hover.contents.value != "" {
		testing.errorf(t, "Expected empty hover string, but received %v", hover.contents.value);
	}

	if strings.contains(expect_hover_string, hover.contents.value) {
		testing.errorf(t, "Expected hover string %v, but received %v", expect_hover_string, hover.contents.value);
	}

}
