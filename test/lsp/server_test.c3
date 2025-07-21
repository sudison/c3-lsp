module lsp::server_tests;
import lsp::server;
import lsp::protocol;
import lsp::project;
import std::io;

fn void test_server_initialization() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	assert(!server.initialized);
	assert(!server.shutdown_requested);
	assert(server.project.file_count() == 0);
}

fn void test_handle_initialize_request() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String initialize_json = `{"jsonrpc":"2.0","id":"1","method":"initialize","params":"{}"}`;;
	
	server.handle_message(initialize_json)!!;
	
	// Check that output contains a response
	String response = output.str_view();
	assert(response.contains("capabilities"));
	assert(response.contains("textDocumentSync"));
	assert(response.contains("completionProvider"));
	assert(response.contains("hoverProvider"));
}

fn void test_handle_shutdown_request() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String shutdown_json = `{"jsonrpc":"2.0","id":"2","method":"shutdown","params":"null"}`;;
	
	server.handle_message(shutdown_json)!!;
	
	// Should have set shutdown flag
	assert(server.shutdown_requested, "Shutdown flag is %s", server.shutdown_requested ? "true" : "false");
	
	// Check that output contains null result (LSP message format)
	String response = output.str_view();
	assert(response.contains("Content-Length:"), "Should have LSP headers");
	assert(response.contains("\"result\":\"null\""), "Should contain null result");
}

fn void test_handle_did_open_notification() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String did_open_json = `{"jsonrpc":"2.0","method":"textDocument/didOpen","params":"{\"textDocument\":{\"uri\":\"file:///test.c3\",\"languageId\":\"c3\",\"version\":1,\"text\":\"import std::io;\"}}"}`;
	
	io::printfn("Before handle_message, file count: %d", server.project.file_count());
	server.handle_message(did_open_json)!!;
	io::printfn("After handle_message, file count: %d", server.project.file_count());
	
	// Should have added file to project
	assert(server.project.file_count() == 1, "File count is %d", server.project.file_count());
	
	SourceFile* file = server.project.get_file_by_uri("file:///test.c3")!!;
	assert(file.content == "import std::io;");
	assert(file.version == 1);
}

fn void test_handle_did_change_notification() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String did_open_json = `{"jsonrpc":"2.0","method":"textDocument/didOpen","params":"{\"textDocument\":{\"uri\":\"file:///test.c3\",\"languageId\":\"c3\",\"version\":1,\"text\":\"import std::io;\"}}"}`;
	String did_change_json = `{"jsonrpc":"2.0","method":"textDocument/didChange","params":"{\"textDocument\":{\"uri\":\"file:///test.c3\",\"version\":2},\"contentChanges\":[{\"text\":\"import std::core;\"}]}"}`;
	
	// First add a file
	server.handle_message(did_open_json)!!;
	
	// Then change it
	server.handle_message(did_change_json)!!;
	
	// Should have updated the file content
	SourceFile* file = server.project.get_file_by_uri("file:///test.c3")!!;
	assert(file.content == "import std::core;");
	assert(file.version == 2);
}

fn void test_handle_did_close_notification() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String did_open_json = `{"jsonrpc":"2.0","method":"textDocument/didOpen","params":"{\"textDocument\":{\"uri\":\"file:///test.c3\",\"languageId\":\"c3\",\"version\":1,\"text\":\"import std::io;\"}}"}`;
	String did_close_json = `{"jsonrpc":"2.0","method":"textDocument/didClose","params":"{\"textDocument\":{\"uri\":\"file:///test.c3\"}}"}`;
	
	// First add a file
	server.handle_message(did_open_json)!!;
	assert(server.project.file_count() == 1);
	
	// Then close it
	server.handle_message(did_close_json)!!;
	
	// Should have removed the file
	assert(server.project.file_count() == 0);
}

fn void test_handle_completion_request() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String did_open_json = `{"jsonrpc":"2.0","method":"textDocument/didOpen","params":"{\"textDocument\":{\"uri\":\"file:///test.c3\",\"languageId\":\"c3\",\"version\":1,\"text\":\"import std::io;\\nstruct Test { int x; }\"}}"}`;
	
	String completion_json = `{"jsonrpc":"2.0","id":"3","method":"textDocument/completion","params":"{\"textDocument\":{\"uri\":\"file:///test.c3\"},\"position\":{\"line\":1,\"character\":10}}"}`;
	
	// First add a file
	if (catch err = server.handle_message(did_open_json))
	{
		io::printfn("Error: %s",err);
	}

	// Request completions
	if (catch err = server.handle_message(completion_json)) {
		io::printfn("Error: %s",err);
	}

	// Should have sent a completion response
	String response = output.str_view();
	assert(response.contains("Content-Length:"), "Should have LSP headers");
	assert(response.contains("items"), "Should contain items field");
	// Should have some completions (struct, fn, etc.)
	assert(response.contains("struct") || response.contains("fn"), "Should contain completions");
}

fn void test_handle_hover_request() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String did_open_json = `{"jsonrpc":"2.0","method":"textDocument/didOpen","params":"{\"textDocument\":{\"uri\":\"file:///test.c3\",\"languageId\":\"c3\",\"version\":1,\"text\":\"import std::io;\\nstruct Test { int x; }\"}}"}`;
	String hover_json = `{"jsonrpc":"2.0","id":"4","method":"textDocument/hover","params":"{\"textDocument\":{\"uri\":\"file:///test.c3\"},\"position\":{\"line\":1,\"character\":5}}"}`;
	
	// First add a file
	server.handle_message(did_open_json)!!;
	
	// Request hover info
	server.handle_message(hover_json)!!;
	
	// Should have sent a hover response
	String response = output.str_view();
	assert(response.contains("Content-Length:"), "Should have LSP headers");
	// Response should be either null or contain hover info
	assert(response.contains("null") || response.contains("contents"), "Should contain hover response");
}

