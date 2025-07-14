// Copyright (c) 2024 C3 Project. All rights reserved.
// Use of this source code is governed by the GNU LGPLv3.0 license
// a copy of which can be found in the LICENSE file.

module parser;
import std::io;
import std::core::mem::allocator;
import std::collections::list;
import std::core::dstring;
/**
 * Allocate a new AST node using the parser's allocator
 */
macro Parser.allocate_node(&self, $Type) @local
{
    return allocator::alloc(self.allocator, $Type);
}


/**
 * Parser context for managing parsing state
 */
struct Parser
{
    Lexer lexer;
    Token current_token;
    Token previous_token;
    bool had_error;
    bool panic_mode;
    Allocator allocator;
    uint error_count;
    uint max_errors;
}

/**
 * Precedence levels for expression parsing
 */
enum Precedence : uint
{
    PREC_NONE,
    PREC_ASSIGNMENT,    // =
    PREC_OR,           // ||
    PREC_AND,          // &&
    PREC_EQUALITY,     // == !=
    PREC_COMPARISON,   // < > <= >=
    PREC_TERM,         // + -
    PREC_FACTOR,       // * / %
    PREC_UNARY,        // ! - +
    PREC_CALL,         // . () []
    PREC_PRIMARY
}

// Removed ParseRule struct - using simpler switch-based approach

/**
 * Initialize parser with source code and allocator
 */
fn void Parser.init(&self, String source, Allocator allocator, uint file_id = 0, uint max_errors = 100)
{
    self.lexer.init(source, file_id);
    self.had_error = false;
    self.panic_mode = false;
    self.allocator = allocator;
    self.error_count = 0;
    self.max_errors = max_errors;

    // Prime the parser with the first token
    self.advance();
}

/**
 * Advance to the next token
 */
fn void Parser.advance(&self)
{
    self.previous_token = self.current_token;
    
    while (true)
    {
        self.current_token = self.lexer.lexer_next_token();
        if (self.current_token.type != TokenType.INVALID_TOKEN) break;
        
        self.error_at_current("Invalid token");
    }
}

/**
 * Check if current token matches the given type
 */
fn bool Parser.check(&self, TokenType type)
{
    return self.current_token.type == type;
}

/**
 * Consume a token of the given type or report an error
 */
fn bool Parser.consume(&self, TokenType type, String message)
{
    if (self.current_token.type == type)
    {
        self.advance();
        return true;
    }
    
    self.error_at_current(message);
    return false;
}

/**
 * Try to consume a token of the given type
 */
fn bool Parser.match(&self, TokenType type)
{
    if (!self.check(type)) return false;
    self.advance();
    return true;
}

/**
 * Check if we should continue parsing (haven't hit error limit)
 */
fn bool Parser.should_continue(&self)
{
    return self.error_count <= self.max_errors && !self.check(TokenType.EOF);
}

/**
 * Report an error at the current token
 */
fn void Parser.error_at_current(&self, String message)
{
    self.error_at(&self.current_token, message);
}

/**
 * Report an error at the previous token
 */
fn void Parser.error(&self, String message)
{
    self.error_at(&self.previous_token, message);
}

/**
 * Report an error at a specific token
 */
fn void Parser.error_at(&self, Token* token, String message)
{
    if (self.panic_mode) return;

    self.error_count++;
    if (self.error_count > self.max_errors)
    {
        io::printf("Too many errors (%d), stopping parsing\n", self.max_errors);
        return;
    }

    self.panic_mode = true;

    io::printf("[%d:%d] Error", token.span.start, token.span.end);

    if (token.type == TokenType.EOF)
    {
        io::print(" at end");
    }
    else if (token.type == TokenType.INVALID_TOKEN)
    {
        // Nothing
    }
    else
    {
        io::printf(" at '%s'", token.lexeme);
    }

    io::printf(": %s\n", message);
    self.had_error = true;
}

/**
 * Synchronize after a parse error - find a safe point to continue parsing
 */
