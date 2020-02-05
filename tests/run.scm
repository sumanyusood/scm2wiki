(import scheme (chicken base) (chicken string)
	srfi-1 srfi-13 comparse test
	scm-semantics-impl semantics2md-impl)

(test-group
 "Semantic Source Parsing"

 (test-group
  "Parsing S-expressions"

  (test "atoms" '("foo/bar" "|bar baz|" "\"quoted string\"" "#\\("
		  #f #f #f)
	(map (lambda (s)
	       (parse (followed-by (as-string an-atom)
				   end-of-input)
		      s))
	     '("foo/bar" "|bar baz|" "\"quoted string\"" "#\\("
	       "not-end-of-input " "(a-cons)" "not(an-atom")))

  (test "cons-cells" '("()" "(foo)" "(foo (bar (baz)))"
		       "'(foo)" "`(foo ,(bar))" "(foo \n  bar  )"
		       #f #f #f)
	(map (lambda (s)
	       (parse (followed-by (as-string a-cons)
				   end-of-input)
		      s))
	     '("()" "(foo)" "(foo (bar (baz)))"
	       "'(foo)" "`(foo ,(bar))" "(foo \n  bar  )"
	       "not-a-cons" "(not (a cons)" "(not end of input  ) "))))

 (test-group
  "Parsing Comments"

  (test "parsing comment blocks"
	"a comment line\nanother line\n\n  an indented comment"
	(parse (a-comment ";;;")
	       (string-append ";;; a comment line\n  ;;; another line\n;;;\n"
			      ";;;   an indented comment\n"))))

 (test-group
  "Parsing & Destructuring Definitions"

  (test "parsing generic definitions" '(#t #t #f #f #f)
	(map (lambda (s)
	       (let ((res (parse (followed-by
				  (a-generic-definition ";;;" 'define
							'variable-definition)
				  end-of-input)
				 s)))
		 (if res #t #f)))
	     '("(define foo 1)" ";;; bla\n (define foo 1) \n"
	       "(define (foo x) #t)" "(foo bar baz)"
	       "(define foo (+ 1 1)")))

  (test "destructuring variable definitions"
	'(variable-definition "foo" "(+ 1 1)" "bla")
	(let ((res (parse (a-variable-definition ";;;")
			  ";;; bla\n(define foo (+ 1 1))")))
	  (list (car res)
		(car (alist-ref 'name (cdr res)))
		(car (alist-ref 'value (cdr res)))
		(car (alist-ref 'comment (cdr res))))))

  (test "destructuring procedure definitions"
	'(procedure-definition "foo" "A procedure" "(foo x y)" "(+ x y)")
	(let ((res (parse (a-procedure-definition ";;;")
			  ";;; A procedure\n (define (foo x y) (+ x y))\n")))
	  (list (car res)
		(car (alist-ref 'name (cdr res)))
		(car (alist-ref 'comment (cdr res)))
		(car (alist-ref 'signature (cdr res)))
		(car (alist-ref 'body (cdr res))))))

  (test "destructuring macro definitions"
	'(syntax-definition "foo" "A macro" "(syntax-rules ()\n...)")
	(let ((res (parse (a-syntax-definition ";;;")
			  (string-append ";;; A macro\n (define-syntax foo\n"
					 "  (syntax-rules ()\n...))\n"))))
	  (list (car res)
		(car (alist-ref 'name (cdr res)))
		(car (alist-ref 'comment (cdr res)))
		(car (alist-ref 'body (cdr res))))))

  (test "destructuring record fields"
	'((field (name "foo"))
	  (field (name "foo")
		 (default "1"))
	  (field (name "foo")
		 (type "fixnum"))
	  (field (name "foo")
		 (default "1")
		 (type "fixnum"))
	  #f)
	(map (lambda (s)
	       (parse (a-record-field ";;;")
		      s))
	     '("foo" "(foo 1)" "(foo : fixnum)" "((foo 1) : fixnum)"
	       "(not a record field)")))

  (test "generate getters/setters"
	'((field (name "bar")
		 (default "1")
		 (type "fixnum")
		 (getter "foo-bar")
		 (setter "foo-bar-set!")))
	(generate-getters+setters (list (parse (a-record-field ";;;")
					       "((bar 1) : fixnum)"))
				  "foo"))

  (test "generate defstruct constructor"
	'(constructor "(make-foo x: x1 y: y1)")
	(generate-defstruct-constructor
	 (list (parse (a-record-field ";;;")
		      "((x 1) : fixnum)")
	       (parse (a-record-field ";;;")
		      "y"))
	 "foo"))

  (test "destructuring defstruct record definition"
	'(record-definition "A defstruct" "defstruct" "(make-foo x: x1 y: y1)"
			    "(foo? x)" "x" "foo-x" "foo-x-set!"
			    "y" "foo-y" "foo-y-set!" "1" "fixnum")
	(let* ((res (parse (a-defstruct ";;;")
			   (string-append
			    ";;; A defstruct\n "
			    "(defstruct foo\n x ((y 1) : fixnum))\n")))
	       (fields (alist-ref 'fields (cdr res))))
	  (list (car res)
		(car (alist-ref 'comment (cdr res)))
		(car (alist-ref 'implementation (cdr res)))
		(car (alist-ref 'constructor (cdr res)))
		(car (alist-ref 'predicate (cdr res)))
		(car (alist-ref 'name (cdar fields)))
		(car (alist-ref 'getter (cdar fields)))
		(car (alist-ref 'setter (cdar fields)))
		(car (alist-ref 'name (cdadr fields)))
		(car (alist-ref 'getter (cdadr fields)))
		(car (alist-ref 'setter (cdadr fields)))
		(car (alist-ref 'default (cdadr fields)))
		(car (alist-ref 'type (cdadr fields))))))

  (test "destructuring define-record definition"
	'(record-definition "A define-record" "define-record" "(make-foo x y)"
			    "(foo? x)" "x" "foo-x" "foo-x-set!"
			    "y" "foo-y" "foo-y-set!" "fixnum")
	(let* ((res (parse (a-define-record ";;;")
			   (string-append
			    ";;; A define-record\n "
			    "(define-record foo x (y : fixnum))\n")))
	       (fields (alist-ref 'fields (cdr res))))
	  (list (car res)
		(car (alist-ref 'comment (cdr res)))
		(car (alist-ref 'implementation (cdr res)))
		(car (alist-ref 'constructor (cdr res)))
		(car (alist-ref 'predicate (cdr res)))
		(car (alist-ref 'name (cdar fields)))
		(car (alist-ref 'getter (cdar fields)))
		(car (alist-ref 'setter (cdar fields)))
		(car (alist-ref 'name (cdadr fields)))
		(car (alist-ref 'getter (cdadr fields)))
		(car (alist-ref 'setter (cdadr fields)))
		(car (alist-ref 'type (cdadr fields))))))

  (test "destructuring srfi-9 record fields"
	'((field (name "x")
		 (getter "foo-x"))
	  (field (name "y")
		 (getter "foo-y")
		 (setter "foo-y-set!"))
	  (field (name "z")
		 (getter "foo-z")
		 (setter "foo-z-set!")
		 (type "fixnum")
		 (comment "a field")))
	(map (lambda (s)
	       (parse (a-srfi-9-field ";;;")
		      s))
	     '("(x foo-x)" "(y foo-y foo-y-set!)"
	       "(z foo-z foo-z-set! : fixnum) ;;; a field\n")))

  (test "destructuring srfi-9 record definition"
	'(record-definition (name "foo") (implementation "srfi-9")
			    (constructor "(make-foo x y)")
			    (predicate "foo?")
			    (fields (field (name "x") (getter "foo-x"))
				    (field (name "y") (getter "foo-y")
					   (setter "foo-y-set!")
					   (type "fixnum")
					   (comment "a field comment")))
			    (comment "A SRFI-9 record"))
	(parse (a-define-record-type ";;;")
	       (string-append ";;; A SRFI-9 record\n (define-record-type foo\n"
			      "   (make-foo x y)\n   foo?\n"
			      "   (x foo-x)\n" "(y foo-y foo-y-set! : fixnum)"
			      "   ;;; a field comment\n)"))))

 (test-group
  "Parsing Modules"

  (test "Destructuring Module Declarations"
	'(module-declaration (name "foo")
			     (comment "A module description")
			     (exported-symbols "bar")
			     (body (comment "A stand-alone comment")
				   (variable-definition
				    (name "bar")
				    (type-annotation (identifier "bar")
						     (type "fixnum"))
				    (value "1")
				    (comment "A variable definition"))))
	(parse (a-module-declaration ";;;")
	       (string-append ";;; A module description\n"
			      " (module foo\n  *\n\n"
			      "   (import scheme (chicken base))\n\n"
			      "   ;;; A stand-alone comment\n\n"
			      "   ;;; A variable definition\n"
			      "   (: bar fixnum)\n"
			      "   (define bar 1)"
			      "  ) ;; closing comment")))
  ))

(test-group
 "Markdown Generation"

 (test "generic definitions"
       (string-append "### [VARIABLE] foo\n"
		      "```Scheme\nfoo  ; type: fixnum, default: 1\n"
		      "```\nA variable definition")
       (transform-generic-definition
	'(variable-definition (name "foo")
			      (value "1")
			      (type-annotation (identifier "foo")
					       (type "fixnum"))
			      (comment "A variable definition"))))

 (test "procedure definitions"
       (string-append "### [PROCEDURE] foo\n"
		      "```Scheme\n(foo x !#optional y)"
		      "  ; type: (fixnum #!optional bool) -> . bool"
		      "\n```\nA procedure definition")
       (transform-procedure-definition
	'(procedure-definition
	  (name "foo")
	  (comment "A procedure definition")
	  (signature "(foo x !#optional y)")
	  (type-annotation (identifier "foo")
			   (type "(fixnum #!optional bool) -> . bool")))))

 (test "table generation"
       (string-append
	"name | getter | setter     | type   | comment        \n"
	"---- | ------ | ---------- | ------ | ---------------\n"
	"x    | foo-x  | foo-x-set! |        | A comment      \n"
	"y    | foo-y  |            | fixnum | Another comment")
       (make-md-table '(name getter setter type comment)
		      '(("x" "foo-x" "foo-x-set!" "" "A comment")
			("y" "foo-y" "" "fixnum" "Another comment"))))

 (test "record definitions"
       (string-append "### [RECORD] foo\n"
		      "**[CONSTRUCTOR]**\n"
		      "```Scheme\n(make-foo x y)\n```\n"
		      "**[PREDICATE]**\n"
		      "```Scheme\n(foo? x)\n```\n"
		      "**[IMPLEMENTATION]** `defstruct`\n"
		      "**[FIELDS]**\n"
		      "name | getter | setter     | default | comment        \n"
		      "---- | ------ | ---------- | ------- | ---------------\n"
		      "x    | foo-x  | foo-x-set! |         |                \n"
		      "y    | foo-y  |            | 1       | A field comment\n"
		      "A record definition")
       (transform-record-definition
	'(record-definition (name "foo")
			    (implementation "defstruct")
			    (comment "A record definition")
			    (constructor "(make-foo x y)")
			    (predicate "(foo? x)")
			    (fields (field (name "x")
					   (getter "foo-x")
					   (setter "foo-x-set!"))
				    (field (name "y")
					   (default "1")
					   (getter "foo-y")
					   (comment "A field comment"))))))
 (test "syntax definitions"
       "### [SYNTAX] foo\nA comment"
       (transform-syntax-definition
	'(syntax-definition (name "foo") (comment "A comment"))))

 (test "module declarations"
       (string-append "## MODULE foo\n"
		      "A module description\n"
		      "A stand-alone comment\n\n"
		      "### [VARIABLE] bar\n"
		      "```Scheme\nbar  ; type: fixnum, default: 1\n```\n"
		      "A variable definition\n\n"
		      "### [PROCEDURE] baz\n"
		      "```Scheme\n(baz x y)"
		      "\n```\nA procedure definition")
       (transform-module-declaration
	'(module-declaration (name "foo")
			     (comment "A module description")
			     (exported-symbols "bar")
			     (body (comment "A stand-alone comment")
				   (variable-definition
				    (name "bar")
				    (type-annotation (identifier "bar")
						     (type "fixnum"))
				    (value "1")
				    (comment "A variable definition"))
				   (procedure-definition
				    (name "baz")
				    (signature "(baz x y)")
				    (comment "A procedure definition"))))
	#f)))

(test-exit)
