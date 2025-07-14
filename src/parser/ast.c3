// Copyright (c) 2024 C3 Project. All rights reserved.
// Use of this source code is governed by the GNU LGPLv3.0 license
// a copy of which can be found in the LICENSE file.

module parser;
import std::collections::list;
import std::core::dstring;

/**
 * AST node kinds for different types of nodes
 */
enum AstKind : uint
{
    AST_POISONED,

    // Root node
    AST_TRANSLATION_UNIT,

    // Expressions
    AST_EXPR_LITERAL,
    AST_EXPR_IDENTIFIER,
    AST_EXPR_BINARY_OP,
    AST_EXPR_UNARY_OP,
    AST_EXPR_CALL,
    AST_EXPR_ACCESS,
    AST_EXPR_SUBSCRIPT,
    AST_EXPR_CAST,
    AST_EXPR_TERNARY,
    AST_EXPR_INITIALIZER_LIST,

    // Statements
    AST_STMT_COMPOUND,
    AST_STMT_EXPRESSION,
    AST_STMT_RETURN,
    AST_STMT_IF,
    AST_STMT_WHILE,
    AST_STMT_FOR,
    AST_STMT_FOREACH,
    AST_STMT_SWITCH,
    AST_STMT_CASE,
    AST_STMT_DEFAULT,
    AST_STMT_BREAK,
    AST_STMT_CONTINUE,
    AST_STMT_DEFER,
    AST_STMT_ASSERT,
    AST_STMT_DECLARATION,

    // Declarations
    AST_DECL_FUNCTION,
    AST_DECL_VARIABLE,
    AST_DECL_CONSTANT,
    AST_DECL_STRUCT,
    AST_DECL_UNION,
    AST_DECL_ENUM,
    AST_DECL_TYPEDEF,
    AST_DECL_IMPORT,
    AST_DECL_MODULE,

    // Types
    AST_TYPE_IDENTIFIER,
    AST_TYPE_POINTER,
    AST_TYPE_ARRAY,
    AST_TYPE_FUNCTION,
}

/**
 * Binary operators
 */
enum BinaryOp : uint
{
    BINOP_ADD,
    BINOP_SUB,
    BINOP_MUL,
    BINOP_DIV,
    BINOP_MOD,
    BINOP_EQ,
    BINOP_NE,
    BINOP_LT,
    BINOP_LE,
    BINOP_GT,
    BINOP_GE,
    BINOP_AND,
    BINOP_OR,
    BINOP_BIT_AND,
    BINOP_BIT_OR,
    BINOP_BIT_XOR,
    BINOP_SHL,
    BINOP_SHR,
    BINOP_ASSIGN,
}

/**
 * Unary operators
 */
enum UnaryOp : uint
{
    UNARYOP_PLUS,
    UNARYOP_MINUS,
    UNARYOP_NOT,
    UNARYOP_BIT_NOT,
    UNARYOP_DEREF,
    UNARYOP_ADDR,
    UNARYOP_PRE_INC,
    UNARYOP_PRE_DEC,
    UNARYOP_POST_INC,
    UNARYOP_POST_DEC,
}

/**
 * Base AST node - all AST nodes inherit from this
 */
struct AstNode
{
    AstKind kind;
    SourceSpan span;
    AstNode* parent;    // Parent node for bidirectional traversal
    AstNode* next;      // For linked lists of nodes
}

/**
 * Expression nodes
 */
struct AstExpr
{
    inline AstNode node;
}

struct AstLiteral
{
    inline AstExpr expr;
    union {
        struct {
            String string_value;
        }
        struct {
            long int_value;
        }
        struct {
            double real_value;
        }
        struct {
            char char_value;
        }
        struct {
            bool bool_value;
        }
    }
}

struct AstIdentifier
{
    inline AstExpr expr;
    String name;
}

struct AstBinaryOp
{
    inline AstExpr expr;
    BinaryOp op;
    AstExpr* left;
    AstExpr* right;
}

struct AstUnaryOp
{
    inline AstExpr expr;
    UnaryOp op;
    AstExpr* operand;
}

struct AstCall
{
    inline AstExpr expr;
    AstExpr* function;
    AstExpr** arguments;  // Array of argument expressions
}

struct AstAccess
{
    inline AstExpr expr;
    AstExpr* object;
    String member;
}

struct AstSubscript
{
    inline AstExpr expr;
    AstExpr* array;
    AstExpr* index;
}

struct AstCast
{
    inline AstExpr expr;
    AstType* type;
    AstExpr* operand;
}

struct AstTernary
{
    inline AstExpr expr;
    AstExpr* condition;
    AstExpr* true_expr;
    AstExpr* false_expr;
}

/**
 * Statement nodes
 */
struct AstStmt
{
    inline AstNode node;
}

