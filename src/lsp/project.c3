module lsp::project;
import parser;
import std::collections::map;
import std::collections::list;
import std::core::dstring;
import std::core::mem;

// Error definitions
faultdef FILE_NOT_FOUND;
faultdef NO_AST_DEFINED;
faultdef INVALID_POSITION;
faultdef INVALID_RANGE;

// LSP text change structures
struct LSPRange
{
	uint start_line;
	uint start_character;
	uint end_line;
	uint end_character;
}

struct LSPTextChange
{
	LSPRange range;  // For incremental changes
	String text;     // New text to insert
	bool is_full_document; // If true, replace entire document
}

struct SourceFile
{
	String file_path;
	String uri;
	String content;
	AstTranslationUnit* ast;
	uint version;
	bool has_errors;
	uint error_count;
	Allocator allocator;
}

struct Project
{
	HashMap{String, SourceFile*} files_by_path;
	HashMap{String, SourceFile*} files_by_uri;
	Allocator allocator;
}

fn Project* Project.init(&self, Allocator allocator)
{
	self.files_by_path.init(allocator);
	self.files_by_uri.init(allocator);
	self.allocator = allocator;
	return self;
}

fn void Project.free(&self)
{
	// Free all source files and their ASTs
	self.files_by_path.@each(; String path, SourceFile* file)
	{
		if (file.ast)
		{
			// The AST was allocated with the parser's allocator
			// We should clean it up properly
		}
		allocator::free(self.allocator, file);
	};
	
	self.files_by_path.free();
	self.files_by_uri.free();
}

fn SourceFile*? Project.add_or_update_file(&self, String file_path, String uri, String content, uint version)
{
	// Remove existing file if present (ignore errors if file doesn't exist)
	if (catch err = self.remove_file_by_path(file_path))
	{
		// File didn't exist, that's okay
	}
	
	// Create new source file
	SourceFile* file = allocator::new(self.allocator, SourceFile);
	file.init(file_path, uri, content, version, self.allocator);
	
	// Add to both maps
	self.files_by_path.set(file.file_path, file);
	self.files_by_uri.set(file.uri, file);
	
	return file;
}

// SourceFile methods
fn void SourceFile.init(&self, String file_path, String uri, String content, uint version, Allocator allocator)
{
	self.allocator = allocator;
	self.file_path = file_path.copy(allocator);
	self.uri = uri.copy(allocator);
	self.content = content.copy(allocator);
	self.version = version;
	self.ast = null;
	self.has_errors = false;
	self.error_count = 0;
	
	// Parse the initial content
	self.parse();
}

fn void SourceFile.parse(&self)
{
	// Create parser for this file
	Parser parser;
	parser.init(self.content, self.allocator);
	
	// Parse the source code
	self.ast = parser.parse(self.file_path);
	self.has_errors = parser.had_error;
	self.error_count = parser.error_count;
}

fn void? SourceFile.apply_text_changes(&self, LSPTextChange[] changes, uint version)
{
	// If any change is full document, apply only the last full document change
	foreach (change : changes)
	{
		if (change.is_full_document)
		{
			allocator::free(self.allocator, self.content.ptr);
			self.content = change.text.copy(self.allocator);
			self.version = version;
			self.parse();
			return;
		}
	}
	
	// Apply incremental changes using DString
	DString builder = dstring::new(self.allocator, self.content);
	defer builder.free();
	
	// Apply changes in reverse order to maintain correct offsets
	// TODO: Sort changes by position first
	foreach (change : changes)
	{
		self.apply_single_change(&builder, change)!;
	}
	
	// Update content
	allocator::free(self.allocator, self.content.ptr);
	self.content = builder.str_view().copy(self.allocator);
	self.version = version;
	
	// Re-parse
	self.parse();
}

fn void? SourceFile.apply_single_change(&self, DString* builder, LSPTextChange change)
{
	// Convert line/character positions to byte offsets
	String current_content = builder.str_view();
	uint start_offset = self.position_to_offset(current_content, change.range.start_line, change.range.start_character)!;
	uint end_offset = self.position_to_offset(current_content, change.range.end_line, change.range.end_character)!;
	
	if (start_offset > end_offset || end_offset > current_content.len)
	{
		return INVALID_RANGE?;
	}
	
	// Replace the range with new text
	builder.delete((usz)start_offset, (usz)(end_offset - start_offset));
	builder.insert_at((usz)start_offset, change.text);
}