fn void Parser.synchronize(&self)
{
    self.panic_mode = false;

    while (self.current_token.type != TokenType.EOF)
    {
        // Stop at statement boundaries
        if (self.previous_token.type == TokenType.SEMICOLON) return;
        if (self.previous_token.type == TokenType.RBRACE) return;

        // Stop at declaration/statement keywords
        if (self.current_token.type == TokenType.IDENT)
        {
            if (self.current_token.lexeme == "fn" ||
                self.current_token.lexeme == "struct" ||
                self.current_token.lexeme == "union" ||
                self.current_token.lexeme == "enum" ||
                self.current_token.lexeme == "const" ||
                self.current_token.lexeme == "module" ||
                self.current_token.lexeme == "import" ||
                self.current_token.lexeme == "if" ||
                self.current_token.lexeme == "while" ||
                self.current_token.lexeme == "for" ||
                self.current_token.lexeme == "switch" ||
                self.current_token.lexeme == "return" ||
                self.current_token.lexeme == "break" ||
                self.current_token.lexeme == "continue" ||
                self.current_token.lexeme == "defer")
            {
                return;
            }
        }

        // Stop at block boundaries
        if (self.current_token.type == TokenType.LBRACE ||
            self.current_token.type == TokenType.RBRACE)
        {
            return;
        }

        self.advance();
    }
}

/**
 * Parse a complete program (translation unit)
 */
fn AstTranslationUnit* Parser.parse(&self, String filename = "")
{
    AstTranslationUnit* translation_unit = self.allocate_node(AstTranslationUnit);
    translation_unit.init(filename, self.lexer.source, self.allocator);

    // TranslationUnit doesn't need span info - it represents the entire file

    while (!self.check(TokenType.EOF) && self.error_count <= self.max_errors)
    {
        // Skip whitespace and comments for better error recovery
        while (self.current_token.type == TokenType.WHITESPACE ||
               self.current_token.type == TokenType.NEWLINE)
        {
            self.advance();
            if (self.check(TokenType.EOF)) break;
        }

        if (self.check(TokenType.EOF)) break;

        AstDecl* decl = self.parse_declaration();
        if (decl != null)
        {
            translation_unit.add_declaration(decl);
        }

        // If we're in panic mode, synchronize to find a safe point
        if (self.panic_mode)
        {
            self.synchronize();
        }
        // If we didn't make progress and no error was reported, advance to prevent infinite loops
        else if (self.current_token.type != TokenType.EOF)
        {
            // Check if we're stuck on the same token
            Token stuck_token = self.current_token;
            self.advance();

            // If we're still on the same position, we might be in an infinite loop
            if (self.current_token.span.start == stuck_token.span.start)
            {
                self.error_at_current("Unexpected token, skipping");
                self.advance();
            }
        }
    }

    return translation_unit;
}

// Expression parsing functions

/**
 * Parse a primary expression (literals, identifiers, parenthesized expressions)
 */
fn AstExpr* Parser.parse_primary(&self)
{
    switch (self.previous_token.type)
    {
        case TokenType.INTEGER:
            AstLiteral* int_literal = self.allocate_node(AstLiteral);
            int_literal.expr.node.kind = AST_EXPR_LITERAL;
            int_literal.expr.node.span = self.previous_token.span;
            int_literal.int_value = self.previous_token.lexeme.to_long()!!;
            return (AstExpr*)int_literal;

        case TokenType.REAL:
            AstLiteral* real_literal = self.allocate_node(AstLiteral);
            real_literal.expr.node.kind = AST_EXPR_LITERAL;
            real_literal.expr.node.span = self.previous_token.span;
            real_literal.real_value = self.previous_token.lexeme.to_double()!!;
            return (AstExpr*)real_literal;

        case TokenType.STRING:
            AstLiteral* string_literal = self.allocate_node(AstLiteral);
            string_literal.expr.node.kind = AST_EXPR_LITERAL;
            string_literal.expr.node.span = self.previous_token.span;
            string_literal.string_value = self.previous_token.lexeme;
            return (AstExpr*)string_literal;

        case TokenType.IDENT:
            AstIdentifier* ident = self.allocate_node(AstIdentifier);
            ident.expr.node.kind = AST_EXPR_IDENTIFIER;
            ident.expr.node.span = self.previous_token.span;
            ident.name = self.previous_token.lexeme;
            return (AstExpr*)ident;

        case TokenType.LPAREN:
            AstExpr* expr = self.parse_expression();
            if (!self.consume(TokenType.RPAREN, "Expected ')' after expression"))
            {
                // Create a synthetic error node for better error recovery
                AstIdentifier* error_node = self.allocate_node(AstIdentifier);
                error_node.expr.node.kind = AST_EXPR_IDENTIFIER;
                error_node.expr.node.span = self.previous_token.span;
                error_node.name = "<error>";
                return (AstExpr*)error_node;
            }
            return expr;

        default:
            self.error_at_current("Expected expression");
            // Create a synthetic error node instead of returning null
            AstIdentifier* error_node = self.allocate_node(AstIdentifier);
            error_node.expr.node.kind = AST_EXPR_IDENTIFIER;
            error_node.expr.node.span = self.current_token.span;
            error_node.name = "<error>";
            return (AstExpr*)error_node;
    }
}

