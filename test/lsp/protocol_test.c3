module lsp::protocol_tests @test;
import lsp::protocol;
import json;

fn void test_parse_valid_request()
{
	String json_str = `{"jsonrpc":"2.0","id":"1","method":"initialize","params":"{}"}`;
	
	LSPRequest request = protocol::parse_request(json_str, tmem)!!;
	
	assert(request.jsonrpc == "2.0", "Should have correct jsonrpc version");
	assert(request.id == "1", "Should have correct ID");
	assert(request.method == "initialize", "Should have correct method");
	assert(request.params.len > 0, "Should have params");
}

fn void test_parse_valid_notification()
{
	String json_str = `{"jsonrpc":"2.0","method":"initialized","params":"{}"}`;
	
	LSPNotification notification = protocol::parse_notification(json_str, tmem)!!;
	
	assert(notification.jsonrpc == "2.0", "Should have correct jsonrpc version");
	assert(notification.method == "initialized", "Should have correct method");
	assert(notification.params.len > 0, "Should have params");
}

fn void test_marshal_response()
{
	LSPResponse response = protocol::create_response("1", `{"capabilities":{}}`);
	
	String json_str = protocol::marshal_response(response, tmem)!!;
	
	assert(json_str.contains(`"jsonrpc":"2.0"`), "Should contain jsonrpc version");
	assert(json_str.contains(`"id":"1"`), "Should contain ID");
	assert(json_str.contains(`"result"`), "Should contain result");
}

fn void test_marshal_notification()
{
	LSPNotification notification = protocol::create_notification("test", `{}`);
	
	String json_str = protocol::marshal_notification(notification, tmem)!!;
	
	assert(json_str.contains(`"jsonrpc":"2.0"`), "Should contain jsonrpc version");
	assert(json_str.contains(`"method":"test"`), "Should contain method");
	assert(json_str.contains(`"params"`), "Should contain params");
}

fn void test_create_error_response()
{
	LSPResponse error_response = protocol::create_error_response("1", protocol::LSPErrorCode.METHOD_NOT_FOUND, "Method not found")!!;
	
	assert(error_response.jsonrpc == "2.0", "Should have correct jsonrpc version");
	assert(error_response.id == "1", "Should have correct ID");
	assert(error_response.result == "", "Should have empty result");
	assert(error_response.error.len > 0, "Should have error content");
}