module lsp::server;
import lsp::protocol;
import lsp::transport;
import lsp::project;
import std::collections::list;
import std::io;
import json;

// LSP document synchronization structures
struct TextDocumentItem
{
	String uri;
	String languageId;
	uint version;
	String text;
}

struct VersionedTextDocumentIdentifier
{
	String uri;
	uint version;
}

struct TextDocumentIdentifier
{
	String uri;
}

struct DidOpenParams
{
	TextDocumentItem textDocument;
}

struct TextDocumentContentChangeEvent
{
	String text; // For full document sync
}

struct DidChangeParams
{
	VersionedTextDocumentIdentifier textDocument;
	TextDocumentContentChangeEvent[] contentChanges;
}

struct DidSaveParams
{
	TextDocumentIdentifier textDocument;
	String text; // Optional
}

struct DidCloseParams
{
	TextDocumentIdentifier textDocument;
}

struct Position
{
	uint line;
	uint character;
}

struct CompletionParams
{
	TextDocumentIdentifier textDocument;
	Position position;
}

struct HoverParams
{
	TextDocumentIdentifier textDocument;
	Position position;
}

// LSP response structures
struct CompletionItem
{
	String label;
	uint kind;
}

struct CompletionList
{
	CompletionItem[] items;
}

struct MarkdownContent
{
	String kind;
	String value;
}

struct HoverResult
{
	MarkdownContent contents;
}

struct LSPServer
{
	bool initialized;
	bool shutdown_requested;
	LSPTransport transport;
	Project project;
}

fn LSPServer* LSPServer.init(&self, InStream input, OutStream output, Allocator allocator)
{
	self.initialized = false;
	self.shutdown_requested = false;
	self.transport.init(input, output, allocator);
	self.project.init(allocator);
	return self;
}

fn LSPServer* LSPServer.init_stdio(&self, Allocator allocator)
{
	self.initialized = false;
	self.shutdown_requested = false;
	self.transport.init_stdio(allocator);
	self.project.init(allocator);
	return self;
}

fn void LSPServer.free(&self)
{
	self.project.free();
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
			self.handle_did_open(notification)!;
		case "textDocument/didChange":
			self.handle_did_change(notification)!;
		case "textDocument/didSave":
			self.handle_did_save(notification)!;
		case "textDocument/didClose":
			self.handle_did_close(notification)!;
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
	// Parse completion request using JSON unmarshaling
	CompletionParams params = json::unmarshal(CompletionParams, request.params, self.transport.allocator)!;
	
	// Get the source file from project
	SourceFile*? file_result = self.project.get_file_by_uri(params.textDocument.uri);

	CompletionList completion_list;

	if (@ok(file_result))
	{
		SourceFile* file = file_result!;
		List{String} completions_result;

		if (catch file.get_completions_at_position(params.position.line, params.position.character, &completions_result))
		{
			// Error getting completions, return empty list
            			completion_list = { .items = {} };
		}
		else
		{
            			completion_list.items = allocator::alloc_array(self.transport.allocator, CompletionItem, completions_result.len());
            			for (usz i = 0; i < completions_result.len(); i++)
            			{
            				completion_list.items[i] = { .label = completions_result.get(i), .kind = 14 }; // 14 = Keyword
            			}
		}
	}
	else
	{
		// File not found, return empty completions
		completion_list = { .items = {} };
	}

	String result;
    @pool()
    {
             DString output = dstring::temp_with_capacity(1024);
             json::marshal(completion_list, &output)!;
              result = output.copy_str(self.transport.allocator);
    };

	if (completion_list.items.len > 0)
	{
		defer allocator::free(self.transport.allocator, completion_list.items);
	}

    defer allocator::free(self.transport.allocator, result.ptr);

    LSPResponse response = protocol::create_response(request.id, result);
    String json_response = protocol::marshal_response(response, self.transport.allocator)!;
    defer allocator::free(self.transport.allocator, json_response.ptr);

	self.transport.write_response(json_response)!;
}

fn void? LSPServer.handle_hover(&self, LSPRequest request)
{
	// Parse hover request using JSON unmarshaling
	HoverParams params = json::unmarshal(HoverParams, request.params, self.transport.allocator)!;
	
	// Get the source file from project
	SourceFile*? file_result = self.project.get_file_by_uri(params.textDocument.uri);
	
	String result;
	bool need_to_free_result = false;
	
	if (@ok(file_result))
	{
		SourceFile* file = file_result!;
		String? hover_result = file.get_hover_info(params.position.line, params.position.character);
		
		if (@ok(hover_result))
		{
			String hover_info = hover_result!;
			// Create hover result struct
			HoverResult hover = {
				.contents = {
					.kind = "markdown",
					.value = hover_info
				}
			};
			
			// Marshal to JSON
			DString hover_output = dstring::new(self.transport.allocator);
			defer hover_output.free();
			json::marshal(hover, &hover_output)!;
			result = hover_output.copy_str(self.transport.allocator);
			need_to_free_result = true;
		}
		else
		{
			// No hover info available
			result = "null";
		}
	}
	else
	{
		// File not found, return null hover
		result = "null";
	}
	
	LSPResponse response = protocol::create_response(request.id, result);
	String json_response = protocol::marshal_response(response, self.transport.allocator)!;
	defer allocator::free(self.transport.allocator, json_response.ptr);
	
	if (need_to_free_result)
	{
		defer allocator::free(self.transport.allocator, result.ptr);
	}
	
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
	LSPResponse response = protocol::create_error_response(id, code, message, self.transport.allocator)!;
	String json_response = protocol::marshal_response(response, self.transport.allocator)!;
	defer allocator::free(self.transport.allocator, json_response.ptr);
	
	self.transport.write_response(json_response)!;
}

// File notification handlers

fn void? LSPServer.handle_did_open(&self, LSPNotification notification)
{
	// Parse didOpen notification using JSON unmarshaling
	DidOpenParams params = json::unmarshal(DidOpenParams, notification.params, self.transport.allocator)!;
	
	// Convert URI to file path (simplified - just remove file:// prefix)
	String file_path = params.textDocument.uri;
	if (params.textDocument.uri.starts_with("file://"))
	{
		file_path = params.textDocument.uri[7..];
	}
	
	// Add file to project
	self.project.add_or_update_file(file_path, params.textDocument.uri, params.textDocument.text, params.textDocument.version)!;
}

fn void? LSPServer.handle_did_change(&self, LSPNotification notification)
{
	// Parse didChange notification using JSON unmarshaling
	DidChangeParams params = json::unmarshal(DidChangeParams, notification.params, self.transport.allocator)!;
	
	// Handle content changes - for now assume full document sync (first change event)
	if (params.contentChanges.len > 0)
	{
		String new_text = params.contentChanges[0].text;
		self.project.update_file_content(params.textDocument.uri, new_text, params.textDocument.version)!;
	}
}

fn void? LSPServer.handle_did_save(&self, LSPNotification notification)
{
	// Parse didSave notification using JSON unmarshaling
	DidSaveParams params = json::unmarshal(DidSaveParams, notification.params, self.transport.allocator)!;
	
	// File is already updated via didChange, so nothing more to do for now
	// Could trigger additional analysis, formatting, etc.
}

fn void? LSPServer.handle_did_close(&self, LSPNotification notification)
{
	// Parse didClose notification using JSON unmarshaling
	DidCloseParams params = json::unmarshal(DidCloseParams, notification.params, self.transport.allocator)!;
	
	// Remove file from project
	self.project.remove_file_by_uri(params.textDocument.uri)!;
}