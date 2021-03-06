/* -*-C++-*- */
/*
 * PDDL parser.
 *
 * Copyright (C) 2002-2004 Carnegie Mellon University
 * Written by H�kan L. S. Younes.
 *
 * Permission is hereby granted to distribute this software for
 * non-commercial research purposes, provided that this copyright
 * notice is included with any such distribution.
 *
 * THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
 * EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE
 * SOFTWARE IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU
 * ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.
 *
 * $Id: pddl.yy,v 6.9 2003-12-05 23:17:07 lorens Exp $
 */

%defines /* instructs to generate an include file 'pddl.hh' */

%{
#include "plans.h"
#include "orderings.h"
#include "requirements.h"
#include "problems.h"
#include "domains.h"
#include "formulas.h"
#include "types.h"
#include <typeinfo>
#include <utility>
#include <cstdlib>
#include <iostream>

/* Enable Bison debugging. */
#define YYDEBUG 1

/* Workaround for bug in Bison 1.35 that disables stack growth. */
#define YYLTYPE_IS_TRIVIAL 1

/* Name of package */
#define PACKAGE "vhpop"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "lorens@cs.cmu.edu"

/* Define to the full name of this package. */
#define PACKAGE_NAME "VHPOP"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "VHPOP 3.0"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "vhpop"

/* Define to the version of this package. */
#define PACKAGE_VERSION "3.0"

/*
 * Context of free variables.
 */
struct Context {
  void push_frame() {
    frames_.push_back(VariableMap());
  }

  void pop_frame() {
    frames_.pop_back();
  }

  void insert(const std::string& name, const Variable& v) {
    frames_.back().insert(std::make_pair(name, v));
  }

  const Variable* shallow_find(const std::string& name) const {
    VariableMap::const_iterator vi = frames_.back().find(name);
    if (vi != frames_.back().end()) {
      return &(*vi).second;
    } else {
      return 0;
    }
  }

  /* Find the Variable given by the name in the context. */
  const Variable* find(const std::string& name) const {
    for (std::vector<VariableMap>::const_reverse_iterator fi =
       frames_.rbegin(); fi != frames_.rend(); fi++) {
      VariableMap::const_iterator vi = (*fi).find(name);
      if (vi != (*fi).end()) {
    return &(*vi).second;
      }
    }
    return 0;
  }

  /* Find the name of the Variable in the context. */
  const std::string* find(const Variable& variable) const 
  {
      for (std::vector<VariableMap>::const_reverse_iterator fi = frames_.rbegin(); fi != frames_.rend(); ++fi)
      {
          for (VariableMap::const_iterator vi = (*fi).begin(); vi != (*fi).end(); ++vi)
          {
              Variable declared = vi->second;
              if (declared == variable) {
                  return &(vi->first);
              }
          }
      }
      return 0;
  }

private:
  struct VariableMap : public std::map<std::string, Variable> {
  };

  std::vector<VariableMap> frames_;
};

/* The lexer. */
extern int yylex();

/* Current line number. */
extern size_t line_number;

/* Name of current file. */
extern std::string current_file;

/* Level of warnings. */
extern int warning_level;

/* Whether the last parsing attempt succeeded. */
static bool success = true;

/* Current domain. */
static Domain* domain;

/* Domains. */
static std::map<std::string, Domain*> domains;

/* Problem being parsed, or 0 if no problem is being parsed. */
static Problem* problem;

/* Current requirements. */
static Requirements* requirements;

/* Predicate being parsed. */
static const Predicate* predicate;

/* Whether predicate declaration is repeated. */
static bool repeated_predicate;

/* Function being parsed. */
static const Function* function;

/* Whether function declaration is repeated. */
static bool repeated_function;

/* Action being parsed, or 0 if no action is being parsed. */
static ActionSchema* action;

/* Action corresponding to the pseudo-step being parsed, or 0 if no pseudo-step is being parsed. */
static const ActionSchema* pseudo_step_action;

/* Decomposition schema being parsed, or 0 if no decomposition is being parsed. */
static DecompositionSchema* decomposition;

/* A map that tracks pseudo-steps for the decomposition schema currently being parsed. */
static std::map<const std::string, const Step*> decomposition_pseudo_steps;

/* Time of current condition. */ 
static FormulaTime formula_time; 

/* Time of current effect. */
static Effect::EffectTime effect_time;

/* Condition for effect being parsed, or 0 if unconditional effect. */
static const Formula* effect_condition; 

/* Current variable context. */
static Context context;

/* Predicate for atomic formula being parsed. */
static const Predicate* atom_predicate;

/* Whether the predicate of the currently parsed atom was undeclared. */
static bool undeclared_atom_predicate;

/* Whether parsing metric fluent. */
static bool metric_fluent;

/* Function for fluent being parsed. */
static const Function* fluent_function;

/* Whether the function of the currently parsed fluent was undeclared. */
static bool undeclared_fluent_function;

/* Paramerers for atomic formula or fluent being parsed. */
static TermList term_parameters;

/* Quantified variables for effect or formula being parsed. */
static TermList quantified;

/* Kind of name map being parsed. */
static enum { TYPE_KIND, CONSTANT_KIND, OBJECT_KIND, VOID_KIND } name_kind;

/* Outputs an error message. */
static void yyerror(const std::string& s); 

/* Outputs a warning message. */
static void yywarning(const std::string& s);

/* Creates an empty domain with the given name. */
static void make_domain(const std::string* name);

/* Creates an empty problem with the given name. */
static void make_problem(const std::string* name, const std::string* domain_name);

/* Adds :typing to the requirements. */
static void require_typing();

/* Adds :fluents to the requirements. */
static void require_fluents();

/* Adds :disjunctive-preconditions to the requirements. */
static void require_disjunction();

/* Adds :duration-inequalities to the requirements. */
static void require_duration_inequalities();

/* Adds: :durative-actions to the requirements. */
static void require_durative_actions();

/* Adds: :decompositions to the requirements. */
static void require_decompositions();

/* Returns a simple type with the given name. */
static const Type& make_type(const std::string* name);

/* Returns the union of the given types. */
static Type make_type(const TypeSet& types);

/* Returns a simple term with the given name. */
static Term make_term(const std::string* name);

/* Creates a predicate with the given name. */
static void make_predicate(const std::string* name);

/* Creates a function with the given name. */
static void make_function(const std::string* name);

/* Creates an action with the given name. */
static void make_action(const std::string* name, bool durative, bool composite);

/* Adds the current action to the current domain. */ 
static void add_action();

/* Creates a decomposition for the given composite action name with the given name. */
static void make_decomposition(const std::string* composite_action_name, const std::string* name);

/* Adds the current decomposition to the current domain. */
static void add_decomposition();

/* Prepares for the parsing of a pseudo-step. */
static void prepare_pseudostep(const std::string* pseudo_step_action_name);

/* Creates the pseudo-step just parsed. */
static const Step* make_pseudostep();

/* Adds a pseudo-step to the current decomposition. */
static void add_pseudo_step(const Step& pseudo_step);

/* Registers the relevant dummy initial and final steps to the pseudo-steps of the current 
   decomposition. */
static void register_dummy_pseudo_steps();

/* Checks that each named pseudo-step exists, and returns a pair of respective references to 
   them if they do */
static std::pair<const Step*, const Step*> 
make_pseudo_step_pair(const std::string* pseudo_step_name1, const std::string* pseudo_step_name2);

/* Creates an ordering from pseudo-steps with the parameter names. */
static const Ordering* make_ordering(const std::string* pseudo_step_name1, 
    const std::string* pseudo_step_name2);

/* Adds an ordering to the current decomposition. */
static void add_ordering(const Ordering& ordering);

/* Returns a binding between the terms, or 0 if they cannot be bound. Two terms cannot be bound 
   if they are incompatible types or if they're both objects (neither one is a variable). */
static Binding* bind_terms(const Term& first, int first_id, const Term& second, int second_id);

/* Creates a causal link between the pseudo-steps with the parameter names, 
   over the given literal. */
static const Link* make_link(const std::string* pseudo_step_name1,
    const Literal& literal, const std::string* pseudo_step_name2);

/* Adds a link to the current decomposition. */
static void add_link(const Link& link);

/* Prepares for the parsing of a universally quantified effect. */ 
static void prepare_forall_effect();

/* Prepares for the parsing of a conditional effect. */ 
static void prepare_conditional_effect(const Formula& condition);

/* Adds types, constants, or objects to the current domain or problem. */
static void add_names(const std::vector<const std::string*>* names,
              const Type& type);

/* Adds variables to the current variable list. */
static void add_variables(const std::vector<const std::string*>* names,
              const Type& type);

/* Prepares for the parsing of an atomic formula. */ 
static void prepare_atom(const std::string* name);

/* Prepares for the parsing of a fluent. */ 
static void prepare_fluent(const std::string* name);

/* Adds a term with the given name to the current atomic formula. */
static void add_term(const std::string* name);

/* Creates the atomic formula just parsed. */
static const Atom* make_atom();

/* Creates the fluent just parsed. */
static const Fluent* make_fluent();

/* Creates a subtraction. */
static const Expression* make_subtraction(const Expression& term,
                      const Expression* opt_term);

/* Creates an equality formula. */
static const Formula* make_equality(const Term* term1, const Term* term2);

/* Creates a negation. */
static const Formula* make_negation(const Formula& negand);

/* Prepares for the parsing of an existentially quantified formula. */
static void prepare_exists();

/* Prepares for the parsing of a universally quantified formula. */
static void prepare_forall();

/* Creates an existentially quantified formula. */
static const Formula* make_exists(const Formula& body);

/* Creates a universally quantified formula. */
static const Formula* make_forall(const Formula& body);

/* Adds the given literal as an effect to the currect action. */
static void add_effect(const Literal& literal);

/* Pops the top-most universally quantified variables. */
static void pop_forall_effect();

/* Adds a timed initial literal to the current problem. */
static void add_init_literal(float time, const Literal& literal);
%}