struct AstCompoundStmt
{
    inline AstStmt stmt;
    AstStmt** statements;  // Array of statements
}

struct AstExpressionStmt
{
    inline AstStmt stmt;
    AstExpr* expression;
}

struct AstReturnStmt
{
    inline AstStmt stmt;
    AstExpr* value;  // May be null for bare return
}

struct AstIfStmt
{
    inline AstStmt stmt;
    AstExpr* condition;
    AstStmt* then_stmt;
    AstStmt* else_stmt;  // May be null
}

struct AstWhileStmt
{
    inline AstStmt stmt;
    AstExpr* condition;
    AstStmt* body;
}

struct AstForStmt
{
    inline AstStmt stmt;
    AstStmt* init;      // May be null
    AstExpr* condition; // May be null
    AstExpr* update;    // May be null
    AstStmt* body;
}

struct AstSwitchStmt
{
    inline AstStmt stmt;
    AstExpr* expression;
    AstStmt** cases;  // Array of case/default statements
}

struct AstCaseStmt
{
    inline AstStmt stmt;
    AstExpr* value;  // null for default case
    AstStmt** statements;
}

struct AstBreakStmt
{
    inline AstStmt stmt;
    String label;  // May be empty
}

struct AstContinueStmt
{
    inline AstStmt stmt;
    String label;  // May be empty
}

/**
 * Declaration nodes
 */
struct AstDecl
{
    inline AstNode node;
    String name;
}

struct AstVarDecl
{
    inline AstDecl decl;
    AstType* type;      // May be null for inferred types
    AstExpr* init;      // May be null
}

struct AstFunctionDecl
{
    inline AstDecl decl;
    AstType* return_type;
    AstVarDecl** parameters;  // Array of parameter declarations
    AstStmt* body;           // May be null for declarations
}

struct AstImportDecl
{
    inline AstDecl decl;
    List{AstIdentifier*} identifiers;  // List of identifier AST nodes for import paths
}

struct AstStructMember
{
    inline AstNode node;
    AstType* type;           // Type of the member
    String name;             // Name of the member
    bool is_inline;          // Whether this is an inline member
}

struct AstStructDecl
{
    inline AstDecl decl;
    bool is_union;           // true for union, false for struct
    List{AstStructMember*} members;  // List of struct members
}

/**
 * Position in source code (line/column, 0-based)
 */
struct SourcePosition
{
    uint line;      // 0-based line number
    uint column;    // 0-based column number (byte offset within line)
}

/**
 * Translation Unit - represents a source file (root AST node)
 */
struct AstTranslationUnit
{
    inline AstNode node;
    String filename;                    // Source file name
    String source_text;                 // Original source code text
    List{AstDecl*} declarations;       // Top-level declarations in the file
    List{uint} line_map;               // Maps line numbers to byte offsets in source_text
}

/**
 * Type nodes
 */
struct AstType
{
    inline AstNode node;
}

struct AstTypeIdentifier
{
    inline AstType type;
    String name;
}

struct AstPointerType
{
    inline AstType type;
    AstType* pointee;
}

struct AstArrayType
{
    inline AstType type;
    AstType* element_type;
    AstExpr* size;  // May be null for unsized arrays
}

/**
 * Union for all AST node types - allows type-safe casting
 */
union AstNodeUnion
{
    AstNode node;
    AstExpr expr;
    AstStmt stmt;
    AstDecl decl;
    AstType type;

    // Root node
    AstTranslationUnit translation_unit;

    // Position types
    SourcePosition source_position;

    // Specific expression types
    AstLiteral literal;
    AstIdentifier identifier;
    AstBinaryOp binary_op;
    AstUnaryOp unary_op;
    AstCall call;
    AstAccess access;
    AstSubscript subscript;
    AstCast cast;
    AstTernary ternary;

    // Specific statement types
    AstCompoundStmt compound_stmt;
    AstExpressionStmt expr_stmt;
    AstReturnStmt return_stmt;
    AstIfStmt if_stmt;
    AstWhileStmt while_stmt;
    AstForStmt for_stmt;
    AstSwitchStmt switch_stmt;
    AstCaseStmt case_stmt;
    AstBreakStmt break_stmt;
    AstContinueStmt continue_stmt;

    // Specific declaration types
    AstVarDecl var_decl;
    AstFunctionDecl function_decl;
    AstImportDecl import_decl;
    AstStructDecl struct_decl;
    AstStructMember struct_member;

    // Specific type types
    AstTypeIdentifier type_identifier;
    AstPointerType pointer_type;
    AstArrayType array_type;
}

/**
 * AST utility functions for traversal and manipulation
 */

/**
 * Set the parent of this node
 */
fn void AstNode.set_parent(&self, AstNode* parent)
{
    self.parent = parent;
}