fn uint? SourceFile.position_to_offset(&self, String content, uint line, uint character)
{
	uint current_line = 0;
	uint line_start = 0;
	
	// Find the start of the target line
	for (uint i = 0; i < content.len; i++)
	{
		if (content[i] == '\n')
		{
			current_line++;
			if (current_line > line)
			{
				break;
			}
			line_start = i + 1;
		}
	}
	
	// Check if we found the target line
	if (current_line < line)
	{
		return INVALID_POSITION?;
	}
	
	// Calculate offset within the line
	uint offset = line_start + character;
	
	// Make sure we don't go past end of content or past the line end
	uint line_end = content.len;
	for (uint i = line_start; i < content.len; i++)
	{
		if (content[i] == '\n')
		{
			line_end = i;
			break;
		}
	}
	
	if (offset > line_end)
	{
		offset = line_end;
	}
	
	return offset;
}

fn bool? Project.remove_file_by_path(&self, String file_path)
{
	SourceFile* file = self.files_by_path.get(file_path)!;
	
	// Remove from both maps
	self.files_by_path.remove(file_path);
	self.files_by_uri.remove(file.uri);
	
	// Free the file and its content
	allocator::free(self.allocator, file.file_path.ptr);
	allocator::free(self.allocator, file.uri.ptr);
	allocator::free(self.allocator, file.content.ptr);
	allocator::free(self.allocator, file);
	
	return true;
}

fn bool? Project.remove_file_by_uri(&self, String uri)
{
	SourceFile* file = self.files_by_uri.get(uri)!;
	return self.remove_file_by_path(file.file_path);
}

fn SourceFile*? Project.get_file_by_path(&self, String file_path)
{
	return self.files_by_path.get(file_path);
}

fn SourceFile*? Project.get_file_by_uri(&self, String uri)
{
	return self.files_by_uri.get(uri);
}

fn void? Project.update_file_content(&self, String uri, String content, uint version)
{
	SourceFile* file = self.files_by_uri.get(uri)!;
	
	// Create a full document change
	LSPTextChange full_change = {
		.range = { .start_line = 0, .start_character = 0, .end_line = 0, .end_character = 0 },
		.text = content,
		.is_full_document = true
	};
	
	LSPTextChange[] changes = { full_change };
	file.apply_text_changes(changes, version)!;
}

fn void? Project.apply_incremental_changes(&self, String uri, LSPTextChange[] changes, uint version)
{
	SourceFile* file = self.files_by_uri.get(uri)!;
	file.apply_text_changes(changes, version)!;
}

fn SourceFile*[] Project.get_all_files(&self)
{
	return self.files_by_path.values(self.allocator);
}

fn usz Project.file_count(&self)
{
	return self.files_by_path.len();
}

fn AstNode*? Project.find_node_at_position(&self, String uri, uint line, uint column)
{
	SourceFile* file = self.files_by_uri.get(uri)!;
	if (!file.ast) return NO_AST_DEFINED?;
	
	SourcePosition pos = { .line = line, .column = column };
	return file.ast.find_node_at_position(pos);
}

fn String[]? Project.get_completions_at_position(&self, String uri, uint line, uint column)
{
	// Basic completion implementation - can be extended
	SourceFile* file = self.files_by_uri.get(uri)!;
	if (!file.ast) return NO_AST_DEFINED?;
	
	// For now, return basic C3 keywords
	String[] keywords = {
		"struct", "union", "enum", "fn", "macro", "const", "var",
		"if", "else", "while", "for", "foreach", "switch", "case", "default",
		"return", "break", "continue", "defer", "import", "module"
	};
	
	return keywords;
}

fn String? Project.get_hover_info(&self, String uri, uint line, uint column)
{
	AstNode*? node = self.find_node_at_position(uri, line, column);
	if (!@ok(node)) return INVALID_POSITION?;
	
	AstNode* ast_node = node!;
	
	// Basic hover implementation
	switch (ast_node.kind)
	{
		case AST_EXPR_IDENTIFIER:
			AstIdentifier* ident = (AstIdentifier*)ast_node;
			return string::tformat("Identifier: %s", ident.name);
		case AST_DECL_FUNCTION:
			AstFunctionDecl* func = (AstFunctionDecl*)ast_node;
			return string::tformat("Function: %s", func.name);
		case AST_DECL_STRUCT:
			AstStructDecl* struct_decl = (AstStructDecl*)ast_node;
			return string::tformat("Struct: %s", struct_decl.name);
		default:
			return string::tformat("AST Node: %s", ast_node.kind);
	}
}