%token DEFINE DOMAIN_TOKEN PROBLEM
%token REQUIREMENTS TYPES CONSTANTS PREDICATES FUNCTIONS
%token STRIPS TYPING NEGATIVE_PRECONDITIONS DISJUNCTIVE_PRECONDITIONS EQUALITY
%token EXISTENTIAL_PRECONDITIONS UNIVERSAL_PRECONDITIONS
%token QUANTIFIED_PRECONDITIONS CONDITIONAL_EFFECTS FLUENTS ADL
%token DURATIVE_ACTIONS DURATION_INEQUALITIES CONTINUOUS_EFFECTS
%token TIMED_INITIAL_LITERALS
%token ACTION PARAMETERS PRECONDITION EFFECT
%token DURATIVE_ACTION DURATION CONDITION
%token PDOMAIN OBJECTS INIT GOAL METRIC
%token WHEN NOT AND OR IMPLY EXISTS FORALL
%token AT OVER START END ALL
%token MINIMIZE MAXIMIZE TOTAL_TIME
%token NUMBER_TOKEN OBJECT_TOKEN EITHER
%token LE GE NAME DURATION_VAR VARIABLE NUMBER
%token ILLEGAL_TOKEN
%token DECOMPOSITIONS COMPOSITE 
%token DECOMPOSITION STEPS LINKS ORDERINGS DECOMPOSITION_NAME

%union {
  const Link* link;
  const Step* step;
  const Ordering* ordering;
  const Formula* formula;
  const Literal* literal;
  const Atom* atom;
  const Expression* expr;
  const Fluent* fluent;
  const Term* term;
  const Type* type;
  TypeSet* types;
  const std::string* str;
  std::vector<const std::string*>* strs;
  float num;
}

%type <link> link
%type <ordering> ordering
%type <step> pseudo_step
%type <formula> da_gd timed_gd timed_gds formula conjuncts disjuncts
%type <literal> name_literal term_formula
%type <atom> atomic_name_formula atomic_term_formula
%type <expr> f_exp opt_f_exp ground_f_exp opt_ground_f_exp
%type <fluent> ground_f_head f_head
%type <term> term
%type <strs> name_seq variable_seq
%type <type> type_spec type
%type <types> types
%type <str> type_name predicate init_predicate function name variable
%type <str> DEFINE DOMAIN_TOKEN PROBLEM
%type <str> WHEN NOT AND OR IMPLY EXISTS FORALL
%type <str> NUMBER_TOKEN OBJECT_TOKEN EITHER
%type <str> AT OVER START END ALL
%type <str> MINIMIZE MAXIMIZE TOTAL_TIME
%type <str> NAME DURATION_VAR VARIABLE
%type <num> NUMBER

%%

pddl_file : { success = true; line_number = 1; } domains_and_problems
              { if (!success) YYERROR; }
          ;

domains_and_problems : /* empty */
                     | domains_and_problems domain_def
                     | domains_and_problems problem_def
                     ;


/* ====================================================================== */
/* Domain definitions. */

domain_def : '(' define '(' domain name ')' { make_domain($5); }
               domain_body ')'
           ;

domain_body : /* empty */
            | require_def
            | require_def domain_body2
            | domain_body2
            ;

domain_body2 : types_def
             | types_def domain_body3
             | domain_body3
             ;

domain_body3 : constants_def
             | predicates_def
             | functions_def
             | constants_def domain_body4
             | predicates_def domain_body5
             | functions_def domain_body6
             | structure_defs
             ;

domain_body4 : predicates_def
             | functions_def
             | predicates_def domain_body7
             | functions_def domain_body8
             | structure_defs
             ;

domain_body5 : constants_def
             | functions_def
             | constants_def domain_body7
             | functions_def domain_body9
             | structure_defs
             ;

domain_body6 : constants_def
             | predicates_def
             | constants_def domain_body8
             | predicates_def domain_body9
             | structure_defs
             ;

domain_body7 : functions_def 
             | functions_def structure_defs
             | structure_defs
             ;

domain_body8 : predicates_def
             | predicates_def structure_defs
             | structure_defs
             ;

domain_body9 : constants_def
             | constants_def structure_defs
             | structure_defs
             ;

structure_defs : structure_def
               | structure_defs structure_def
               ;

structure_def : action_def
              | decomposition_def
              ;

require_def : '(' REQUIREMENTS require_keys ')'
            ;

require_keys : require_key
             | require_keys require_key
             ;

require_key : STRIPS                    { requirements->strips = true; }
            | TYPING                    { requirements->typing = true; }
            | NEGATIVE_PRECONDITIONS    { requirements->negative_preconditions = true; }
            | DISJUNCTIVE_PRECONDITIONS { requirements->disjunctive_preconditions = true; }
            | EQUALITY                  { requirements->equality = true; }
            | EXISTENTIAL_PRECONDITIONS { requirements->existential_preconditions = true; }
            | UNIVERSAL_PRECONDITIONS   { requirements->universal_preconditions = true; }
            | QUANTIFIED_PRECONDITIONS  { requirements->quantified_preconditions(); }
            | CONDITIONAL_EFFECTS       { requirements->conditional_effects = true; }
            | FLUENTS                   { requirements->fluents = true; }
            | ADL                       { requirements->adl(); }
            | DURATIVE_ACTIONS          
                {
                    if(requirements->decompositions == true) {
                        yyerror(":durative-actions cannot be combined with :decompositions at this time");
                    }
                    
                    else{
                        requirements->durative_actions = true; 
                    }
                }
            | DURATION_INEQUALITIES     { requirements->duration_inequalities = true; }
            | CONTINUOUS_EFFECTS        { yyerror("`:continuous-effects' not supported"); }
            | TIMED_INITIAL_LITERALS
                {
                    requirements->durative_actions = true;
                    requirements->timed_initial_literals = true;
                }
            | DECOMPOSITIONS            
                {
                    if(requirements->durative_actions == true) {
                        yyerror(":decompositions cannot be combined with :durative-actions at this time");
                    }

                    else {
                        requirements->decompositions = true; 
                    }
                }
            ;

