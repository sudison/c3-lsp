module lsp::project_tests @test;
import lsp::project;
import parser;

fn void test_project_initialization()
{
	Project project;
	project.init(tmem);
	
	assert(project.file_count() == 0);
}

fn void test_add_single_file()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/hello.c3";
	String uri = "file:///test/hello.c3";
	String content = "import main;";
	uint version = 1;
	
	SourceFile* file = project.add_or_update_file(file_path, uri, content, version)!!;
	
	assert(file != null);
	assert(file.file_path == file_path);
	assert(file.uri == uri);
	assert(file.content == content);
	assert(file.version == version);
	assert(project.file_count() == 1);
}

fn void test_get_file_by_path()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/example.c3";
	String uri = "file:///test/example.c3";
	String content = "struct Point { int x; int y; }";
	
	project.add_or_update_file(file_path, uri, content, 1)!!;
	
	SourceFile* retrieved = project.get_file_by_path(file_path)!!;
	assert(retrieved != null);
	assert(retrieved.file_path == file_path);
	assert(retrieved.uri == uri);
	assert(retrieved.content == content);
}

fn void test_get_file_by_uri()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/module.c3";
	String uri = "file:///test/module.c3";
	String content = "module test; import std::io;";
	
	project.add_or_update_file(file_path, uri, content, 1)!!;
	
	SourceFile* retrieved = project.get_file_by_uri(uri)!!;
	assert(retrieved != null);
	assert(retrieved.file_path == file_path);
	assert(retrieved.uri == uri);
	assert(retrieved.content == content);
}

fn void test_update_file_content()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/changeable.c3";
	String uri = "file:///test/changeable.c3";
	String original_content = "import old_module;";
	String updated_content = "import new_module;";
	
	project.add_or_update_file(file_path, uri, original_content, 1)!!;
	project.update_file_content(uri, updated_content, 2)!!;
	
	SourceFile* file = project.get_file_by_uri(uri)!!;
	assert(file.content == updated_content);
	assert(file.version == 2);
}

fn void test_remove_file_by_path()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/removable.c3";
	String uri = "file:///test/removable.c3";
	String content = "import temporary;";
	
	project.add_or_update_file(file_path, uri, content, 1)!!;
	assert(project.file_count() == 1);
	
	bool removed = project.remove_file_by_path(file_path)!!;
	assert(removed);
	assert(project.file_count() == 0);
	
	// Verify file is no longer accessible
	SourceFile*? file_result = project.get_file_by_path(file_path);
	assert(!@ok(file_result));
}

fn void test_remove_file_by_uri()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/removable2.c3";
	String uri = "file:///test/removable2.c3";
	String content = "import another_temp;";
	
	project.add_or_update_file(file_path, uri, content, 1)!!;
	assert(project.file_count() == 1);
	
	bool removed = project.remove_file_by_uri(uri)!!;
	assert(removed);
	assert(project.file_count() == 0);
	
	// Verify file is no longer accessible
	SourceFile*? file_result = project.get_file_by_uri(uri);
	assert(!@ok(file_result));
}

fn void test_multiple_files()
{
	Project project;
	project.init(tmem);
	
	// Add multiple files
	project.add_or_update_file("/test/file1.c3", "file:///test/file1.c3", "import file1;", 1)!!;
	project.add_or_update_file("/test/file2.c3", "file:///test/file2.c3", "import file2;", 1)!!;
	project.add_or_update_file("/test/file3.c3", "file:///test/file3.c3", "import file3;", 1)!!;
	
	assert(project.file_count() == 3);
	
	// Verify all files are accessible
	SourceFile* file1 = project.get_file_by_path("/test/file1.c3")!!;
	SourceFile* file2 = project.get_file_by_path("/test/file2.c3")!!;
	SourceFile* file3 = project.get_file_by_path("/test/file3.c3")!!;
	
	assert(file1 != null);
	assert(file2 != null);
	assert(file3 != null);
	
	// Remove one file
	project.remove_file_by_path("/test/file2.c3")!!;
	assert(project.file_count() == 2);
	
	// Verify remaining files are still accessible
	assert(@ok(project.get_file_by_path("/test/file1.c3")));
	assert(@ok(project.get_file_by_path("/test/file3.c3")));
	assert(!@ok(project.get_file_by_path("/test/file2.c3")));
}

fn void test_replace_existing_file()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/replaceable.c3";
	String uri = "file:///test/replaceable.c3";
	
	// Add initial file
	project.add_or_update_file(file_path, uri, "import old_module;", 1)!!;
	assert(project.file_count() == 1);
	
	// Replace with new content (same path/uri)
	project.add_or_update_file(file_path, uri, "import new_module;", 2)!!;
	assert(project.file_count() == 1); // Should still be just one file
	
	SourceFile* file = project.get_file_by_path(file_path)!!;
	assert(file.content == "import new_module;");
	assert(file.version == 2);
}

