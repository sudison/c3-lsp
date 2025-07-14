// Copyright (c) 2024 C3 Project. All rights reserved.
// Use of this source code is governed by the GNU LGPLv3.0 license
// a copy of which can be found in the LICENSE file.

module parser;
import std::collections::list;

/**
 * AST node kinds for different types of nodes
 */
enum AstKind : uint
{
    AST_POISONED,
    
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
    AstNode* next;  // For linked lists of nodes
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
    List{String} paths;      // Dynamic list of import paths (e.g., ["std::io", "std::core::mem"])
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