types_def : '(' TYPES { require_typing(); name_kind = TYPE_KIND; }
              typed_names ')' { name_kind = VOID_KIND; }
          ;

constants_def : '(' CONSTANTS { name_kind = CONSTANT_KIND; } typed_names ')'
                  { name_kind = VOID_KIND; }
              ;

predicates_def : '(' PREDICATES predicate_decls ')'
               ;

functions_def : '(' FUNCTIONS { require_fluents(); } function_decls ')'
              ;


/* ====================================================================== */
/* Predicate and function declarations. */

predicate_decls : /* empty */
                | predicate_decls predicate_decl
                ;

predicate_decl : '(' predicate { make_predicate($2); } variables ')'
                   { predicate = 0; }
               ;

function_decls : /* empty */
               | function_decl_seq
               | function_decl_seq function_type_spec function_decls
               ;

function_decl_seq : function_decl
                  | function_decl_seq function_decl
                  ;

function_type_spec : '-' { require_typing(); } function_type
                   ;

function_decl : '(' function { make_function($2); } variables ')'
                  { function = 0; }
              ;


/* ====================================================================== */
/* Actions. */

action_def : '(' ACTION name { make_action($3, false, false); } parameters action_body ')' { add_action(); }
           | '(' DURATIVE_ACTION name { require_durative_actions(); make_action($3, true, false); } 
                 parameters DURATION duration_constraint da_body ')' { add_action(); }
           ;
               
parameters : /* empty */
           | PARAMETERS '(' variables ')'
           ;

action_body : precondition action_body2
            | action_body2
            ;

action_body2 : effect action_body3
             | action_body3
             ;

action_body3 : /* empty */
             | composite
             ;

precondition : PRECONDITION { formula_time = AT_START; } formula { action->set_condition(*$3); }
             ;

effect : EFFECT { effect_time = Effect::AT_END; } eff_formula
       ;

composite : COMPOSITE 't' { require_decompositions(); action->set_composite(true); }
          | COMPOSITE 'f' { require_decompositions(); action->set_composite(false); }
          ;

da_body : CONDITION da_gd da_body2 { action->set_condition(*$2); }
        | da_body2
        ;

da_body2 : /* empty */
         | EFFECT da_effect
         ;


/* ====================================================================== */
/* Decompositions. */

decomposition_def : '(' DECOMPOSITION name                                     
                        DECOMPOSITION_NAME name           { make_decomposition($3, $5); }
                        parameters decomposition_body ')' { add_decomposition(); decomposition_pseudo_steps.clear(); }
                  ;

decomposition_body  : STEPS '(' steps ')'                 { register_dummy_pseudo_steps(); }
                      decomposition_body2
                    ;

decomposition_body2 : LINKS '(' links ')' decomposition_body3
                        {
                          if (decomposition->link_list().contains_cycle()) {
                           yyerror("cycle detected in links for decomposition " + decomposition->name());
                          }
                        }
                    | decomposition_body3
                    ;


decomposition_body3 : /* empty */
                    | ORDERINGS '(' orderings ')'         
                        {
                          if (decomposition->ordering_list().contains_cycle()) {
                            yyerror("cycle detected in orderings for decomposition " + decomposition->name());
                          } 
                        }
                    ;

steps : /* empty */
      | steps step
      ;

step  : '(' name pseudo_step ')'       { decomposition_pseudo_steps.insert( std::make_pair(*$2, $3) ); add_pseudo_step(*$3); }
      ;

pseudo_step : '(' name                 { prepare_pseudostep($2); } 
                  terms ')'            { $$ = make_pseudostep(); }
            ;

links : /* empty */
      | links link                     { add_link(*$2); }
      ;

link  : '(' name term_formula name ')' { $$ = make_link($2, *$3, $4); }
      ;

orderings : /* empty*/
          | orderings ordering         { add_ordering(*$2); }
          ;

ordering : '(' name name ')'           { $$ = make_ordering($2, $3); }
         ;

/* ====================================================================== */
/* Duration constraints. */

duration_constraint : simple_duration_constraint
                    | '(' and simple_duration_constraints ')' { require_duration_inequalities(); }
                    ;

simple_duration_constraint : '(' LE duration_var f_exp ')'  { require_duration_inequalities(); action->set_max_duration(*$4); }
                           | '(' GE duration_var f_exp ')'  { require_duration_inequalities(); action->set_min_duration(*$4); }
                           | '(' '=' duration_var f_exp ')' { action->set_duration(*$4); }
                           ;

simple_duration_constraints : /* empty */
                            | simple_duration_constraints
                                simple_duration_constraint
                            ;


/* ====================================================================== */
/* Goals with time annotations. */

da_gd : timed_gd
      | '(' and timed_gds ')' { $$ = $3; }
      ;

timed_gds : /* empty */ { $$ = &Formula::TRUE; }
          | timed_gds timed_gd { $$ = &(*$1 && *$2); }
          ;

timed_gd : '(' at start { formula_time = AT_START; } formula ')' { $$ = $5; }
         | '(' at end { formula_time = AT_END; } formula ')' { $$ = $5; }
         | '(' over all { formula_time = OVER_ALL; } formula ')' { $$ = $5; }
         ;


/* ====================================================================== */
/* Effect formulas. */

eff_formula : term_literal
            | '(' and eff_formulas ')'
            | '(' forall { prepare_forall_effect(); } '(' variables ')' eff_formula ')' { pop_forall_effect(); }
            | '(' when { formula_time = AT_START; } formula { prepare_conditional_effect(*$4); } one_eff_formula ')' { effect_condition = 0; }
            ;

eff_formulas : /* empty */
             | eff_formulas eff_formula
             ;

one_eff_formula : term_literal
                | '(' and term_literals ')'
                ;

term_literal : atomic_term_formula { add_effect(*$1); }
             | '(' not atomic_term_formula ')' { add_effect(Negation::make(*$3)); }
             ;

term_literals : /* empty */
              | term_literals term_literal
              ;

da_effect : timed_effect
          | '(' and da_effects ')'
          | '(' forall { prepare_forall_effect(); }
              '(' variables ')' da_effect ')' { pop_forall_effect(); }
          | '(' when da_gd { prepare_conditional_effect(*$3); }
              timed_effect ')' { effect_condition = 0; }
          ;

da_effects : /* empty */
           | da_effects da_effect
           ;

timed_effect : '(' at start
                 { effect_time = Effect::AT_START; formula_time = AT_START; }
                 a_effect ')'
             | '(' at end
                 { effect_time = Effect::AT_END; formula_time = AT_END; }
                 a_effect ')'
             ;

a_effect : term_literal
         | '(' and a_effects ')'
         | '(' forall { prepare_forall_effect(); }
             '(' variables ')' a_effect ')' { pop_forall_effect(); }
         | '(' when formula { prepare_conditional_effect(*$3); }
             one_eff_formula ')' { effect_condition = 0; }
         ;

a_effects : /* empty */
          | a_effects a_effect
          ;


/* ====================================================================== */
/* Problem definitions. */

problem_def : '(' define '(' problem name ')' '(' PDOMAIN name ')'
                { make_problem($5, $9); } problem_body ')'
                { delete requirements; }
            ;

problem_body : require_def problem_body2
             | problem_body2
             ;

problem_body2 : object_decl problem_body3
              | problem_body3
              ;

problem_body3 : init goal_spec
              | goal_spec
              ;

object_decl : '(' OBJECTS { name_kind = OBJECT_KIND; } typed_names ')'
                { name_kind = VOID_KIND; }
            ;

init : '(' INIT init_elements ')'
     ;

init_elements : /* empty */
              | init_elements init_element
              ;

