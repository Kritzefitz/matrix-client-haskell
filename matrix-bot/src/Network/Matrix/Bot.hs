module Network.Matrix.Bot ( MatrixBot(..)
                          , runMatrixBot
                          ) where

import Control.Monad (forever)
import Control.Monad.IO.Class (liftIO)
import Network.Matrix.Client

import Network.Matrix.Bot.Async
import Network.Matrix.Bot.ErrorHandling
import Network.Matrix.Bot.Router
import Network.Matrix.Bot.State
import Network.Matrix.Bot.Sync

data MatrixBot = forall r. MatrixBot
     { initializeBotEnv :: forall m. (MonadMatrixBotBase m) => m r
     , botRouter :: forall m. (MonadMatrixBotBase m, MonadResyncableMatrixBot m, MonadSyncGroupManager m)
                 => r -> BotEventRouter m
     }

runMatrixBot :: ClientSession
          -> MatrixBot
          -> IO ()
runMatrixBot session MatrixBot{..} = do
  userID <- retry (getTokenOwner session) >>= dieOnLeft "Could not determine own MXID"
  initialSyncToken <- retry (getInitialSyncToken session userID)
    >>= dieOnLeft "Could not retrieve saved sync token"
  liftIO $ print initialSyncToken
  runMatrixBotT session userID initialSyncToken $ do
    r <- initializeBotEnv
    forever $ syncLoop (botRouter r) >>= logOnLeft "Error while syncing"
