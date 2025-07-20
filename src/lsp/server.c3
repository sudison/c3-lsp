module lsp::server;
import lsp::protocol;
import lsp::transport;
import std::io;
import json;

struct LSPServer
{
	bool initialized;
	bool shutdown_requested;
	LSPTransport transport;
}

fn LSPServer* LSPServer.init(&self, InStream input, OutStream output, Allocator allocator)
{
	self.initialized = false;
	self.shutdown_requested = false;
	self.transport.init(input, output, allocator);
	return self;
}

fn LSPServer* LSPServer.init_stdio(&self, Allocator allocator)
{
	self.initialized = false;
	self.shutdown_requested = false;
	self.transport.init_stdio(allocator);
	return self;
}

fn void? LSPServer.run(&self)
{
	while (!self.shutdown_requested)
	{
		LSPMessage? msg = self.transport.read_message();
		if (catch err = msg)
		{
			if (err == io::EOF) break;
			self.send_error_response("", protocol::LSPErrorCode.PARSE_ERROR, "Failed to read message")!;
			continue;
		}
		
		self.handle_message(msg.content)!;
	}
}

fn void? LSPServer.handle_message(&self, String json_content)
{
	@pool()
	{
		if (self.is_notification(json_content))
		{
			self.handle_notification(json_content)!;
		}
		else
		{
			self.handle_request(json_content)!;
		}
	};
}

fn bool LSPServer.is_notification(&self, String json_content)
{
	return !json_content.contains("\"id\":");
}

fn void? LSPServer.handle_request(&self, String json_content)
{
	LSPRequest? request = protocol::parse_request(json_content, self.transport.allocator);
	if (catch err = request)
	{
		self.send_error_response("", protocol::LSPErrorCode.PARSE_ERROR, "Invalid request")!;
		return;
	}
	
	switch (request.method)
	{
		case "initialize":
			self.handle_initialize(request)!;
		case "shutdown":
			self.handle_shutdown(request)!;
		case "textDocument/completion":
			self.handle_completion(request)!;
		case "textDocument/hover":
			self.handle_hover(request)!;
		case "textDocument/definition":
			self.handle_definition(request)!;
		default:
			self.send_error_response(request.id, protocol::LSPErrorCode.METHOD_NOT_FOUND, "Method not found")!;
	}
}

fn void? LSPServer.handle_notification(&self, String json_content)
{
	LSPNotification? notification = protocol::parse_notification(json_content, self.transport.allocator);
	if (catch err = notification) return;
	
	switch (notification.method)
	{
		case "initialized":
			self.initialized = true;
		case "textDocument/didOpen":
		case "textDocument/didChange":
		case "textDocument/didSave":
		case "textDocument/didClose":
		case "exit":
			self.shutdown_requested = true;
		default:
	}
}

fn void? LSPServer.handle_initialize(&self, LSPRequest request)
{
	String result = `{"capabilities":{"textDocumentSync":1,"completionProvider":{"triggerCharacters":["."]},"hoverProvider":true,"definitionProvider":true}}`;
	
	LSPResponse response = protocol::create_response(request.id, result);
	String json_response = protocol::marshal_response(response, self.transport.allocator)!;
	defer allocator::free(self.transport.allocator, json_response.ptr);
	
	self.transport.write_response(json_response)!;
}

fn void? LSPServer.handle_shutdown(&self, LSPRequest request)
{
	LSPResponse response = protocol::create_response(request.id, "null");
	String json_response = protocol::marshal_response(response, self.transport.allocator)!;
	defer allocator::free(self.transport.allocator, json_response.ptr);
	
	self.transport.write_response(json_response)!;
	self.shutdown_requested = true;
}

fn void? LSPServer.handle_completion(&self, LSPRequest request)
{
	String result = `{"items":[{"label":"example","kind":1,"detail":"Example completion"}]}`;
	
	LSPResponse response = protocol::create_response(request.id, result);
	String json_response = protocol::marshal_response(response, self.transport.allocator)!;
	defer allocator::free(self.transport.allocator, json_response.ptr);
	
	self.transport.write_response(json_response)!;
}

fn void? LSPServer.handle_hover(&self, LSPRequest request)
{
	String result = `{"contents":{"kind":"markdown","value":"Example hover information"}}`;
	
	LSPResponse response = protocol::create_response(request.id, result);
	String json_response = protocol::marshal_response(response, self.transport.allocator)!;
	defer allocator::free(self.transport.allocator, json_response.ptr);
	
	self.transport.write_response(json_response)!;
}

fn void? LSPServer.handle_definition(&self, LSPRequest request)
{
	String result = `[]`;
	
	LSPResponse response = protocol::create_response(request.id, result);
	String json_response = protocol::marshal_response(response, self.transport.allocator)!;
	defer allocator::free(self.transport.allocator, json_response.ptr);
	
	self.transport.write_response(json_response)!;
}

fn void? LSPServer.send_error_response(&self, String id, protocol::LSPErrorCode code, String message)
{
	LSPResponse response = protocol::create_error_response(id, code, message)!;
	String json_response = protocol::marshal_response(response, self.transport.allocator)!;
	defer allocator::free(self.transport.allocator, json_response.ptr);
	
	self.transport.write_response(json_response)!;
}