/**
 * Parse a binary expression
 */
fn AstExpr* Parser.parse_binary(&self, AstExpr* left)
{
    TokenType operator_type = self.previous_token.type;
    Precedence precedence = get_precedence(operator_type);
    AstExpr* right = self.parse_precedence((Precedence)(precedence + 1));

    AstBinaryOp* binary = self.allocate_node(AstBinaryOp);
    binary.expr.node.kind = AST_EXPR_BINARY_OP;
    binary.expr.node.span = left.node.span;
    binary.op = token_to_binary_op(operator_type);
    binary.left = left;
    binary.right = right;

    // Set parent relationships
    if (left != null) left.node.set_parent((AstNode*)binary);
    if (right != null) right.node.set_parent((AstNode*)binary);

    return (AstExpr*)binary;
}

/**
 * Parse a unary expression
 */
fn AstExpr* Parser.parse_unary(&self)
{
    TokenType operator_type = self.previous_token.type;
    SourceSpan operator_span = self.previous_token.span;
    AstExpr* operand = self.parse_precedence(PREC_UNARY);

    AstUnaryOp* unary = self.allocate_node(AstUnaryOp);
    unary.expr.node.kind = AST_EXPR_UNARY_OP;
    unary.expr.node.span = operator_span;
    unary.op = token_to_unary_op(operator_type);
    unary.operand = operand;

    // Set parent relationship
    if (operand != null) operand.node.set_parent((AstNode*)unary);

    return (AstExpr*)unary;
}

/**
 * Parse expression with precedence
 */
fn AstExpr* Parser.parse_precedence(&self, Precedence precedence)
{
    self.advance();

    // Parse prefix expression based on token type
    AstExpr* left = null;
    switch (self.previous_token.type)
    {
        case TokenType.INTEGER:
        case TokenType.REAL:
        case TokenType.STRING:
        case TokenType.IDENT:
        case TokenType.LPAREN:
            left = self.parse_primary();
        case TokenType.MINUS:
        case TokenType.PLUS:
        case TokenType.BANG:
        case TokenType.TILDE:
        case TokenType.STAR:
        case TokenType.AMPERSAND:
        case TokenType.PLUSPLUS:
        case TokenType.MINUSMINUS:
            left = self.parse_unary();
        default:
            self.error("Expected expression");
            // Create a synthetic error node for better error recovery
            AstIdentifier* error_node = self.allocate_node(AstIdentifier);
            error_node.expr.node.kind = AST_EXPR_IDENTIFIER;
            error_node.expr.node.span = self.previous_token.span;
            error_node.name = "<error>";
            left = (AstExpr*)error_node;
    }

    while (precedence <= get_precedence(self.current_token.type))
    {
        self.advance();
        left = self.parse_binary(left);
    }

    return left;
}

/**
 * Get precedence for a token type
 */
fn Precedence get_precedence(TokenType type)
{
    switch (type)
    {
        case TokenType.OR: return PREC_OR;
        case TokenType.AND: return PREC_AND;
        case TokenType.EQEQ:
        case TokenType.NOT_EQUAL: return PREC_EQUALITY;
        case TokenType.GREATER:
        case TokenType.GREATER_EQ:
        case TokenType.LESS:
        case TokenType.LESS_EQ: return PREC_COMPARISON;
        case TokenType.PLUS:
        case TokenType.MINUS:
        case TokenType.PIPE:
        case TokenType.CARET:
        case TokenType.SHL:
        case TokenType.SHR: return PREC_TERM;
        case TokenType.STAR:
        case TokenType.SLASH:
        case TokenType.PERCENT:
        case TokenType.AMPERSAND: return PREC_FACTOR;
        default: return PREC_NONE;
    }
}

