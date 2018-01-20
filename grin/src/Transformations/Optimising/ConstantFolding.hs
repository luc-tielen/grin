{-# LANGUAGE LambdaCase, TupleSections, TypeApplications, RecordWildCards, DeriveFunctor, OverloadedStrings #-}
module Transformations.Optimising.ConstantFolding where

import Check
import Grin
import Free
import Test
import Test.Hspec
import Test.QuickCheck
--import Transformations
import Transformations.Substitution
import Data.Functor.Foldable

import qualified Data.Map.Strict as Map

{-
Constant folding is not part of the official grin optimization pipeline.
This transformation is used for demonstrate and experiment with the
testing.
-}

constantFolding :: Exp -> Exp
constantFolding = ana builder where
  builder :: Exp -> ExpF Exp
  builder = \case
    EBind (SReturn v) (Var n) rest | isConstant v ->
      project $ substitution (Map.singleton n v) rest

    rest ->
      project rest

tests :: Spec
tests = do
  describe "constant folding" $ do
    it "inside bind" $ do
      x <- buildExpM $
        "x"  <=: store @Var "a"    $
        "y"  <=: store @Var "b"    $
        "u"  <=: unit  @Int 5      $
        Unit <=: store @Var "u"    $
        unit @Var "u"

      e <- buildExpM $
        "x"  <=: store @Var "a" $
        "y"  <=: store @Var "b" $
        Unit <=: store @Int 5   $
        unit @Int 5
      constantFolding x `shouldBe` e

    it "last bind" $ do
      x <- buildExpM $
        "x" <=: store @Var "a" $
        "y" <=: store @Var "b" $
        "u" <=: unit  @Int 5   $
        unit @Var "u"
      e <- buildExpM $
        "x" <=: store @Var "a" $
        "y" <=: store @Var "b" $
        unit @Int 5
      constantFolding x `shouldBe` e

    it "unused variable" $ do
      x <- buildExpM $
        "x" <=: store @Int 3 $
        "u" <=: unit  @Int 4 $
        unit @Int 5
      e <- buildExpM $
        "x" <=: store @Int 3 $
        unit @Int 5
      constantFolding x `shouldBe` e

    it "only one statement" $ do
      x <- buildExpM $
        def "fun" ["a", "b"] $
          "x" <=: unit @Int 3 $
          unit @Var "x"
      e <- buildExpM $
        def "fun" ["a", "b"] $
          unit @Int 3
      constantFolding x `shouldBe` e

    it "the program size shrinks" $ property $ forAll nonWellFormedPrograms $ \original ->
      let transformed = constantFolding original
      in conjoin
          [ transformed `smallerThan` original
          , checkUniqueNames transformed
          ]

-- Check if the number of nodes in a program is less rhan or equals after the transformation.
smallerThan :: Exp -> Exp -> Property
smallerThan transformed original  =
  let sizeReduced  = programSize transformed
      sizeOriginal = programSize original
  in
    cover (sizeReduced == sizeOriginal) 0 "Non Reduced" $
    cover (sizeReduced <  sizeOriginal) 1 "Reduced"     $
    (sizeReduced <= sizeOriginal)

checkUniqueNames :: Exp -> Property
checkUniqueNames = label "Unique name" . null . nonUniqueNames

cfRunTests :: IO ()
cfRunTests = hspec Transformations.Optimising.ConstantFolding.tests