/**
 * Get the root node (TranslationUnit) by traversing up the tree
 */
fn AstTranslationUnit* AstNode.get_root(&self)
{
    AstNode* current = self;
    while (current.parent != null)
    {
        current = current.parent;
    }

    if (current.kind == AST_TRANSLATION_UNIT)
    {
        return (AstTranslationUnit*)current;
    }

    return null;
}

/**
 * Check if this node is an ancestor of another node
 */
fn bool AstNode.is_ancestor_of(&self, AstNode* descendant)
{
    if (descendant == null) return false;

    AstNode* current = descendant.parent;
    while (current != null)
    {
        if (current == self) return true;
        current = current.parent;
    }

    return false;
}

/**
 * Find the common ancestor with another node
 */
fn AstNode* AstNode.find_common_ancestor(&self, AstNode* other)
{
    if (other == null) return null;

    // Get all ancestors of this node
    AstNode* current = self;
    while (current != null)
    {
        // Check if current is an ancestor of other
        if (current.is_ancestor_of(other) || current == other)
        {
            return current;
        }
        current = current.parent;
    }

    return null;
}

/**
 * TranslationUnit member functions
 */

/**
 * Initialize a translation unit with allocator and source text
 */
fn void AstTranslationUnit.init(&self, String filename, String source_text, Allocator allocator)
{
    self.node.kind = AST_TRANSLATION_UNIT;
    self.node.parent = null;
    self.filename = filename;
    self.source_text = source_text;
    self.declarations.init(allocator);
    self.line_map.init(allocator);

    // Build line map
    self.build_line_map();
}

/**
 * Add a declaration to the translation unit
 */
fn void AstTranslationUnit.add_declaration(&self, AstDecl* decl)
{
    if (decl == null) return;

    decl.node.set_parent((AstNode*)self);
    self.declarations.push(decl);
}

/**
 * Get declaration by index
 */
fn AstDecl* AstTranslationUnit.get_declaration(&self, usz index)
{
    if (index >= self.declarations.len()) return null;
    return self.declarations[index];
}

/**
 * Get number of declarations
 */
fn usz AstTranslationUnit.declaration_count(&self)
{
    return self.declarations.len();
}

/**
 * Build line map from source text
 */
fn void AstTranslationUnit.build_line_map(&self)
{
    // Clear existing line map
    self.line_map.clear();

    // Line 0 always starts at offset 0
    self.line_map.push(0);

    // Scan through source text to find line breaks
    for (usz i = 0; i < self.source_text.len; i++)
    {
        if (self.source_text[i] == '\n')
        {
            // Next line starts after this newline
            self.line_map.push((uint)(i + 1));
        }
    }
}

/**
 * Convert byte offset to line/column position
 */
fn SourcePosition AstTranslationUnit.offset_to_position(&self, uint offset)
{
    SourcePosition pos = { .line = 0, .column = 0 };

    // Find the line containing this offset
    for (usz line = 0; line < self.line_map.len(); line++)
    {
        uint line_start = self.line_map[line];

        // Check if this is the last line or if offset is before next line
        if (line + 1 >= self.line_map.len() || offset < self.line_map[line + 1])
        {
            pos.line = (uint)line;
            pos.column = offset - line_start;
            break;
        }
    }

    return pos;
}

/**
 * Convert line/column position to byte offset
 */
fn uint AstTranslationUnit.position_to_offset(&self, SourcePosition pos)
{
    if ((usz)pos.line >= self.line_map.len())
    {
        // Line beyond end of file, return end of file offset
        return (uint)self.source_text.len;
    }

    uint line_start = self.line_map[pos.line];
    uint offset = line_start + pos.column;

    // Clamp to end of file
    if ((usz)offset > self.source_text.len)
    {
        offset = (uint)self.source_text.len;
    }

    return offset;
}

/**
 * Find AST node at given line/column position
 */
fn AstNode* AstTranslationUnit.find_node_at_position(&self, SourcePosition pos)
{
    uint offset = self.position_to_offset(pos);
    return self.find_node_at_offset(offset);
}

/**
 * Find AST node at given byte offset
 */
fn AstNode* AstTranslationUnit.find_node_at_offset(&self, uint offset)
{
    // Start search from the translation unit itself
    return self.find_deepest_node_at_offset((AstNode*)self, offset);
}

/**
 * Recursively find the deepest (most specific) AST node containing the given offset
 */