/**
 * Parse a complete expression
 */
fn AstExpr* Parser.parse_expression(&self)
{
    return self.parse_precedence(PREC_ASSIGNMENT);
}

/**
 * Convert token type to binary operator
 */
fn BinaryOp token_to_binary_op(TokenType type)
{
    switch (type)
    {
        case TokenType.PLUS: return BINOP_ADD;
        case TokenType.MINUS: return BINOP_SUB;
        case TokenType.STAR: return BINOP_MUL;
        case TokenType.SLASH: return BINOP_DIV;
        case TokenType.PERCENT: return BINOP_MOD;
        case TokenType.EQEQ: return BINOP_EQ;
        case TokenType.NOT_EQUAL: return BINOP_NE;
        case TokenType.LESS: return BINOP_LT;
        case TokenType.LESS_EQ: return BINOP_LE;
        case TokenType.GREATER: return BINOP_GT;
        case TokenType.GREATER_EQ: return BINOP_GE;
        case TokenType.AND: return BINOP_AND;
        case TokenType.OR: return BINOP_OR;
        case TokenType.AMPERSAND: return BINOP_BIT_AND;
        case TokenType.PIPE: return BINOP_BIT_OR;
        case TokenType.CARET: return BINOP_BIT_XOR;
        case TokenType.SHL: return BINOP_SHL;
        case TokenType.SHR: return BINOP_SHR;
        case TokenType.EQUAL: return BINOP_ASSIGN;
        default: return BINOP_ADD; // Should not happen
    }
}

/**
 * Convert token type to unary operator
 */
fn UnaryOp token_to_unary_op(TokenType type)
{
    switch (type)
    {
        case TokenType.PLUS: return UNARYOP_PLUS;
        case TokenType.MINUS: return UNARYOP_MINUS;
        case TokenType.BANG: return UNARYOP_NOT;
        case TokenType.TILDE: return UNARYOP_BIT_NOT;
        case TokenType.STAR: return UNARYOP_DEREF;
        case TokenType.AMPERSAND: return UNARYOP_ADDR;
        case TokenType.PLUSPLUS: return UNARYOP_PRE_INC;
        case TokenType.MINUSMINUS: return UNARYOP_PRE_DEC;
        default: return UNARYOP_PLUS; // Should not happen
    }
}

// Removed parse rules table - using simpler switch-based approach


// Statement parsing functions

/**
 * Parse a statement
 */
fn AstStmt* Parser.parse_statement(&self)
{
    if (self.match(TokenType.LBRACE))
    {
        return self.parse_compound_statement();
    }

    if (self.check(TokenType.IDENT))
    {
        if (self.current_token.lexeme == "return")
        {
            self.advance();
            return self.parse_return_statement();
        }
        else if (self.current_token.lexeme == "if")
        {
            self.advance();
            return self.parse_if_statement();
        }
        else if (self.current_token.lexeme == "while")
        {
            self.advance();
            return self.parse_while_statement();
        }
        else if (self.current_token.lexeme == "for")
        {
            self.advance();
            return self.parse_for_statement();
        }
        else if (self.current_token.lexeme == "break")
        {
            self.advance();
            return self.parse_break_statement();
        }
        else if (self.current_token.lexeme == "continue")
        {
            self.advance();
            return self.parse_continue_statement();
        }
    }

    return self.parse_expression_statement();
}

/**
 * Parse a compound statement (block)
 */
