module lsp::transport_tests @test;
import lsp::transport;
import std::io;

fn void test_read_simple_lsp_message()
{
	// Create test LSP message with proper headers and correct length
	String json_content = `{"jsonrpc":"2.0","method":"test","params":{}}`;
	@pool()
	{
		DString msg_builder = dstring::temp_with_capacity(200);
		msg_builder.appendf("Content-Length: %d\r\n\r\n%s", json_content.len, json_content);
		String test_message = msg_builder.str_view();
		
		ByteReader input;
		input.init(test_message);
		
		ByteWriter output;
		output.tinit();
		defer (void)output.destroy();
		
		LSPTransport transport;
		transport.init(&input, &output, tmem);
		
		// Read the message
		LSPMessage msg = transport.read_message()!!;
		
		assert(msg.content_length == json_content.len, "Content length should match");
		assert(msg.content == json_content, "Content should match");
		assert(msg.content_type == "application/vscode-jsonrpc; charset=utf-8", "Should have default content type");
	};
}

fn void test_read_lsp_message_with_content_type()
{
	// Create test LSP message with custom content type
	String json_content = `{"jsonrpc":"2.0","method":"test"}`;
	@pool()
	{
		DString msg_builder = dstring::temp_with_capacity(200);
		msg_builder.appendf("Content-Type: application/json\r\nContent-Length: %d\r\n\r\n%s", json_content.len, json_content);
		String test_message = msg_builder.str_view();
		
		ByteReader input;
		input.init(test_message);
		
		ByteWriter output;
		output.tinit();
		defer (void)output.destroy();
		
		LSPTransport transport;
		transport.init(&input, &output, tmem);
		
		// Read the message
		LSPMessage msg = transport.read_message()!!;
		
		assert(msg.content_length == json_content.len, "Content length should match");
		assert(msg.content == json_content, "Content should match");
		assert(msg.content_type == "application/json", "Should have custom content type");
	};
}

fn void test_write_lsp_message()
{
	ByteReader input;
	input.init("");
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPTransport transport;
	transport.init(&input, &output, tmem);
	
	// Write a message
	String json_content = `{"jsonrpc":"2.0","method":"test"}`;
	transport.write_message(json_content)!!;
	
	// Verify output
	String written = output.str_view();
	// Check that it starts with Content-Length header
	assert(written.starts_with("Content-Length:"), "Should start with Content-Length header");
	assert(written.contains(`{"jsonrpc":"2.0","method":"test"}`), "Should contain JSON content");
}

fn void test_read_invalid_content_length()
{
	// Test with invalid content length
	String test_message = "Content-Length: invalid\r\n\r\ntest";
	
	ByteReader input;
	input.init(test_message);
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPTransport transport;
	transport.init(&input, &output, tmem);
	
	// Should fail to read message
	LSPMessage? msg = transport.read_message();
	assert(!@ok(msg), "Should fail with invalid content length");
}

fn void test_read_missing_content_length()
{
	// Test with missing content length header
	String test_message = "Content-Type: application/json\r\n\r\ntest";
	
	ByteReader input;
	input.init(test_message);
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPTransport transport;
	transport.init(&input, &output, tmem);
	
	// Should fail to read message
	LSPMessage? msg = transport.read_message();
	assert(!@ok(msg), "Should fail with missing content length");
}

fn void test_read_content_too_large()
{
	// Test with content length exceeding maximum
	String test_message = "Content-Length: 99999999999\r\n\r\ntest";
	
	ByteReader input;
	input.init(test_message);
	
	ByteWriter output;
	output.tinit();
	defer (void)output.destroy();
	
	LSPTransport transport;
	transport.init(&input, &output, tmem);
	
	// Should fail to read message
	LSPMessage? msg = transport.read_message();
	assert(!@ok(msg), "Should fail with content too large");
}