init_element : '(' init_predicate { prepare_atom($2); } names ')'
                 { problem->add_init_atom(*make_atom()); }
             | '(' AT { prepare_atom($2); } names ')'
                 { problem->add_init_atom(*make_atom()); }
             | '(' not atomic_name_formula ')'
                 { Formula::register_use($3); Formula::unregister_use($3); }
             | '(' '=' ground_f_head NUMBER ')'
                 { problem->add_init_value(*$3, $4); }
             | '(' at NUMBER name_literal ')'
                 { add_init_literal($3, *$4); }
             ;

goal_spec : goal
          | goal metric_spec
          ;

goal : '(' GOAL formula ')' { problem->set_goal(*$3); }
     ;

metric_spec : '(' METRIC maximize { metric_fluent = true; } ground_f_exp ')'
                { problem->set_metric(*$5, true); metric_fluent = false; }
            | '(' METRIC minimize { metric_fluent = true; } ground_f_exp ')'
                { problem->set_metric(*$5); metric_fluent = false; }
            ;


/* ====================================================================== */
/* Formulas. */

formula : atomic_term_formula                                            { $$ = &TimedLiteral::make(*$1, formula_time); }
        | '(' '=' term term ')'                                          { $$ = make_equality($3, $4); }
        | '(' not formula ')'                                            { $$ = make_negation(*$3); }
        | '(' and conjuncts ')'                                          { $$ = $3; }
        | '(' or     { require_disjunction(); } disjuncts ')'            { $$ = $4; }
        | '(' imply  { require_disjunction(); } formula formula ')'      { $$ = &(!*$4 || *$5); }
        | '(' exists { prepare_exists(); } '(' variables ')' formula ')' { $$ = make_exists(*$7); }
        | '(' forall { prepare_forall(); } '(' variables ')' formula ')' { $$ = make_forall(*$7); }
        ;

conjuncts : /* empty */       { $$ = &Formula::TRUE; }
          | conjuncts formula { $$ = &(*$1 && *$2); }
          ;

disjuncts : /* empty */       { $$ = &Formula::FALSE; }
          | disjuncts formula { $$ = &(*$1 || *$2); }
          ;

term_formula : atomic_term_formula { $$ = $1; }
             | '(' not atomic_term_formula ')' { $$ = &Negation::make(*$3); }
             ;

atomic_term_formula : '(' predicate { prepare_atom($2); } terms ')'  { $$ = make_atom(); }
                    ;

atomic_name_formula : '(' predicate { prepare_atom($2); } names ')'  { $$ = make_atom(); }
                    ;

name_literal : atomic_name_formula             { $$ = $1; }
             | '(' not atomic_name_formula ')' { $$ = &Negation::make(*$3); }
             ;


/* ====================================================================== */
/* Function expressions. */

f_exp : NUMBER { $$ = new Value($1); }
      | '(' '+' f_exp f_exp ')' { $$ = &Addition::make(*$3, *$4); }
      | '(' '-' f_exp opt_f_exp ')' { $$ = make_subtraction(*$3, $4); }
      | '(' '*' f_exp f_exp ')' { $$ = &Multiplication::make(*$3, *$4); }
      | '(' '/' f_exp f_exp ')' { $$ = &Division::make(*$3, *$4); }
      | f_head { $$ = $1; }
      ;

opt_f_exp : /* empty */ { $$ = 0; }
          | f_exp
          ;

f_head : '(' function { prepare_fluent($2); } terms ')'
           { $$ = make_fluent(); }
       | function { prepare_fluent($1); $$ = make_fluent(); }
       ;

ground_f_exp : NUMBER { $$ = new Value($1); }
             | '(' '+' ground_f_exp ground_f_exp ')'
                 { $$ = &Addition::make(*$3, *$4); }
             | '(' '-' ground_f_exp opt_ground_f_exp ')'
                 { $$ = make_subtraction(*$3, $4); }
             | '(' '*' ground_f_exp ground_f_exp ')'
                 { $$ = &Multiplication::make(*$3, *$4); }
             | '(' '/' ground_f_exp ground_f_exp ')'
                 { $$ = &Division::make(*$3, *$4); }
             | ground_f_head { $$ = $1; }
             ;

opt_ground_f_exp : /* empty */ { $$ = 0; }
                 | ground_f_exp
                 ;

ground_f_head : '(' function { prepare_fluent($2); } names ')'
                  { $$ = make_fluent(); }
              | function { prepare_fluent($1); $$ = make_fluent(); }
              ;


/* ====================================================================== */
/* Terms and types. */

terms : /* empty */
      | terms name     { add_term($2); }
      | terms variable { add_term($2); }
      ;

names : /* empty */
      | names name { add_term($2); }
      ;

term : name     { $$ = new Term(make_term($1)); }
     | variable { $$ = new Term(make_term($1)); }
     ;

variables : /* empty */
          | variable_seq { add_variables($1, TypeTable::OBJECT); }
          | variable_seq type_spec { add_variables($1, *$2); delete $2; }
              variables
          ;

variable_seq : variable { $$ = new std::vector<const std::string*>(1, $1); }
             | variable_seq variable { $$ = $1; $$->push_back($2); }
             ;

typed_names : /* empty */
            | name_seq { add_names($1, TypeTable::OBJECT); }
            | name_seq type_spec { add_names($1, *$2); delete $2; } typed_names
            ;

name_seq : name { $$ = new std::vector<const std::string*>(1, $1); }
         | name_seq name { $$ = $1; $$->push_back($2); }
         ;

type_spec : '-' { require_typing(); } type { $$ = $3; }
          ;

type : object { $$ = new Type(TypeTable::OBJECT); }
     | type_name { $$ = new Type(make_type($1)); }
     | '(' either types ')' { $$ = new Type(make_type(*$3)); delete $3; }
     ;

types : object { $$ = new TypeSet(); }
      | type_name { $$ = new TypeSet(); $$->insert(make_type($1)); }
      | types object { $$ = $1; }
      | types type_name { $$ = $1; $$->insert(make_type($2)); }
      ;

function_type : number
              ;


/* ====================================================================== */
/* Tokens. */

define : DEFINE { delete $1; }
       ;

domain : DOMAIN_TOKEN { delete $1; }
       ;

problem : PROBLEM { delete $1; }
        ;

when : WHEN { delete $1; }
     ;

not : NOT { delete $1; }
    ;

and : AND { delete $1; }
    ;

or : OR { delete $1; }
   ;

imply : IMPLY { delete $1; }
      ;

exists : EXISTS { delete $1; }
       ;

forall : FORALL { delete $1; }
       ;

at : AT { delete $1; }
   ;

over : OVER { delete $1; }
     ;

start : START { delete $1; }
      ;

end : END { delete $1; }
    ;

all : ALL { delete $1; }
    ;

duration_var : DURATION_VAR { delete $1; }
             ;

minimize : MINIMIZE { delete $1; }
         ;

maximize : MAXIMIZE { delete $1; }
         ;

number : NUMBER_TOKEN { delete $1; }
       ;

object : OBJECT_TOKEN { delete $1; }
       ;

either : EITHER { delete $1; }
       ;

type_name : DEFINE | DOMAIN_TOKEN | PROBLEM
          | EITHER
          | AT | OVER | START | END | ALL
          | MINIMIZE | MAXIMIZE | TOTAL_TIME
          | NAME
          ;

predicate : type_name
          | OBJECT_TOKEN | NUMBER_TOKEN
          ;

init_predicate : DEFINE | DOMAIN_TOKEN | PROBLEM
               | EITHER
               | OVER | START | END | ALL
               | MINIMIZE | MAXIMIZE | TOTAL_TIME
               | NAME
               | OBJECT_TOKEN | NUMBER_TOKEN
               ;

function : name
         ;

name : DEFINE | DOMAIN_TOKEN | PROBLEM
     | NUMBER_TOKEN | OBJECT_TOKEN | EITHER
     | WHEN | NOT | AND | OR | IMPLY | EXISTS | FORALL
     | AT | OVER | START | END | ALL
     | MINIMIZE | MAXIMIZE | TOTAL_TIME
     | NAME
     ;