fn AstStmt* Parser.parse_compound_statement(&self)
{
    AstCompoundStmt* compound = self.allocate_node(AstCompoundStmt);
    compound.stmt.node.kind = AST_STMT_COMPOUND;
    compound.stmt.node.span = self.previous_token.span;

    // Parse statements until we hit the closing brace
    // This is simplified - would need proper dynamic array handling
    while (!self.check(TokenType.RBRACE) && !self.check(TokenType.EOF))
    {
        // Skip whitespace and newlines
        while (self.current_token.type == TokenType.WHITESPACE ||
               self.current_token.type == TokenType.NEWLINE)
        {
            self.advance();
            if (self.check(TokenType.RBRACE) || self.check(TokenType.EOF)) break;
        }

        if (self.check(TokenType.RBRACE) || self.check(TokenType.EOF)) break;

        AstStmt* stmt = self.parse_statement();
        if (stmt != null)
        {
            // Add to statements array
            // compound.statements.push(stmt);
        }

        // If we're in panic mode, try to recover
        if (self.panic_mode)
        {
            self.synchronize();
        }
    }

    if (!self.consume(TokenType.RBRACE, "Expected '}' after block"))
    {
        // If we can't find the closing brace, try to recover
        while (!self.check(TokenType.RBRACE) && !self.check(TokenType.EOF))
        {
            self.advance();
        }
        if (self.check(TokenType.RBRACE)) self.advance();
    }

    return (AstStmt*)compound;
}

// Removed - now implemented as member function

// Removed - now implemented as member function

/**
 * Parse an expression statement
 */
fn AstStmt* Parser.parse_expression_statement(&self)
{
    AstExpressionStmt* expr_stmt = self.allocate_node(AstExpressionStmt);
    expr_stmt.stmt.node.kind = AST_STMT_EXPRESSION;

    expr_stmt.expression = self.parse_expression();
    if (expr_stmt.expression != null)
    {
        expr_stmt.stmt.node.span = expr_stmt.expression.node.span;
    }
    else
    {
        expr_stmt.stmt.node.span = self.current_token.span;
    }

    // Try to consume semicolon, but don't fail if it's missing (common in LSP scenarios)
    if (!self.consume(TokenType.SEMICOLON, "Expected ';' after expression"))
    {
        // Check if we're at a natural statement boundary
        if (self.current_token.type == TokenType.RBRACE ||
            self.current_token.type == TokenType.EOF ||
            self.current_token.type == TokenType.NEWLINE ||
            (self.current_token.type == TokenType.IDENT &&
             (self.current_token.lexeme == "if" ||
              self.current_token.lexeme == "while" ||
              self.current_token.lexeme == "for" ||
              self.current_token.lexeme == "return")))
        {
            // It's okay, we're at a natural boundary
        }
        else
        {
            // Try to skip to next statement
            self.synchronize();
        }
    }

    return (AstStmt*)expr_stmt;
}

// Declaration parsing functions

/**
 * Parse a declaration
 */
fn AstDecl* Parser.parse_declaration(&self)
{
    if (self.check(TokenType.IDENT))
    {
        if (self.current_token.lexeme == "import")
        {
            self.advance();
            return self.parse_import_declaration();
        }
        else if (self.current_token.lexeme == "fn")
        {
            self.advance();
            return self.parse_function_declaration();
        }
        else if (self.current_token.lexeme == "struct")
        {
            self.advance();
            return self.parse_struct_declaration();
        }
        else if (self.current_token.lexeme == "union")
        {
            self.advance();
            return self.parse_struct_declaration(); // Use same function, it handles union flag
        }
        else if (self.current_token.lexeme == "enum")
        {
            self.advance();
            return self.parse_enum_declaration();
        }
        else if (self.current_token.lexeme == "const")
        {
            self.advance();
            return self.parse_const_declaration();
        }
    }

    // Try to parse as variable declaration
    return self.parse_variable_declaration();
}

// All old function definitions removed - now using member functions

/**
 * Parse an import declaration
 * Syntax: import path1, path2, path3;
 * Example: import std::io, std::core::mem;
 */
fn AstDecl* Parser.parse_import_declaration(&self)
{
    // Store the start position (import keyword)
    SourceSpan import_start = self.previous_token.span;

    AstImportDecl* import_decl = self.allocate_node(AstImportDecl);
    import_decl.init(self.allocator);
    import_decl.node.span.start = import_start.start;

    // Skip whitespace before first import path
    while (self.current_token.type == TokenType.WHITESPACE ||
           self.current_token.type == TokenType.NEWLINE)
    {
        self.advance();
    }

    do {
        // Parse a single import path as identifier nodes (e.g., std::io::file)
        if (!self.parse_import_path_identifiers(import_decl))
        {
            self.error_at_current("Expected import path");
            // Try to recover by synchronizing to next statement
            self.synchronize();
            break;
        }

        // Skip whitespace before comma or semicolon
        while (self.current_token.type == TokenType.WHITESPACE ||
               self.current_token.type == TokenType.NEWLINE)
        {
            self.advance();
        }

    } while (self.match(TokenType.COMMA));

    // Skip whitespace before semicolon
    while (self.current_token.type == TokenType.WHITESPACE ||
           self.current_token.type == TokenType.NEWLINE)
    {
        self.advance();
    }

    // Consume semicolon
    if (!self.consume(TokenType.SEMICOLON, "Expected ';' after import declaration"))
    {
        // Try to recover by finding the next statement
        self.synchronize();
    }

    // Set the end span to include the semicolon
    import_decl.node.span.end = self.previous_token.span.end;

    return (AstDecl*)import_decl;
}

