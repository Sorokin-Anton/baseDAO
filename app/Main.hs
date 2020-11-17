-- SPDX-FileCopyrightText: 2020 TQ Tezos
-- SPDX-License-Identifier: LicenseRef-MIT-TQ

{-# LANGUAGE ApplicativeDo #-}
module Main
  ( main
  ) where

import Universum

import qualified Data.Map as Map
import Data.Version (showVersion)
import Lorentz (DGitRevision, GitRepoSettings(..), mkDGitRevision)
import Lorentz.ContractRegistry
import Main.Utf8 (withUtf8)
import Morley.CLI (addressOption)
import qualified Options.Applicative as Opt
import Options.Applicative.Help.Pretty (Doc, linebreak)
import Paths_baseDAO (version)
import Util.CLI (mkCLOptionParser)
import Util.Named

import qualified Lorentz.Contracts.BaseDAO as DAO
import qualified Lorentz.Contracts.GameDAO as GameDAO

programInfo :: DGitRevision -> Opt.ParserInfo CmdLnArgs
programInfo gitRev = Opt.info (Opt.helper <*> versionOption <*> argParser contracts gitRev) $
  mconcat
  [ Opt.fullDesc
  , Opt.progDesc "BaseDAO contracts registry"
  , Opt.header "BaseDAO contracts for Michelson"
  , Opt.footerDoc usageDoc
  ]
  where
    versionOption = Opt.infoOption ("baseDAO-" <> showVersion version)
      (Opt.long "version" <> Opt.help "Show version.")

repoSettings :: GitRepoSettings
repoSettings = GitRepoSettings $ \commit ->
  "https://github.com/tqtezos/baseDAO/tree/" <> commit

usageDoc :: Maybe Doc
usageDoc = Just $ mconcat
   [ "You can use help for specific COMMAND", linebreak
   , "EXAMPLE:", linebreak
   , "  baseDAO print --help", linebreak
   ]

contracts :: ContractRegistry
contracts = ContractRegistry $ Map.fromList
  [ "BaseDAO" ?:: ContractInfo
    { ciContract = DAO.baseDaoContract DAO.defaultConfig
    , ciIsDocumented = True
    , ciStorageParser = Just $ baseDaoStorageParser @()
    , ciStorageNotes = Nothing
    }
  , "GameDAO" ?:: ContractInfo
    { ciContract = GameDAO.gameDaoContract
    , ciIsDocumented = True
    , ciStorageParser = Just $
        baseDaoStorageParser @GameDAO.GameDaoProposalMetadata
    , ciStorageNotes = Nothing
    }
  ]

baseDaoStorageParser :: forall m. Opt.Parser (DAO.Storage m)
baseDaoStorageParser = do
  adminAddress <-
    addressOption Nothing (#name .! "admin")
    (#help .! "Administrator of the DAO contract")
  votingPeriod <-
    mkCLOptionParser (Just $ 60 * 60 * 24 * 7) (#name .! "voting-period")
    (#help .! "Period after which proposals can be finished")
  quorumThreshold <-
    mkCLOptionParser (Just 4) (#name .! "quorum-threshold")
    (#help .! "Total number of votes necessary for successful proposal")
  pure $ DAO.mkStorage
    (#admin .! adminAddress)
    (#votingPeriod .? Just votingPeriod)
    (#quorumThreshold .? Just quorumThreshold)

main :: IO ()
main = withUtf8 $ do
  let gitRev = $(mkDGitRevision) repoSettings
  cmdLnArgs <- Opt.execParser (programInfo gitRev)
  runContractRegistry contracts cmdLnArgs `catchAny` (die . displayException)