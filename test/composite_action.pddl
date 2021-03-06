; The 4-operator blocks world domain from the 2nd International
; Planning Competition.

(define (domain composite_action)
  (:predicates (on ?x ?y) (ontable ?x) (clear ?x) (handempty) (holding ?x))
  (:action pick-up
	   :parameters (?x)
	   :precondition (and (clear ?x) (ontable ?x) (handempty))
	   :effect (and (not (ontable ?x)) (not (clear ?x)) (not (handempty)) (holding ?x))
	   :composite t)

  (:action put-down
           :parameters (?x)
           :precondition (holding ?x)
           :effect (and (not (holding ?x)) (clear ?x) (handempty)
			(ontable ?x))
		:composite			t	
			)

  (:action stack
           :parameters (?x ?y)
           :precondition (and (holding ?x) (clear ?y))
           :effect (and (not (holding ?x)) (not (clear ?y)) (clear ?x)
                        (handempty) (on ?x ?y)))
)
