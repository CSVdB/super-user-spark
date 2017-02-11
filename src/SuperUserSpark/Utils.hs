{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module SuperUserSpark.Utils where

import Import

import Data.List (isInfixOf)
import qualified System.Directory as D (createDirectoryIfMissing)

incase
    :: MonadReader c m
    => (c -> Bool) -> m () -> m ()
incase bf func = do
    b <- asks bf
    when b func

incaseElse
    :: MonadReader c m
    => (c -> Bool) -> m a -> m a -> m a
incaseElse bf funcif funcelse = do
    b <- asks bf
    if b
        then funcif
        else funcelse

containsNewline :: String -> Bool
containsNewline f = any (\c -> elem c f) ['\n', '\r']

containsMultipleConsequtiveSlashes :: String -> Bool
containsMultipleConsequtiveSlashes = isInfixOf "//"

(&&&) :: (a -> Bool) -> (a -> Bool) -> a -> Bool
(&&&) f g = \a -> f a && g a

(|||) :: (a -> Bool) -> (a -> Bool) -> a -> Bool
(|||) f g = \a -> f a || g a

createDirectoryIfMissing :: FilePath -> IO ()
createDirectoryIfMissing = D.createDirectoryIfMissing True