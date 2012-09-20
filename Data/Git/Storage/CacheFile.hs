{-# LANGUAGE ScopedTypeVariables #-}
-- |
-- Module      : Data.Git.Storage.CacheFile
-- License     : BSD-style
-- Maintainer  : Vincent Hanquez <vincent@snarc.org>
-- Stability   : experimental
-- Portability : unix
--
module Data.Git.Storage.CacheFile (CacheFile, newCacheVal, getCacheVal) where

import Control.Applicative ((<$>))
import Control.Concurrent.MVar
import qualified Control.Exception as E
import Data.Time.Clock
import Filesystem
import Filesystem.Path
import Prelude hiding (FilePath)

data CacheFile a = CacheFile
    { cacheFilepath :: FilePath
    , cacheRefresh  :: IO a
    , cacheIniVal   :: a
    , cacheLock     :: MVar (MTime, a)
    }

utcZero = UTCTime (toEnum 0) 0

newCacheVal :: FilePath -> IO a -> a -> IO (CacheFile a)
newCacheVal path refresh initialVal =
    CacheFile path refresh initialVal <$> newMVar (MTime utcZero, initialVal)

getCacheVal :: CacheFile a -> IO a
getCacheVal cachefile = modifyMVar (cacheLock cachefile) getOrRefresh
    where getOrRefresh s@(mtime, cachedVal) = do
             cMTime <- getMTime $ cacheFilepath cachefile
             case cMTime of
                  Nothing -> return ((MTime utcZero, cacheIniVal cachefile), cacheIniVal cachefile)
                  Just newMtime | newMtime > mtime -> cacheRefresh cachefile >>= \v -> return ((newMtime, v), v)
                                | otherwise        -> return (s, cachedVal)

newtype MTime = MTime UTCTime deriving (Eq,Ord)

getMTime filepath = (Just . MTime <$> getModified filepath)
            `E.catch` \(_ :: E.SomeException) -> return Nothing