fn void test_handle_unknown_method() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String unknown_json = `{"jsonrpc":"2.0","id":"5","method":"unknown/method","params":"{}"}`;
	
	server.handle_message(unknown_json)!!;
	
	// Should have sent an error response
	String response = output.str_view();
	assert(response.contains("Content-Length:"), "Should have LSP headers");
	assert(response.contains("error"), "%s", response);
	assert(response.contains("Method not found"), "%s", response);
}

fn void test_is_notification_detection() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	// Test request (has id)
	String request = `{"id":"1","method":"initialize","params":{}}`;
	assert(!server.is_notification(request));
	
	// Test notification (no id)
	String notification = `{"method":"textDocument/didOpen","params":{}}`;
	assert(server.is_notification(notification));
	
	// Test notification with id in string content (should still be detected as notification)
	String tricky_notification = `{"method":"textDocument/didOpen","params":{"text":"some id: value"}}`;
	assert(server.is_notification(tricky_notification));
}

fn void test_completion_with_nonexistent_file() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String completion_json = `{"jsonrpc":"2.0","id":"6","method":"textDocument/completion","params":"{\"textDocument\":{\"uri\":\"file:///nonexistent.c3\"},\"position\":{\"line\":0,\"character\":0}}"}`;
	
	server.handle_message(completion_json)!!;
	
	// Should have sent an empty completion response
	String response = output.str_view();
	assert(response.contains("Content-Length:"), "Should have LSP headers");
	assert(response.contains("items"), "Should contain items field");
	assert(response.contains("[]"), "Should contain empty array"); // Empty items array
}

fn void test_hover_with_nonexistent_file() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String hover_json = `{"jsonrpc":"2.0","id":"7","method":"textDocument/hover","params":"{\"textDocument\":{\"uri\":\"file:///nonexistent.c3\"},\"position\":{\"line\":0,\"character\":0}}"}`;
	
	// Test JSON parsing first
	io::printfn("Testing hover_json: %s", hover_json);
	LSPRequest request = protocol::parse_request(hover_json, tmem)!!;
	io::printfn("Parsed request method: %s", request.method);
	io::printfn("Parsed request params: %s", request.params);
	
	server.handle_message(hover_json)!!;
	
	// Should have sent a null hover response
	String response = output.str_view();
	assert(response.contains("Content-Length:"), "Should have LSP headers");
	assert(response.contains("null"), "Should contain null response");
}

fn void test_file_uri_path_conversion() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String did_open_json = `{"jsonrpc":"2.0","method":"textDocument/didOpen","params":"{\"textDocument\":{\"uri\":\"file:///path/to/test.c3\",\"languageId\":\"c3\",\"version\":1,\"text\":\"import std::io;\"}}"}`;
	
	server.handle_message(did_open_json)!!;
	
	// Should have added file with converted path
	assert(server.project.file_count() == 1);
	
	// Should be accessible by both URI and converted path
	SourceFile* file_by_uri = server.project.get_file_by_uri("file:///path/to/test.c3")!!;
	SourceFile* file_by_path = server.project.get_file_by_path("/path/to/test.c3")!!;
	
	assert(file_by_uri == file_by_path);
	assert(file_by_uri.file_path == "/path/to/test.c3");
	assert(file_by_uri.uri == "file:///path/to/test.c3");
}

fn void test_initialized_notification() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String initialized_json = `{"jsonrpc":"2.0","method":"initialized","params":"{}"}`;
	
	assert(!server.initialized);
	
	server.handle_message(initialized_json)!!;
	
	// Should have set initialized flag
	assert(server.initialized);
}

fn void test_exit_notification() @test
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPServer server;
	server.init(&input, &output, tmem);
	defer server.free();
	
	String exit_json = `{"jsonrpc":"2.0","method":"exit","params":"{}"}`;
	
	io::printfn("Before handle_message, shutdown_requested: %s", server.shutdown_requested ? "true" : "false");
	io::printfn("is_notification result: %s", server.is_notification(exit_json) ? "true" : "false");
	assert(!server.shutdown_requested);
	
	// Let's see what the parsed notification contains
	LSPNotification notification = protocol::parse_notification(exit_json, tmem)!!;
	io::printfn("Parsed notification method: '%s'", notification.method);
	io::printfn("Parsed notification params: '%s'", notification.params);
	
	// Try calling handle_notification directly to see if JSON parsing is the issue
	if (catch err = server.handle_notification(exit_json))
	{
		io::printfn("handle_notification failed with error");
	}
	else
	{
		io::printfn("handle_notification succeeded");
	}
	io::printfn("After handle_notification, shutdown_requested: %s", server.shutdown_requested ? "true" : "false");
	
	server.handle_message(exit_json)!!;
	io::printfn("After handle_message, shutdown_requested: %s", server.shutdown_requested ? "true" : "false");
	
	// Should have set shutdown flag
	assert(server.shutdown_requested, "Shutdown flag is %s", server.shutdown_requested ? "true" : "false");
}