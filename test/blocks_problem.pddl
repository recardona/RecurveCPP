(define (problem blocks-3)
  (:domain blocks)
  (:objects b1 b2 b3)
  (:init (clear b1) (ontable b1)
         (clear b2) (ontable b2)
         (clear b3) (ontable b3)
         (handempty))
  (:goal (and (on b2 b1)
              (on b3 b2)))
)
