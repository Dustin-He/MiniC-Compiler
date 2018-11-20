%{
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "tree.h"

int yylex(void);
void yyerror(char*);

extern FILE* yyin;
extern FILE* yyout;
extern int lineno;
extern char* yytext;

struct TreeNode* root;
%}

%union {
	int val;
	char* str;
	struct TreeNode* node;
};

%token <str>	EOL  VAR  END  IF  GOTO  PARAM  CALL  RETURN
%token <val>	NUM
%token <str>	ID_TMP  ID_PARAM  ID_NATIVE  ID_LABEL  ID_FUNC
%token <val>	ASSIGN  OP_BI_LOGIC  OP_BI_ARITH  OP_UNI
%token <str>	ARR_L  ARR_R  COLON

%type <node>	Goal  FuncVarDefnList
%type <node>	FuncDefn  VarDefn  ExprList
%type <node>	Expr  RVal
%type <node>	Integer  Id

%%

Goal	: FuncVarDefnList {
		$$ = alloc_treenode(TN_ROOT, NULL, -1);
		root = $$;
		$$->child[0] = $1;
		for (struct TreeNode* tmp_node = $1; tmp_node != NULL; tmp_node = tmp_node->nxt)
			tmp_node->parent = $$;
	}
	;

FuncVarDefnList	: 		{ $$ = NULL; }
	| EOL FuncVarDefnList	{ $$ = $2; }
	| VarDefn EOL FuncVarDefnList {
		$$ = $1;
		$1->nxt = $3;
		if ($3 != NULL)
			$3->prv = $1;
	}
	| FuncDefn EOL FuncVarDefnList {
		$$ = $1;
		$1->nxt = $3;
		if ($3 != NULL)
			$3->prv = $1;
	}
	;

FuncDefn	: Id ARR_L Integer ARR_R EOL ExprList END Id {
		$$ = alloc_treenode(TN_FUNC, $1->str, $3->val);
		free_treenode($1);
		free_treenode($3);
		$$->child[0] = $6;
		for (struct TreeNode* tmp_node = $6; tmp_node != NULL; tmp_node = tmp_node->nxt)
			tmp_node->parent = $$;
	}
	;

ExprList	:	{ $$ = NULL; }
	| EOL ExprList	{ $$ = $2; }
	| VarDefn EOL ExprList {
		$$ = $1;
		$1->nxt = $3;
		if ($3 != NULL)
			$3->prv = $1;
	}
	| Expr EOL ExprList {
		$$ = $1;
		$1->nxt = $3;
		if ($3 != NULL)
			$3->prv = $1;
	}
	;

Expr	: Id ASSIGN RVal OP_BI_LOGIC RVal {
		$$ = alloc_treenode(TN_EXPR_BI_LOGIC, $1->str, $4);
		free_treenode($1);
		$$->child[0] = $3;
		$3->parent = $$;
		$$->child[0] = $5;
		$5->parent = $$;
	}
	| Id ASSIGN RVal OP_BI_ARITH RVal {
		$$ = alloc_treenode(TN_EXPR_BI_ARITH, $1->str, $4);
		free_treenode($1);
		$$->child[0] = $3;
		$3->parent = $$;
		$$->child[0] = $5;
		$5->parent = $$;
	}
	| Id ASSIGN OP_BI_ARITH RVal {
		switch ($3)
		{
		case OP_ADD: $$ = alloc_treenode(TN_EXPR_UNI_ARITH, $1->str, OP_POS); break;
		case OP_SUB: $$ = alloc_treenode(TN_EXPR_UNI_ARITH, $1->str, OP_NEG); break;
		default: yyerror("wrong syntax.");
		}
		free_treenode($1);
		$$->child[0] = $4;
		$4->parent = $$;
	}
	| Id ASSIGN OP_UNI RVal {
		$$ = alloc_treenode(TN_EXPR_UNI_LOGIC, $1->str, $3);
		free_treenode($1);
		$$->child[0] = $4;
		$4->parent = $$;
	}
	| Id ASSIGN RVal {
		$$ = alloc_treenode(TN_EXPR_ASSN, $1->str, -1);
		free_treenode($1);
		$$->child[0] = NULL;
		$$->child[1] = $3;
		$3->parent = $$;
		$$->child[2] = NULL;
	}
	| Id ARR_L RVal ARR_R ASSIGN RVal {
		$$ = alloc_treenode(TN_EXPR_ASSN, $1->str, -1);
		free_treenode($1);
		$$->child[0] = $3;
		$3->parent = $$;
		$$->child[1] = $6;
		$6->parent = $$;
		$$->child[2] = NULL;
	}
	| Id ASSIGN Id ARR_L RVal ARR_R {
		$$ = alloc_treenode(TN_EXPR_ASSN, $1->str, -1);
		free_treenode($1);
		$$->child[0] = NULL;
		$$->child[1] = $3;
		$3->parent = $$;
		$$->child[2] = $5;
		$5->parent = $$;
	}
	| IF RVal OP_BI_LOGIC RVal GOTO Id {
		$$ = alloc_treenode(TN_EXPR_IF_GOTO, $6->str, $3);
		free_treenode($6);
		$$->child[0] = $2;
		$2->parent = $$;
		$$->child[1] = $4;
		$4->parent = $$;
	}
	| GOTO Id {
		$$ = alloc_treenode(TN_EXPR_GOTO, $2->str, -1);
		free_treenode($2);
	}
	| Id COLON {
		$$ = alloc_treenode(TN_EXPR_LABEL, $1->str, -1);
		free_treenode($1);
	}
	| PARAM RVal {
		$$ = alloc_treenode(TN_EXPR_PARAM, NULL, -1);
		$$->child[0] = $2;
		$2->parent = $$;
	}
	| Id ASSIGN CALL Id {
		$$ = alloc_treenode(TN_EXPR_CALL, $1->str, -1);
		free_treenode($1);
		$$->child[0] = $4;
		$4->parent = $$;
	}
	| RETURN RVal {
		$$ = alloc_treenode(TN_EXPR_RETURN, NULL, -1);
		$$->child[0] = $2;
		$2->parent = $$;
	}
	;