variable : VARIABLE
         ;

%%

/* Outputs an error message. */
static void yyerror(const std::string& s) {
  std::cerr << PACKAGE ":" << current_file << ':' << line_number << ": " << s
        << std::endl;
  success = false;
}


/* Outputs a warning. */
static void yywarning(const std::string& s) {
  if (warning_level > 0) {
    std::cerr << PACKAGE ":" << current_file << ':' << line_number << ": " << s
          << std::endl;
    if (warning_level > 1) {
      success = false;
    }
  }
}


/* Creates an empty domain with the given name. */
static void make_domain(const std::string* name) {
  domain = new Domain(*name);
  domains[*name] = domain;
  requirements = &domain->requirements;
  problem = 0;
  delete name;
}


/* Creates an empty problem with the given name. */
static void make_problem(const std::string* name,
             const std::string* domain_name) {
  std::map<std::string, Domain*>::const_iterator di =
    domains.find(*domain_name);
  if (di != domains.end()) {
    domain = (*di).second;
  } else {
    domain = new Domain(*domain_name);
    domains[*domain_name] = domain;
    yyerror("undeclared domain `" + *domain_name + "' used");
  }
  requirements = new Requirements(domain->requirements);
  problem = new Problem(*name, *domain);
  delete name;
  delete domain_name;
}


/* Adds :typing to the requirements. */
static void require_typing() {
  if (!requirements->typing) {
    yywarning("assuming `:typing' requirement");
    requirements->typing = true;
  }
}


/* Adds :fluents to the requirements. */
static void require_fluents() {
  if (!requirements->fluents) {
    yywarning("assuming `:fluents' requirement");
    requirements->fluents = true;
  }
}


/* Adds :disjunctive-preconditions to the requirements. */
static void require_disjunction() {
  if (!requirements->disjunctive_preconditions) {
    yywarning("assuming `:disjunctive-preconditions' requirement");
    requirements->disjunctive_preconditions = true;
  }
}


/* Adds :duration-inequalities to the requirements. */
static void require_duration_inequalities() {
  if (!requirements->duration_inequalities) {
    yywarning("assuming `:duration-inequalities' requirement");
    requirements->duration_inequalities = true;
  }
}

/* Adds :durative-actions to the requirements. */
static void require_durative_actions() {

  if(requirements->decompositions == true) {
    yyerror(":durative-actions cannot be combined with :decompositions at this time");
  }

  else {
      if (!requirements->durative_actions) {
        yywarning("assuming `:durative-actions' requirement");
        requirements->durative_actions = true;
      }
  }

}

/* Adds :decompositions to the requirements. */
static void require_decompositions() {

  if(requirements->durative_actions == true) {
    yyerror(":decompositions cannot be combined with :durative-actions at this time");
  }

  else {
      if (!requirements->decompositions) {
        yywarning("assuming `:decompositions' requirement");
        requirements->decompositions = true;
      }
  }

}


/* Returns a simple type with the given name. */
static const Type& make_type(const std::string* name) {
  const Type* t = domain->types().find_type(*name);
  if (t == 0) {
    t = &domain->types().add_type(*name);
    if (name_kind != TYPE_KIND) {
      yywarning("implicit declaration of type `" + *name + "'");
    }
  }
  delete name;
  return *t;
}


/* Returns the union of the given types. */
static Type make_type(const TypeSet& types) {
  return TypeTable::union_type(types);
}


/* Returns a simple term with the given name. */
static Term make_term(const std::string* name) {
  if ((*name)[0] == '?') {
    const Variable* vp = context.find(*name);
    if (vp != 0) {
      delete name;
      return *vp;
    } else {
      Variable v = TermTable::add_variable(TypeTable::OBJECT);
      context.insert(*name, v);
      yyerror("free variable `" + *name + "' used");
      delete name;
      return v;
    }
  } else {
    TermTable& terms = (problem != 0) ? problem->terms() : domain->terms();
    const Object* o = terms.find_object(*name);
    if (o == 0) {
      size_t n = term_parameters.size();
      if (atom_predicate != 0
      && PredicateTable::parameters(*atom_predicate).size() > n) {
    const Type& t = PredicateTable::parameters(*atom_predicate)[n];
    o = &terms.add_object(*name, t);
      } else {
    o = &terms.add_object(*name, TypeTable::OBJECT);
      }
      yywarning("implicit declaration of object `" + *name + "'");
    }
    delete name;
    return *o;
  }
}


/* Creates a predicate with the given name. */
static void make_predicate(const std::string* name) {
  predicate = domain->predicates().find_predicate(*name);
  if (predicate == 0) {
    repeated_predicate = false;
    predicate = &domain->predicates().add_predicate(*name);
  } else {
    repeated_predicate = true;
    yywarning("ignoring repeated declaration of predicate `" + *name + "'");
  }
  delete name;
}


/* Creates a function with the given name. */
static void make_function(const std::string* name) {
  repeated_function = false;
  function = domain->functions().find_function(*name);
  if (function == 0) {
    function = &domain->functions().add_function(*name);
  } else {
    repeated_function = true;
    if (*name == "total-time") {
      yywarning("ignoring declaration of reserved function `" + *name + "'");
    } else {
      yywarning("ignoring repeated declaration of function `" + *name + "'");
    }
  }
  delete name;
}


/* Creates an action with the given name. */
static void make_action(const std::string* name, bool durative, bool composite) {
  if (durative) {
    if (!requirements->durative_actions) {
      yywarning("assuming `:durative-actions' requirement");
      requirements->durative_actions = true;
    }
  }
  context.push_frame();
  action = new ActionSchema(*name, durative, composite);
  delete name;
}


/* Adds the current action to the current domain. */
static void add_action() {
  context.pop_frame();
  if (domain->find_action(action->name()) == 0) {
    action->strengthen_effects(*domain);
    domain->add_action(*action);
  } else {
    yywarning("ignoring repeated declaration of action `"
          + action->name() + "'");
    delete action;
  }
  action = 0;
}

/* Creates a decomposition for the given composite action name with the given name. */
static void make_decomposition(const std::string* composite_action_name, const std::string* name) 
{
    context.push_frame();

    const ActionSchema* composite_action = domain->find_action(*composite_action_name);
    if(composite_action == 0) {
        yyerror("no action labeled " + *composite_action_name + " exists");
    }

    else if(!(composite_action->composite())) {
        yyerror("action " + *composite_action_name + " is not composite");
    }

    else {
        decomposition = new DecompositionSchema(composite_action, *name);
        delete name;
    }
}

/* Adds the current decomposition to the current domain. */
static void add_decomposition()
{
	// Check that there exists a path of causal links from all init dummy effects to all goal dummy preconditions
	// TODO

    context.pop_frame();

    /* If we have not declared this decomposition in the past, */
    if(domain->find_decomposition(decomposition->composite_action_schema().name(), decomposition->name()) == 0) {
        domain->add_decomposition(*decomposition);
    }

    else {
        yywarning("ignoring repeated declaration of decomposition `" 
            + decomposition->name() + "' for composite action `" 
            + decomposition->composite_action_schema().name() + "'");
        delete decomposition;
    }

    decomposition = 0;
}


/* Prepares for the parsing of a pseudo-step. */
static void prepare_pseudostep(const std::string* pseudo_step_action_name) 
{ 
    /* Verify that the action name refers to an existing action. */
    pseudo_step_action = domain->find_action(*pseudo_step_action_name);

    if(pseudo_step_action == 0) {
        yyerror("No action of type " + *pseudo_step_action_name + " exists for pseudo-step definition.");
    }

    else {
        term_parameters.clear();
        delete pseudo_step_action_name;
    }
}


