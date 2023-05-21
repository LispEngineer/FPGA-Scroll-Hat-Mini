(ns font-transpose.core
  "Tools to transpose a font from ASCII bytes to ASCII bytes in 8x8.
   Copyright 2023 Douglas P. Fields, Jr. symbolics@lisp.engineer
   See LICENSE file for licensing information.
   See README.md for more information."
  (:require [clojure.set :as set]
            [clojure.string :as str]))


(def input
  "Raw text input file split into lines"
  (map str/trim (str/split-lines (slurp "font.raw"))))

(defn to-binary-string
  [hex]
  (let [bin (.toString (BigInteger. hex 16) 2)
        len (count bin)]
    (seq
      (if (< len 8)
        (str (apply str (repeat (- 8 len) \0)) bin)
        bin))))

(defn bin-to-hex
  [bin]
  (let [hex (.toString (BigInteger. bin 2) 16)
        len (count hex)]
    (if (< len 2)
      (str (apply str (repeat (- 2 len) \0)) hex)
      hex)))


(def input-binary-partitioned
  (partition 8 (map to-binary-string input)))

;; Now we have:
;; (
;;  ( ( 1 2 3 4 5 6 7 8 )
;;    ( 1 2 3 4 5 6 7 8 )
;;    ( 1 2 3 4 5 6 7 8 )
;;    ( 1 2 3 4 5 6 7 8 )
;;    ( 1 2 3 4 5 6 7 8 )
;;    ( 1 2 3 4 5 6 7 8 )
;;    ( 1 2 3 4 5 6 7 8 )
;;    ( 1 2 3 4 5 6 7 8 ) )
;;  ...
;; )
;;
;; And we want to transpose each entry which is a matrix

(defn transpose
  [m] ;; Nested Sequence i.e. matrix
  (apply mapv vector m))

(def input-transposed
  (map transpose input-binary-partitioned))

(defn matrix-to-strings
  [m]
  (map #(apply str %) m))

(def input-transposed-hex
  (let [;; Back to strings
        m-s (map matrix-to-strings input-transposed)
        ;; Single sequence of strings
        msc (apply concat m-s)
        ;; Back to hex
        hex (map bin-to-hex msc)]
    hex))

;; And write our output
(spit "font-transposed.raw"
      (apply str (interpose \newline input-transposed-hex)))