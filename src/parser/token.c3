// Copyright (c) 2024 C3 Project. All rights reserved.
// Use of this source code is governed by the GNU LGPLv3.0 license
// a copy of which can be found in the LICENSE file.

module parser;

/**
 * Token types for C3 lexer
 * Starting with basic punctuation tokens
 */
enum TokenType : uint
{
    INVALID_TOKEN,

    // Single character tokens
    COMMA,           // ,
    SEMICOLON,       // ;
    LBRACE,          // {
    RBRACE,          // }
    LPAREN,          // (
    RPAREN,          // )
    LBRACKET,        // [
    RBRACKET,        // ]
    LVEC,            // [<
    RVEC,            // >]
    DOT,             // .
    COLON,           // :
    QUESTION,        // ?
    QUESTQUEST,      // ??
    ELVIS,           // ?:
    BANG,            // !
    BANGBANG,        // !!
    TILDE,           // ~
    PLUS,            // +
    MINUS,           // -
    STAR,            // *
    SLASH,           // /
    PERCENT,         // %
    AMPERSAND,       // &
    PIPE,            // |
    CARET,           // ^
    LESS,            // <
    GREATER,         // >
    EQUAL,           // =
    AT,              // @
    HASH,            // #
    DOLLAR,          // $

    // Multi-character tokens
    ARROW,           // ->
    SCOPE,           // ::
    DOTDOT,          // ..
    ELLIPSIS,        // ...
    EQEQ,            // ==
    NOT_EQUAL,       // !=
    LESS_EQ,         // <=
    GREATER_EQ,      // >=
    IMPLIES,         // =>
    AND,             // &&
    CT_AND,          // &&&
    OR,              // ||
    CT_OR,           // |||
    PLUSPLUS,        // ++
    CT_CONCAT,       // +++
    MINUSMINUS,      // --
    SHL,             // <<
    SHR,             // >>

    // Assignment operators
    PLUS_ASSIGN,     // +=
    MINUS_ASSIGN,    // -=
    MULT_ASSIGN,     // *=
    DIV_ASSIGN,      // /=
    MOD_ASSIGN,      // %=
    BIT_AND_ASSIGN,  // &=
    BIT_OR_ASSIGN,   // |=
    BIT_XOR_ASSIGN,  // ^=
    SHL_ASSIGN,      // <<=
    SHR_ASSIGN,      // >>=

    // Literals
    IDENT,           // identifier
    CONST_IDENT,     // CONSTANT_IDENTIFIER
    TYPE_IDENT,      // TypeIdentifier
    AT_IDENT,        // @macro
    AT_CONST_IDENT,  // @MACRO
    AT_TYPE_IDENT,   // @Macro
    HASH_IDENT,      // #macro
    CT_IDENT,        // $macro (compile-time identifier)
    CT_CONST_IDENT,  // $MACRO (compile-time const identifier)
    CT_TYPE_IDENT,   // $Macro (compile-time type identifier)
    BUILTIN,         // $$builtin
    STRING,          // "string"
    CHAR_LITERAL,    // 'c'
    HEX_ARRAY,       // x"4865 6c6c 6f20 776f 726c 6421"
    BASE64_ARRAY,    // b64"SGVsbG8gV29ybGQh"
    INTEGER,         // 123
    REAL,            // 1.23

    // Special tokens
    WHITESPACE,      // space, tab
    NEWLINE,         // \n
    COMMENT_LINE,    // // comment
    COMMENT_BLOCK,   // /* comment */
    DOC_COMMENT,     // <* doc comment *>

    // End of file
    EOF,
}

/**
 * Source location information
 */
struct SourceSpan
{
    uint file_id;
    uint start;     // Absolute offset from start of file
    uint end;       // Absolute offset from start of file (exclusive)
}

/**
 * Token data union for different token types
 */
union TokenData
{
    struct {
        String string;
    }
    struct {
        double real_value;
    }
    struct {
        long int_value;
    }
    struct {
        char char_value;
    }
}

/**
 * A lexed token
 */
struct Token
{
    TokenType type;
    SourceSpan span;
    TokenData data;
    String lexeme;          // Raw text of the token
}