/* Creates the pseudo-step just parsed. */
static const Step* make_pseudostep()
{
    // Check that the arity of the parsed terms matches the arity of the pseudo-step's action.
    size_t n = term_parameters.size();

    if(pseudo_step_action->parameters().size() != n) 
    {
        yyerror("incorrect number of parameters specified for pseudo-step action "
            + pseudo_step_action->name());
    }

    else 
    {
        // Store a reference to the id of this pseudo-step. */
        int pseudo_step_id = -(++Decomposition::next_pseudo_step_id);
        
        // Here, I have to iterate through the parsed terms, and do different things 
        // depending on whether the term is an object constant, or a variable.
        for (TermList::size_type pi = 0; pi < term_parameters.size(); ++pi)
        {
            // Get the parsed Term at this index.
            Term t = term_parameters[pi];

            // Get the variable and type of the action schema at this index. 
            const Variable action_parameter = pseudo_step_action->parameters()[pi];
            const Type typeof_action_parameter = TermTable::type(action_parameter);

            if (t.object()) 
            {
                // Find all the objects compatible with the type of the action schema's parameter at the current index.
                ObjectList ol = domain->terms().compatible_objects(typeof_action_parameter);

                // See if we can find the current term in that list.
                ObjectList::iterator oitr = std::find(ol.begin(), ol.end(), t);
                if (oitr == ol.end()) { // not found!
                    yyerror("type-incompatible object for pseudo-step action parameter");
                }

                else 
                { 
                    // The type of the action schema's parameter at the current index is compatible to the parsed term.
                    // Add a binding to the decomposition, where:
                    // (the action schema's variable and this decomposition's index) are bound to
                    // (this term and the pseudo-step's index)
                    const Binding* new_binding = new Binding(action_parameter, (int) decomposition->id(), t, pseudo_step_id, true);
                    decomposition->add_binding(*new_binding);
                }
            }

            else // t is a variable
            { 
                // Check that the name of this term matches one name on the parameter list of the decomposition schema.
                std::string name_of_term_variable = *context.find(t.as_variable());
                const Variable* parameter_variable_match = 0;

                for (VariableList::const_iterator vi = decomposition->parameters().begin();
                    vi != decomposition->parameters().end();
                    ++vi)
                {
                    std::string name_of_parameter_variable = *context.find(*vi);
                    if (name_of_term_variable == name_of_parameter_variable) {
                        parameter_variable_match = &(*vi);
                    }
                }

                if (parameter_variable_match == 0) {
                    yyerror("variable " + name_of_term_variable + " does not exist in parameter list for decomposition");
                }

                else
                {
                    // Since we have a match, we ignore the term variable altogether, 
                    // because the binding is relative to the parameter of the decomposition.

                    // The parameter variable must be a subtype of the action schema variable.
                    const Variable decomposition_parameter = *parameter_variable_match;
                    const Type typeof_decomposition_parameter = TermTable::type(decomposition_parameter);

                    if (! domain->types().subtype(typeof_decomposition_parameter, typeof_action_parameter)) {
                        yyerror("variable " + name_of_term_variable + " is type-incompatible with pseudo-step action parameater");
                    }

                    // Once I've done that check, add a binding as before.  And then we're done here!
                    const Binding* new_binding = new Binding(decomposition_parameter, (int)decomposition->id(), action_parameter, pseudo_step_id, true);
                    decomposition->add_binding(*new_binding);
                }
            }
        }

        /* At this point we have successfully created all the bindings necessary for the pseudo-step in question. */
        Step* new_pseudo_step = new Step(pseudo_step_id, *pseudo_step_action);
        return new_pseudo_step;
    }
    
    return NULL;
}


/* Adds a pseudo-step to the current decomposition. */
static void add_pseudo_step(const Step& pseudo_step) 
{
    decomposition->add_pseudo_step(pseudo_step);
    pseudo_step_action = 0;
}

/* Registers the relevant dummy initial and final steps to the pseudo-steps of the current 
   decomposition. */
static void register_dummy_pseudo_steps()
{
    const Step  dummy_initial_step = decomposition->pseudo_steps()[0];
	const Step* dummy_initial = new Step(dummy_initial_step);

    const Step  dummy_goal_step = decomposition->pseudo_steps()[1];
	const Step* dummy_final = new Step(dummy_goal_step);

	decomposition_pseudo_steps.insert( std::make_pair(std::string("init"), dummy_initial) );
	decomposition_pseudo_steps.insert( std::make_pair(std::string("goal"), dummy_final) );
}


/* Checks that each named pseudo-step exists, and returns a pair of respective references to 
   them if they do */
static std::pair<const Step*, const Step*> 
make_pseudo_step_pair(const std::string* pseudo_step_name1, const std::string* pseudo_step_name2)
{
    const Step* pseudo_step1;
    const Step* pseudo_step2;
    std::map<const std::string, const Step*>::const_iterator si;

    si = decomposition_pseudo_steps.find(*pseudo_step_name1);
    if (si == decomposition_pseudo_steps.end()) {
        yyerror("psuedo-step" + *pseudo_step_name1 + " referenced in decomposition "
            + decomposition->name() + " does not exist");
    }
    else {
        pseudo_step1 = (*si).second;
    }

    si = decomposition_pseudo_steps.find(*pseudo_step_name2);
    if (si == decomposition_pseudo_steps.end()) {
        yyerror("psuedo-step" + *pseudo_step_name2 + " referenced in decomposition "
            + decomposition->name() + " does not exist");
    }
    else {
        pseudo_step2 = (*si).second;
    }

    return std::make_pair(pseudo_step1, pseudo_step2);
}

/* Creates an ordering from pseudo-steps with the parameter names. */
static const Ordering* make_ordering(const std::string* pseudo_step_name1, const std::string* pseudo_step_name2)
{
    // Check that each decomposition pseudo-step exists, and store references to them if they do
    std::pair<const Step*, const Step*> pseudo_steps = 
        make_pseudo_step_pair(pseudo_step_name1, pseudo_step_name2);

    // Check that the names of the pseudo-steps are not the same. This check is done after 
    // verifying they exist, because it doesn't make sense to check before.
    if (*pseudo_step_name1 == *pseudo_step_name2) {
        yyerror("illegal ordering constraint (cannot order step " + *pseudo_step_name1 
            + " relative to itself in decomposition " + decomposition->name() + ")");
    }

    // Create ordering and return it. I assume that the ordering is constructed in between the end-points.
    return new Ordering(pseudo_steps.first->id(), StepTime::AT_END,
        pseudo_steps.second->id(), StepTime::AT_START);
}

/* Adds an ordering to the current decomposition. */
static void add_ordering(const Ordering& ordering)
{
    decomposition->add_ordering(ordering);
}

/* Returns a binding between the terms, or 0 if they cannot be bound. Two terms cannot be bound 
   if they are incompatible types or if they're both objects (neither one is a variable). */
static Binding* bind_terms(const Term& first, int first_id, const Term& second, int second_id)
{
    // Return zero if both terms are objects.
    if (first.object() && second.object()) {
        return 0;
    }

    else if (first.variable() && second.variable()) 
    {
        // Check for type compatibility.
        Type first_t = TermTable::type(first);
        Type second_t = TermTable::type(second);

        const Type* most_specific = TypeTable::most_specific(first_t, second_t);
        if (most_specific == 0) {
            return 0; // incompatible types
        }

        else
        {
            // The most specific Term will serve as Term for the binding.
            // The other will serve as a Variable.
            if (*most_specific == first_t) {
                return new Binding(first.as_variable(), first_id, second, second_id, true);
            }

            else {
                return new Binding(second.as_variable(), second_id, first, first_id, true);
            }
        }
    }

    else  
    {
        // Only one of them will be a variable (the other will be a term)
        Variable variable = first.variable() ? first.as_variable() : second.as_variable();
        Term term = first.variable() ? second : first;
 
        // Check for type compatibility; the term should be the most specific type, so
        // its type should be the subtype of the variable.
        Type variable_t = TermTable::type(variable);
        Type term_t = TermTable::type(term);

        if (! TypeTable::subtype(term_t, variable_t)) {
            return 0; // incompatible types
        }

        else 
        {
            // return the binding!
            return new Binding(variable, first.variable() ? first_id : second_id,
                               term, first.variable() ? second_id : first_id, true);
        }
    }
}