RVal	: Id		{ $$ = $1; }
	| Integer	{ $$ = $1; }
	;

VarDefn	: VAR Id {
		$$ = alloc_treenode(TN_VAR, $2->str, -1);
		free_treenode($2);
	}
	| VAR Integer Id {
		$$ = alloc_treenode(TN_VAR, $3->str, $2->val);
		free_treenode($2);
		free_treenode($3);
	}
	;

Integer	: NUM		{ $$ = alloc_treenode(TN_NUM, NULL, $1); }
	;

Id	: ID_TMP	{ $$ = alloc_treenode(TN_ID, $1, -1); }
	| ID_PARAM	{ $$ = alloc_treenode(TN_ID, $1, -1); }
	| ID_NATIVE	{ $$ = alloc_treenode(TN_ID, $1, -1); }
	| ID_FUNC	{ $$ = alloc_treenode(TN_ID, $1, -1); }
	| ID_LABEL	{ $$ = alloc_treenode(TN_ID, $1, -1); }
	;

%%

void yyerror(char* s)
{
	fprintf(stderr, ">> ERROR@L%d: %s\n", lineno, s);
	exit(-3);
}

int main(int argc, char** argv)
{
	char *infile_path = NULL, *outfile_path = NULL;
	lineno = 1;
	for (int i = 1; i < argc; i++)
	{
		if (strcmp(argv[i], "--infile") == 0 || strcmp(argv[i], "--input") == 0
			|| strcmp(argv[i], "-I") == 0)
		{
			if (i + 1 >= argc)
			{
				fprintf(stderr, "No input file\n");
				return -1;
			}
			yyin = fopen(argv[i+1], "r");
			if (yyin == NULL)
			{
				fprintf(stderr, "Cannot open file: %s\nPlease check if it is valid\n",
					argv[i+1]);
				return -1;
			}
			i++;
			infile_path = argv[i];
			continue;
		}
		if (strcmp(argv[i], "--outfile") == 0 || strcmp(argv[i], "--output") == 0
			|| strcmp(argv[i], "-O") == 0)
		{
			if (i + 1 >= argc)
			{
				fprintf(stderr, "No output file\n");
				return -1;
			}
			yyout = fopen(argv[i+1], "w");
			if (yyout == NULL)
			{
				fprintf(stderr, "Cannot open file: %s\nPlease check if it is valid\n",
					argv[i+1]);
				return -1;
			}
			i++;
			outfile_path = argv[i];
			continue;
		}
		fprintf(stderr, "Unknown option: %s\n", argv[i]);
		return -2;
	}

	init_tree();
	yyparse();
	print_tree(root, 1, stdout);

	if (yyin != stdin)
		fclose(yyin);
	if (yyout != stdout)
		fclose(yyout);
	return 0;
}