fn AstNode* AstTranslationUnit.find_deepest_node_at_offset(&self, AstNode* node, uint offset)
{
    if (node == null) return null;

    // Special handling for TranslationUnit - search its children directly
    if (node.kind == AST_TRANSLATION_UNIT)
    {
        AstTranslationUnit* tu = (AstTranslationUnit*)node;
        for (usz i = 0; i < tu.declarations.len(); i++)
        {
            AstNode* child_result = self.find_deepest_node_at_offset((AstNode*)tu.declarations[i], offset);
            if (child_result != null)
            {
                return child_result;
            }
        }
        // If no child contains the offset, return null (don't return TranslationUnit)
        return null;
    }

    // For other nodes, check if offset is within this node's span
    if (offset < node.span.start || offset >= node.span.end)
    {
        return null;
    }

    // This node contains the offset, now check if any children contain it more specifically
    AstNode* best_child = null;

    // Check different node types for children
    switch (node.kind)
    {
        case AST_DECL_IMPORT:
            AstImportDecl* import_decl = (AstImportDecl*)node;
            for (usz i = 0; i < import_decl.identifiers.len(); i++)
            {
                AstNode* child_result = self.find_deepest_node_at_offset((AstNode*)import_decl.identifiers[i], offset);
                if (child_result != null)
                {
                    best_child = child_result;
                }
            }

        case AST_EXPR_BINARY_OP:
            AstBinaryOp* binary = (AstBinaryOp*)node;
            AstNode* left_result = self.find_deepest_node_at_offset((AstNode*)binary.left, offset);
            if (left_result != null) best_child = left_result;

            AstNode* right_result = self.find_deepest_node_at_offset((AstNode*)binary.right, offset);
            if (right_result != null) best_child = right_result;

        case AST_EXPR_UNARY_OP:
            AstUnaryOp* unary = (AstUnaryOp*)node;
            AstNode* operand_result = self.find_deepest_node_at_offset((AstNode*)unary.operand, offset);
            if (operand_result != null) best_child = operand_result;

        default:
            // For other node types, we don't traverse children yet
            // This can be extended as needed
    }

    // Return the most specific child found, or this node if no children contain the offset
    return best_child != null ? best_child : node;
}

/**
 * ImportDecl member functions
 */

/**
 * Initialize an import declaration with allocator
 */
fn void AstImportDecl.init(&self, Allocator allocator)
{
    self.node.kind = AST_DECL_IMPORT;
    self.name = ""; // Import declarations don't have a single name
    self.identifiers.init(allocator);
}

/**
 * Add an identifier to the import declaration
 */
fn void AstImportDecl.add_identifier(&self, AstIdentifier* identifier)
{
    if (identifier == null) return;

    identifier.expr.node.set_parent((AstNode*)self);
    self.identifiers.push(identifier);
}

/**
 * Get identifier by index
 */
fn AstIdentifier* AstImportDecl.get_identifier(&self, usz index)
{
    if (index >= self.identifiers.len()) return null;
    return self.identifiers[index];
}

/**
 * Get number of identifiers
 */
fn usz AstImportDecl.identifier_count(&self)
{
    return self.identifiers.len();
}

/**
 * Get the full import path as a string (e.g., "std::io::file")
 */
fn String AstImportDecl.get_path_string(&self, Allocator allocator)
{
    if (self.identifiers.len() == 0) return "";

    DString path_builder = dstring::new_with_capacity(allocator, 256);

    for (usz i = 0; i < self.identifiers.len(); i++)
    {
        if (i > 0) path_builder.append("::");
        path_builder.append(self.identifiers[i].name);
    }

    return path_builder.str_view();
}

/**
 * AST utility functions for traversal and manipulation
 */

/**
 * Set the parent of a node and add it as a child to the parent
 */
fn void ast_set_parent(AstNode* child, AstNode* parent)
{
    if (child == null) return;
    child.parent = parent;
}

/**
 * Get the root node (TranslationUnit) by traversing up the tree
 */
fn AstTranslationUnit* ast_get_root(AstNode* node)
{
    if (node == null) return null;

    AstNode* current = node;
    while (current.parent != null)
    {
        current = current.parent;
    }

    if (current.kind == AST_TRANSLATION_UNIT)
    {
        return (AstTranslationUnit*)current;
    }

    return null;
}

/**
 * Check if a node is an ancestor of another node
 */
fn bool ast_is_ancestor(AstNode* ancestor, AstNode* descendant)
{
    if (ancestor == null || descendant == null) return false;

    AstNode* current = descendant.parent;
    while (current != null)
    {
        if (current == ancestor) return true;
        current = current.parent;
    }

    return false;
}

/**
 * Find the common ancestor of two nodes
 */
fn AstNode* ast_find_common_ancestor(AstNode* node1, AstNode* node2)
{
    if (node1 == null || node2 == null) return null;

    // Get all ancestors of node1
    AstNode* current = node1;
    while (current != null)
    {
        // Check if current is an ancestor of node2
        if (ast_is_ancestor(current, node2) || current == node2)
        {
            return current;
        }
        current = current.parent;
    }

    return null;
}