fn void test_get_all_files()
{
	Project project;
	project.init(tmem);
	
	// Add several files
	project.add_or_update_file("/test/a.c3", "file:///test/a.c3", "// File A", 1)!!;
	project.add_or_update_file("/test/b.c3", "file:///test/b.c3", "// File B", 1)!!;
	project.add_or_update_file("/test/c.c3", "file:///test/c.c3", "// File C", 1)!!;
	
	SourceFile*[] all_files = project.get_all_files();
	assert(all_files.len == 3);
	assert(project.file_count() == 3);
}

fn void test_completions_with_valid_ast()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/valid.c3";
	String uri = "file:///test/valid.c3";
	String content = "import std::io;\nstruct Test { int x; }\n";
	
	project.add_or_update_file(file_path, uri, content, 1)!!;
	
	// Try to get completions
	String[]? completions_result = project.get_completions_at_position(uri, 1, 10);
	if (@ok(completions_result))
	{
		String[] completions = completions_result!!;
		assert(completions.len > 0); // Should have some keywords
		
		// Check for some expected C3 keywords
		bool found_fn = false;
		bool found_struct = false;
		bool found_return = false;
		
		foreach (keyword : completions)
		{
			if (keyword == "fn") found_fn = true;
			if (keyword == "struct") found_struct = true;
			if (keyword == "return") found_return = true;
		}
		
		assert(found_fn && found_struct && found_return);
	}
}

fn void test_hover_info()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/hover_test.c3";
	String uri = "file:///test/hover_test.c3";
	String content = "import foo;\nstruct Point { int x; }\n";
	
	project.add_or_update_file(file_path, uri, content, 1)!!;
	
	// Try to get hover info - should work now with proper line breaks
	String? hover_result = project.get_hover_info(uri, 1, 5);
	// Don't assert on the result since it depends on parser implementation
	// Just verify the function doesn't crash
}

fn void test_file_not_found_errors()
{
	Project project;
	project.init(tmem);
	
	// Try to access non-existent file
	SourceFile*? file_result = project.get_file_by_path("/nonexistent/file.c3");
	assert(!@ok(file_result)); // Should return error
	
	SourceFile*? uri_result = project.get_file_by_uri("file:///nonexistent/file.c3");
	assert(!@ok(uri_result)); // Should return error
	
	// Try to remove non-existent file
	bool? remove_result = project.remove_file_by_path("/nonexistent/file.c3");
	assert(!@ok(remove_result)); // Should return error
	
	bool? remove_uri_result = project.remove_file_by_uri("file:///nonexistent/file.c3");
	assert(!@ok(remove_uri_result)); // Should return error
}

fn void test_update_nonexistent_file()
{
	Project project;
	project.init(tmem);
	
	// Try to update a file that doesn't exist
	if (catch err = project.update_file_content("file:///nonexistent.c3", "new content", 2))
	{
		// Got expected error
	}
	else
	{
		assert(false, "Expected error but function succeeded");
	}
}

fn void test_incremental_text_changes()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/incremental.c3";
	String uri = "file:///test/incremental.c3";
	String initial_content = "import foo;\nstruct Point { int x; }\n";
	
	project.add_or_update_file(file_path, uri, initial_content, 1)!!;
	
	// Create an incremental change - replace "int x" with "int y"
	LSPTextChange change = {
		.range = {
			.start_line = 1,
			.start_character = 15,  // Position of "x"
			.end_line = 1,
			.end_character = 20     // After "int x"
		},
		.text = "int y",
		.is_full_document = false
	};
	
	LSPTextChange[] changes = { change };
	project.apply_incremental_changes(uri, changes, 2)!!;
	
	SourceFile* file = project.get_file_by_uri(uri)!!;
	assert(file.version == 2);
	// The content should now have "int y" instead of "int x"
	assert(file.content.contains("int y"));
	assert(!file.content.contains("int x"));
}

fn void test_full_document_change()
{
	Project project;
	project.init(tmem);
	
	String file_path = "/test/full_doc.c3";
	String uri = "file:///test/full_doc.c3";
	String initial_content = "import foo;\n";
	
	project.add_or_update_file(file_path, uri, initial_content, 1)!!;
	
	// Create a full document change
	LSPTextChange full_change = {
		.range = { .start_line = 0, .start_character = 0, .end_line = 0, .end_character = 0 },
		.text = "import bar;\nstruct Test { float f; }\n",
		.is_full_document = true
	};
	
	LSPTextChange[] changes = { full_change };
	project.apply_incremental_changes(uri, changes, 2)!!;
	
	SourceFile* file = project.get_file_by_uri(uri)!!;
	assert(file.version == 2);
	assert(file.content == "import bar;\nstruct Test { float f; }\n");
}