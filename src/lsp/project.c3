module lsp::project;
import parser;
import std::collections::map;
import std::collections::list;

// Error definitions
faultdef FILE_NOT_FOUND;
faultdef NO_AST_DEFINED;
faultdef INVALID_POSITION;

struct SourceFile
{
	String file_path;
	String uri;
	String content;
	AstTranslationUnit* ast;
	uint version;
	bool has_errors;
	uint error_count;
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
	SourceFile* file = allocator::new(self.allocator, SourceFile, {
		.file_path = file_path.copy(self.allocator),
		.uri = uri.copy(self.allocator),
		.content = content.copy(self.allocator),
		.version = version,
		.ast = null,
		.has_errors = false,
		.error_count = 0
	});
	
	// Parse the content
	self.parse_file(file);
	
	// Add to both maps
	self.files_by_path.set(file.file_path, file);
	self.files_by_uri.set(file.uri, file);
	
	return file;
}

fn void Project.parse_file(&self, SourceFile* file)
{
	// Create parser for this file
	Parser parser;
	parser.init(file.content, self.allocator);
	
	// Parse the source code
	file.ast = parser.parse(file.file_path);
	file.has_errors = parser.had_error;
	file.error_count = parser.error_count;
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
	
	// Update content and version
	allocator::free(self.allocator, file.content.ptr);
	file.content = content.copy(self.allocator);
	file.version = version;
	
	// Re-parse the file
	self.parse_file(file);
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