/**
 * Parse a single import path as identifier nodes (e.g., std::io::file)
 */
fn bool Parser.parse_import_path_identifiers(&self, AstImportDecl* import_decl)
{
    // Skip whitespace before parsing the path
    while (self.current_token.type == TokenType.WHITESPACE ||
           self.current_token.type == TokenType.NEWLINE)
    {
        self.advance();
    }

    if (!self.check(TokenType.IDENT))
    {
        return false;
    }

    // Parse first identifier
    AstIdentifier* first_ident = self.allocate_node(AstIdentifier);
    first_ident.expr.node.kind = AST_EXPR_IDENTIFIER;
    first_ident.expr.node.span = self.current_token.span;
    first_ident.name = self.current_token.lexeme;
    self.advance();

    import_decl.add_identifier(first_ident);

    // Handle :: separators for nested modules
    while (self.match(TokenType.SCOPE))
    {
        // Skip whitespace after ::
        while (self.current_token.type == TokenType.WHITESPACE ||
               self.current_token.type == TokenType.NEWLINE)
        {
            self.advance();
        }

        if (!self.check(TokenType.IDENT))
        {
            self.error_at_current("Expected identifier after '::'");
            return false;
        }

        // Create identifier node for this part of the path
        AstIdentifier* ident = self.allocate_node(AstIdentifier);
        ident.expr.node.kind = AST_EXPR_IDENTIFIER;
        ident.expr.node.span = self.current_token.span;
        ident.name = self.current_token.lexeme;
        self.advance();

        import_decl.add_identifier(ident);
    }

    return true;
}

/**
 * Parse a struct or union declaration
 * Syntax: struct TypeName { members... }
 * Syntax: union TypeName { members... }
 */
fn AstDecl* Parser.parse_struct_declaration(&self)
{
    // The "struct" or "union" keyword has already been consumed
    bool is_union = self.previous_token.lexeme == "union";

    AstStructDecl* struct_decl = self.allocate_node(AstStructDecl);
    struct_decl.decl.node.kind = AST_DECL_STRUCT;
    struct_decl.decl.node.span = self.previous_token.span;
    struct_decl.is_union = is_union;
    struct_decl.members.init(self.allocator);

    // Skip whitespace before type name
    while (self.current_token.type == TokenType.WHITESPACE ||
           self.current_token.type == TokenType.NEWLINE)
    {
        self.advance();
    }

    // Parse struct name (could be IDENT, TYPE_IDENT, or CONST_IDENT)
    if (!self.check(TokenType.IDENT) && !self.check(TokenType.TYPE_IDENT) && !self.check(TokenType.CONST_IDENT))
    {
        self.error_at_current("Expected struct name");
        // Try to recover by using a placeholder name and continuing
        struct_decl.decl.name = "<missing>";
        self.synchronize();
    }
    else
    {
        struct_decl.decl.name = self.current_token.lexeme;
        self.advance();
    }



    // Skip whitespace before opening brace
    while (self.current_token.type == TokenType.WHITESPACE ||
           self.current_token.type == TokenType.NEWLINE)
    {
        self.advance();
    }

    // Parse struct body
    if (!self.consume(TokenType.LBRACE, "Expected '{' after struct name"))
    {
        self.synchronize();
        return (AstDecl*)struct_decl;
    }

    // Parse struct members
    while (!self.check(TokenType.RBRACE) && !self.check(TokenType.EOF))
    {
        // Skip whitespace and newlines
        while (self.current_token.type == TokenType.WHITESPACE ||
               self.current_token.type == TokenType.NEWLINE)
        {
            self.advance();
            if (self.check(TokenType.RBRACE) || self.check(TokenType.EOF)) break;
        }

        if (self.check(TokenType.RBRACE) || self.check(TokenType.EOF)) break;

        AstStructMember* member = self.parse_struct_member();
        if (member != null)
        {
            struct_decl.members.push(member);
        }

        // If we're in panic mode, try to recover
        if (self.panic_mode)
        {
            self.synchronize();
        }
    }

    // Consume closing brace
    if (!self.consume(TokenType.RBRACE, "Expected '}' after struct members"))
    {
        // Try to recover by finding the closing brace or EOF
        while (!self.check(TokenType.RBRACE) && !self.check(TokenType.EOF))
        {
            self.advance();
        }
        if (self.check(TokenType.RBRACE)) self.advance();
        // Clear panic mode after recovery attempt
        self.panic_mode = false;
    }

    return (AstDecl*)struct_decl;
}