/* Creates a causal link between the pseudo-steps with the parameter names, 
   over the given literal. */
static const Link* make_link(const std::string* pseudo_step_name1, 
     const Literal& literal, const std::string* pseudo_step_name2)
{
    // Check that each decomposition pseudo-step exists, and store references to them if they do
    std::pair<const Step*, const Step*> pseudo_steps = 
        make_pseudo_step_pair(pseudo_step_name1, pseudo_step_name2);

    // Check that the names of the pseudo-steps are not the same. This check is done after 
    // verifying they exist, because it doesn't make sense to check before.
    if (*pseudo_step_name1 == *pseudo_step_name2) {
        yyerror("illegal causal link (cannot link step " + *pseudo_step_name1 
            + " to itself in decomposition " + decomposition->name() + ")");
    }

    // Check that the Literal exists as an effect of the first pseudo-step
    // If so, store the effect for the causal link
    const Effect* effect_match = 0;

    for (EffectList::const_iterator ei = pseudo_steps.first->action().effects().begin();
        ei != pseudo_steps.first->action().effects().end();
        ++ei)
    {
        const Literal* el = &(*ei)->literal();

        // To be a match, it first has to match the predicate type and the arity...
        if (Literal::syntactically_equal(literal, *el)) {
            effect_match = (*ei);
        }
    }

    if (effect_match == 0) 
    {
        yyerror("literal " + domain->predicates().name(literal.predicate()) +
            " not found as effect of pseudo-step" + pseudo_steps.first->action().name());
    }
    
    // Check that the Literal exists as a precondition of the second pseudo-step
    // If so, store the literal as an open precondition for the causal link
    const OpenCondition* op_match = 0;

    const Formula& pseudo_step_condition = pseudo_steps.second->action().condition();

    if (typeid(pseudo_step_condition) == typeid(Atom) || typeid(pseudo_step_condition) == typeid(Negation))
    {
        const Literal* cond = dynamic_cast<const Literal*>(&pseudo_step_condition);
        if (Literal::syntactically_equal(literal, *cond)) {
            op_match = new OpenCondition(pseudo_steps.second->id(), *cond);
        }        
    }

    else if (typeid(pseudo_step_condition) == typeid(Conjunction))
    {
        // for each conjunct, check if it's an Atom or Negation; skip any other types
        const Conjunction& conj = dynamic_cast<const Conjunction&>(pseudo_step_condition);
        for (FormulaList::const_iterator fi = conj.conjuncts().begin();
            fi != conj.conjuncts().end();
            ++fi)
        {
            if (typeid(**fi) == typeid(Atom) || typeid(**fi) == typeid(Negation))
            {
                const Literal* cond = dynamic_cast<const Literal*>(*fi);
                if (Literal::syntactically_equal(literal, *cond)) {
                    op_match = new OpenCondition(pseudo_steps.second->id(), *cond);
                }
            }

            else  {
                // skip this literal, and see if we can find another one in the conjunction to link to.
                continue; 
            }
        }
    }

    else
    {
        yyerror("unable to create causal link to precondition within " + pseudo_steps.second->action().name()
            + "; linked pseudo-step preconditions are limited to literals");
    }

    if (op_match == 0)
    {
        yyerror("literal " + domain->predicates().name(literal.predicate()) +
            " not found as a precondition of pseudo-step" + pseudo_steps.second->action().name());
    }

    const Link* link = new Link(pseudo_steps.first->id(), StepTime::AT_END, *op_match);


    // For each of the literal's terms, corresponding Bindings must be added to the decomposition.
    for (size_t i = 0; i < literal.arity(); ++i)
    {
		Term t = literal.term(i);

        // Add a term binding between the terms of:
        // the effect of the first pseudo-step and
        // the precondition of the second pseudo-step
        Term effect_term = effect_match->literal().term(i);        
        Term precondition_term = op_match->literal()->term(i);

        Binding* new_binding = bind_terms(effect_term, pseudo_steps.first->id(), precondition_term, pseudo_steps.second->id());

        if (new_binding == 0) {
            yyerror("cannot create needed binding for causal link due to incompatibility of terms");
        }

        else {
            decomposition->add_binding(*new_binding);
        }
    }

    return link;
}

/* Adds a link to the current decomposition. */
static void add_link(const Link& link)
{
    decomposition->add_link(link);
}


/* Prepares for the parsing of a universally quantified effect. */ 
static void prepare_forall_effect() {
  if (!requirements->conditional_effects) {
    yywarning("assuming `:conditional-effects' requirement");
    requirements->conditional_effects = true;
  }
  context.push_frame();
  quantified.push_back(Term(0));
}


/* Prepares for the parsing of a conditional effect. */ 
static void prepare_conditional_effect(const Formula& condition) {
  if (!requirements->conditional_effects) {
    yywarning("assuming `:conditional-effects' requirement");
    requirements->conditional_effects = true;
  }
  effect_condition = &condition;
}


/* Adds types, constants, or objects to the current domain or problem. */
static void add_names(const std::vector<const std::string*>* names,
              const Type& type) {
  for (std::vector<const std::string*>::const_iterator si = names->begin();
       si != names->end(); si++) {
    const std::string* s = *si;
    if (name_kind == TYPE_KIND) {
      if (*s == TypeTable::OBJECT_NAME) {
    yywarning("ignoring declaration of reserved type `object'");
      } else if (*s == TypeTable::NUMBER_NAME) {
    yywarning("ignoring declaration of reserved type `number'");
      } else {
    const Type* t = domain->types().find_type(*s);
    if (t == 0) {
      t = &domain->types().add_type(*s);
    }
    if (!TypeTable::add_supertype(*t, type)) {
      yyerror("cyclic type hierarchy");
    }
      }
    } else if (name_kind == CONSTANT_KIND) {
      const Object* o = domain->terms().find_object(*s);
      if (o == 0) {
    domain->terms().add_object(*s, type);
      } else {
    TypeSet components;
    TypeTable::components(components, TermTable::type(*o));
    components.insert(type);
    TermTable::set_type(*o, make_type(components));
      }
    } else { /* name_kind == OBJECT_KIND */
      if (domain->terms().find_object(*s) != 0) {
    yywarning("ignoring declaration of object `" + *s
          + "' previously declared as constant");
      } else {
    const Object* o = problem->terms().find_object(*s);
    if (o == 0) {
      problem->terms().add_object(*s, type);
    } else {
      TypeSet components;
      TypeTable::components(components, TermTable::type(*o));
      components.insert(type);
      TermTable::set_type(*o, make_type(components));
    }
      }
    }
    delete s;
  }
  delete names;
}


/* Adds variables to the current variable list. */
static void add_variables(const std::vector<const std::string*>* names, const Type& type) 
{
  for (std::vector<const std::string*>::const_iterator si = names->begin();
       si != names->end(); 
       si++) 
  {
    const std::string* s = *si;
    
    if (predicate != 0) 
    {
      if (!repeated_predicate) {
        PredicateTable::add_parameter(*predicate, type);
      }
    } 
    
    else if (function != 0) 
    {
      if (!repeated_function) {
        FunctionTable::add_parameter(*function, type);
      }
    } 
    
    else 
    {
      if (context.shallow_find(*s) != 0) {
        yyerror("repetition of parameter `" + *s + "'");
      } 
      
      else if (context.find(*s) != 0) {
        yywarning("shadowing parameter `" + *s + "'");
      }

      Variable var = TermTable::add_variable(type);
      context.insert(*s, var);
      
      if (!quantified.empty()) {
        quantified.push_back(var);
      } 
      
      else { 

        if(action != 0) {
          action->add_parameter(var);
        }

        else { /* decomposition != 0 */
          decomposition->add_parameter(var);
        }

      }
    }

    delete s;
  }
  delete names;
}


