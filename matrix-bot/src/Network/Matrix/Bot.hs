{-# LANGUAGE GADTs #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}
module Network.Matrix.Bot ( MatrixBotOptions(..)
                          , matrixBot
                          ) where

import Control.Monad (forever)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.IO.Unlift (MonadUnliftIO)
import Network.Matrix.Client
import Network.Matrix.Bot.ErrorHandling
import Network.Matrix.Bot.Router
import Network.Matrix.Bot.State
import Network.Matrix.Bot.Sync

data MatrixBotOptions m where
  MatrixBotOptions
    :: (MatrixBotBase n, MonadUnliftIO n, MonadResyncableMatrixBot n)
    => { runBotT :: forall a. n a -> m a
       , botRouter :: RunnableBotEventRouter n
       } -> MatrixBotOptions m

matrixBot :: ClientSession
          -> (forall m. (MatrixBotBase m, MonadUnliftIO m, MonadResyncableMatrixBot m) => MatrixBotOptions m)
          -> IO ()
matrixBot session MatrixBotOptions{..} = do
  userID <- retry (getTokenOwner session) >>= dieOnLeft "Could not determine own MXID"
  initialSyncToken <- retry (getInitialSyncToken session userID)
    >>= dieOnLeft "Could not retrieve saved sync token"
  liftIO $ print initialSyncToken
  runMatrixBot session userID initialSyncToken $ runBotT $
    forever $ syncLoop botRouter >>= logOnLeft "Error while syncing"