/**
 * Parse a struct member declaration
 * Syntax: type member_name;
 * Syntax: inline type member_name;
 */
fn AstStructMember* Parser.parse_struct_member(&self)
{
    AstStructMember* member = self.allocate_node(AstStructMember);
    member.node.kind = AST_DECL_STRUCT; // Reusing for member nodes
    member.node.span = self.current_token.span;
    member.is_inline = false;

    // Check for inline keyword
    if (self.check(TokenType.IDENT) && self.current_token.lexeme == "inline")
    {
        member.is_inline = true;
        self.advance();

        // Skip whitespace after inline
        while (self.current_token.type == TokenType.WHITESPACE ||
               self.current_token.type == TokenType.NEWLINE)
        {
            self.advance();
        }
    }

    // Parse type (simplified - just parse as identifier for now)
    member.type = self.parse_type();
    if (member.type == null)
    {
        self.error_at_current("Expected type in struct member");
        return null;
    }

    // Skip whitespace before member name
    while (self.current_token.type == TokenType.WHITESPACE ||
           self.current_token.type == TokenType.NEWLINE)
    {
        self.advance();
    }

    // Parse member name
    if (!self.check(TokenType.IDENT))
    {
        self.error_at_current("Expected member name");
        return null;
    }

    member.name = self.current_token.lexeme;
    self.advance();

    // Skip whitespace before semicolon
    while (self.current_token.type == TokenType.WHITESPACE ||
           self.current_token.type == TokenType.NEWLINE)
    {
        self.advance();
    }

    // Consume semicolon
    if (!self.consume(TokenType.SEMICOLON, "Expected ';' after struct member"))
    {
        // Try to recover
        self.synchronize();
    }

    return member;
}

fn AstDecl* Parser.parse_union_declaration(&self) { return null; }
fn AstDecl* Parser.parse_enum_declaration(&self) { return null; }
fn AstDecl* Parser.parse_const_declaration(&self) { return null; }
fn AstDecl* Parser.parse_function_declaration(&self) { return null; }
fn AstDecl* Parser.parse_variable_declaration(&self) { return null; }
/**
 * Parse a type (simplified implementation)
 * For now, just handle basic identifier types
 */
fn AstType* Parser.parse_type(&self)
{
    // Skip whitespace
    while (self.current_token.type == TokenType.WHITESPACE ||
           self.current_token.type == TokenType.NEWLINE)
    {
        self.advance();
    }

    if (!self.check(TokenType.IDENT) && !self.check(TokenType.TYPE_IDENT) && !self.check(TokenType.CONST_IDENT))
    {
        return null;
    }

    AstTypeIdentifier* type_ident = self.allocate_node(AstTypeIdentifier);
    type_ident.type.node.kind = AST_TYPE_IDENTIFIER;
    type_ident.type.node.span = self.current_token.span;
    type_ident.name = self.current_token.lexeme;
    self.advance();

    return (AstType*)type_ident;
}
fn AstStmt* Parser.parse_return_statement(&self) { return null; }
fn AstStmt* Parser.parse_if_statement(&self) { return null; }
fn AstStmt* Parser.parse_while_statement(&self) { return null; }
fn AstStmt* Parser.parse_for_statement(&self) { return null; }
fn AstStmt* Parser.parse_break_statement(&self) { return null; }
fn AstStmt* Parser.parse_continue_statement(&self) { return null; }