/* Prepares for the parsing of an atomic formula. */ 
static void prepare_atom(const std::string* name) {
  atom_predicate = domain->predicates().find_predicate(*name);
  if (atom_predicate == 0) {
    atom_predicate = &domain->predicates().add_predicate(*name);
    undeclared_atom_predicate = true;
    if (problem != 0) {
      yywarning("undeclared predicate `" + *name + "' used");
    } else {
      yywarning("implicit declaration of predicate `" + *name + "'");
    }
  } else {
    undeclared_atom_predicate = false;
  }
  term_parameters.clear();
  delete name;
}


/* Prepares for the parsing of a fluent. */ 
static void prepare_fluent(const std::string* name) {
  fluent_function = domain->functions().find_function(*name);
  if (fluent_function == 0) {
    fluent_function = &domain->functions().add_function(*name);
    undeclared_fluent_function = true;
    if (problem != 0) {
      yywarning("undeclared function `" + *name + "' used");
    } else {
      yywarning("implicit declaration of function `" + *name + "'");
    }
  } else {
    undeclared_fluent_function = false;
  }
  if (*name == "total-time") {
    if (!metric_fluent) {
      yyerror("reserved function `" + *name + "' not allowed here");
    }
  } else {
    require_fluents();
  }
  term_parameters.clear();
  delete name;
}


/* Adds a term with the given name to the current atomic formula. */
static void add_term(const std::string* name) {
  Term term = make_term(name);
  if (atom_predicate != 0) {
    size_t n = term_parameters.size();
    if (undeclared_atom_predicate) {
      PredicateTable::add_parameter(*atom_predicate, TermTable::type(term));
    } else {
      const TypeList& params = PredicateTable::parameters(*atom_predicate);
      if (params.size() > n
      && !TypeTable::subtype(TermTable::type(term), params[n])) {
    yyerror("type mismatch");
      }
    }
  } else if (fluent_function != 0) {
    size_t n = term_parameters.size();
    if (undeclared_fluent_function) {
      FunctionTable::add_parameter(*fluent_function, TermTable::type(term));
    } else {
      const TypeList& params = FunctionTable::parameters(*fluent_function);
      if (params.size() > n
      && !TypeTable::subtype(TermTable::type(term), params[n])) {
    yyerror("type mismatch");
      }
    }
  }
  term_parameters.push_back(term);
}


/* Creates the atomic formula just parsed. */
static const Atom* make_atom() {
  size_t n = term_parameters.size();
  if (PredicateTable::parameters(*atom_predicate).size() < n) {
    yyerror("too many parameters passed to predicate `"
        + PredicateTable::name(*atom_predicate) + "'");
  } else if (PredicateTable::parameters(*atom_predicate).size() > n) {
    yyerror("too few parameters passed to predicate `"
        + PredicateTable::name(*atom_predicate) + "'");
  }
  const Atom& atom = Atom::make(*atom_predicate, term_parameters);
  atom_predicate = 0;
  return &atom;
}


/* Creates the fluent just parsed. */
static const Fluent* make_fluent() {
  size_t n = term_parameters.size();
  if (FunctionTable::parameters(*fluent_function).size() < n) {
    yyerror("too many parameters passed to function `"
        + FunctionTable::name(*fluent_function) + "'");
  } else if (FunctionTable::parameters(*fluent_function).size() > n) {
    yyerror("too few parameters passed to function `"
        + FunctionTable::name(*fluent_function) + "'");
  }
  const Fluent& fluent = Fluent::make(*fluent_function, term_parameters);
  fluent_function = 0;
  return &fluent;
}


/* Creates a subtraction. */
static const Expression* make_subtraction(const Expression& term,
                      const Expression* opt_term) {
  if (opt_term != 0) {
    return &Subtraction::make(term, *opt_term);
  } else {
    return &Subtraction::make(*new Value(0), term);
  }
}


/* Creates an equality formula. */
static const Formula* make_equality(const Term* term1, const Term* term2) {
  if (!requirements->equality) {
    yywarning("assuming `:equality' requirement");
    requirements->equality = true;
  }
  const Formula& eq = Equality::make(*term1, *term2);
  delete term1;
  delete term2;
  return &eq;
}


/* Creates a negated formula. */
static const Formula* make_negation(const Formula& negand) {
  if (typeid(negand) == typeid(Literal)
      || typeid(negand) == typeid(TimedLiteral)) {
    if (!requirements->negative_preconditions) {
      yywarning("assuming `:negative-preconditions' requirement");
      requirements->negative_preconditions = true;
    }
  } else if (!requirements->disjunctive_preconditions
         && typeid(negand) != typeid(Equality)) {
    yywarning("assuming `:disjunctive-preconditions' requirement");
    requirements->disjunctive_preconditions = true;
  }
  return &!negand;
}


/* Prepares for the parsing of an existentially quantified formula. */
static void prepare_exists() {
  if (!requirements->existential_preconditions) {
    yywarning("assuming `:existential-preconditions' requirement");
    requirements->existential_preconditions = true;
  }
  context.push_frame();
  quantified.push_back(Term(0));
}


/* Prepares for the parsing of a universally quantified formula. */
static void prepare_forall() {
  if (!requirements->universal_preconditions) {
    yywarning("assuming `:universal-preconditions' requirement");
    requirements->universal_preconditions = true;
  }
  context.push_frame();
  quantified.push_back(Term(0));
}


/* Creates an existentially quantified formula. */
static const Formula* make_exists(const Formula& body) {
  context.pop_frame();
  size_t m = quantified.size() - 1;
  size_t n = m;
  while (quantified[n].variable()) {
    n--;
  }
  if (n < m) {
    if (body.tautology() || body.contradiction()) {
      quantified.resize(n, Term(0));
      return &body;
    } else {
      Exists& exists = *new Exists();
      for (size_t i = n + 1; i <= m; i++) {
    exists.add_parameter(quantified[i].as_variable());
      }
      exists.set_body(body);
      quantified.resize(n, Term(0));
      return &exists;
    }
  } else {
    quantified.pop_back();
    return &body;
  }
}


/* Creates a universally quantified formula. */
static const Formula* make_forall(const Formula& body) {
  context.pop_frame();
  size_t m = quantified.size() - 1;
  size_t n = m;
  while (quantified[n].variable()) {
    n--;
  }
  if (n < m) {
    if (body.tautology() || body.contradiction()) {
      quantified.resize(n, Term(0));
      return &body;
    } else {
      Forall& forall = *new Forall();
      for (size_t i = n + 1; i <= m; i++) {
    forall.add_parameter(quantified[i].as_variable());
      }
      forall.set_body(body);
      quantified.resize(n, Term(0));
      return &forall;
    }
  } else {
    quantified.pop_back();
    return &body;
  }
}


/* Adds the current effect to the currect action. */
static void add_effect(const Literal& literal) 
{
    PredicateTable::make_dynamic(literal.predicate());
    Effect* effect = new Effect(literal, effect_time);
    
    for (TermList::const_iterator vi = quantified.begin(); vi != quantified.end(); vi++) 
    {
        if ((*vi).variable()) {
            effect->add_parameter((*vi).as_variable());
        }
    }

    if (effect_condition != 0) {
        effect->set_condition(*effect_condition);
    }

    action->add_effect(*effect);
}


/* Pops the top-most universally quantified variables. */
static void pop_forall_effect() {
  context.pop_frame();
  size_t n = quantified.size() - 1;
  while (quantified[n].variable()) {
    n--;
  }
  quantified.resize(n, Term(0));
}


/* Adds a timed initial literal to the current problem. */
static void add_init_literal(float time, const Literal& literal) {
  problem->add_init_literal(time, literal);
  if (time > 0.0f) {
    PredicateTable::make_dynamic(literal.predicate());
  }
}
