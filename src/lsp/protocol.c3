module lsp::protocol;
import json;
import std::collections::list;

alias LSPRequestId = String;

struct LSPRequest
{
	String jsonrpc;
	LSPRequestId id;
	String method;
	String params;
}

struct LSPResponse  
{
	String jsonrpc;
	LSPRequestId id;
	String result;
	String error;
}

struct LSPNotification
{
	String jsonrpc;
	String method;
	String params;
}

struct LSPError
{
	int code;
	String message;
	String data;
}

enum LSPErrorCode : int (int value)
{
	PARSE_ERROR = -32700,
	INVALID_REQUEST = -32600,
	METHOD_NOT_FOUND = -32601,
	INVALID_PARAMS = -32602,
	INTERNAL_ERROR = -32603,
	
	REQUEST_FAILED = -32803,
	SERVER_CANCELLED = -32802,
	CONTENT_MODIFIED = -32801,
	REQUEST_CANCELLED = -32800
}

fn LSPRequest? parse_request(String json_str, Allocator allocator)
{
	return json::unmarshal(LSPRequest, json_str, allocator);
}

fn LSPNotification? parse_notification(String json_str, Allocator allocator)
{
	return json::unmarshal(LSPNotification, json_str, allocator);
}

fn String? marshal_response(LSPResponse response, Allocator allocator)
{
	@pool()
	{
		DString output = dstring::temp_with_capacity(512);
		json::marshal(response, &output)!;
		return output.copy_str(allocator);
	};
}

fn String? marshal_notification(LSPNotification notification, Allocator allocator)
{
	@pool()
	{
		DString output = dstring::temp_with_capacity(512);
		json::marshal(notification, &output)!;
		return output.copy_str(allocator);
	};
}

fn LSPResponse create_response(LSPRequestId id, String result)
{
	return {
		.jsonrpc = "2.0",
		.id = id,
		.result = result,
		.error = ""
	};
}

fn LSPResponse? create_error_response(LSPRequestId id, LSPErrorCode code, String message)
{
	LSPError error = {
		.code = (int)code,
		.message = message,
		.data = ""
	};
	
	@pool()
	{
		DString error_output = dstring::temp_with_capacity(256);
		json::marshal(error, &error_output)!;
		
		return {
			.jsonrpc = "2.0",
			.id = id,
			.result = "",
			.error = error_output.str_view()
		};
	};
}

fn LSPNotification create_notification(String method, String params)
{
	return {
		.jsonrpc = "2.0",
		.method = method,
		.params = params
	};
}