-- SPDX-FileCopyrightText: 2020 TQ Tezos
-- SPDX-License-Identifier: LicenseRef-MIT-TQ

{-# LANGUAGE RebindableSyntax #-}
{-# OPTIONS_GHC -Wno-unused-do-bind #-}

-- | Template for DAO. Writing your own DAO can be starting from copying this
-- module.
--
-- Some bits are already initialized as example.
-- You can follow @TODO@s to make sure that all the code is updated.
--
-- In case of non-trivial contract feel free to split this into modules.
module Main
  ( main
  ) where

import Lorentz
import Universum (IO, Num (..))

import Paths_templateDAO (version)

import Lorentz.ContractRegistry
import Util.Markdown

import Lorentz.Contracts.BaseDAO
import BaseDAO.CLI

------------------------------------------------------------------------
-- DAO logic
------------------------------------------------------------------------

-- TODO: Read the following section and fill it with the implementation.

-- | Proposal metadata.
data ProposalMetadata = ProposalMetadata
  {
    mpmDescription :: MText
    -- ^ Proposal description.
  , mpmNonce :: Natural
    -- ^ Include this if it should be possible to offer equivalent proposals,
    -- by default proposals of any given sender must be unique.
  , mpmPayload :: Integer
    -- ^ Other useful fields go here.
  } deriving stock (Generic)
    deriving anyclass (IsoValue)

instance HasAnnotation ProposalMetadata where
  annOptions = daoAnnOptions

instance TypeHasDoc ProposalMetadata where
  typeDocMdDescription = [md|
    User's proposal metadata.

    This description will appear in the autogenerated documentation for the
    entire DAO contract.
    |]

-- | Global extra in contract state. Left empty here, but can be initialized
-- similarly to 'ProposalMetadata'.
type ContractExtra = ()

-- | DAO configuration.
config :: Config ContractExtra ProposalMetadata
config = Config
  { cDaoName =
      "Custom DAO"
  , cDaoDescription =
      "Your description here"
  , cUnfrozenTokenMetadata =
      -- Token metadata as described in FA2, change it if you need a custom
      -- token semantics
      cUnfrozenTokenMetadata defaultConfig
  , cFrozenTokenMetadata =
      cFrozenTokenMetadata defaultConfig

  , cProposalCheck = do
      -- storage is not needed
      dip drop
      -- Verification at proposal stage.
      -- Here we implement a simple predicate that ensures our payload to be
      -- not too high.

      -- Get our proposal metadata
      toField #ppProposalMetadata
      -- Get payload
      toField #mpmPayload

      -- Check that payload is under the limit
      push 50; ge

  , cRejectedProposalReturnValue = do
      -- storage is not needed
      dip drop

      -- How many tokens to return on proposal rejection.

      -- Here we provide a simple implementation that returns
      -- all the tokens back to the proposal's author.
      toField #pProposerFrozenToken; toNamed #slash_amount

  , cDecisionLambda =
      -- Handler for successfully accepted proposal.
      error "not implemented"

  , cMaxVotingPeriod = 60 * 60 * 24 * 30  -- 30 days
  , cMinVotingPeriod = 1

  , cMaxQuorumThreshold = 1000
  , cMinQuorumThreshold = 1

  , cMaxVotes = 1000

    -- Maximum number of ongoing proposals.
    -- This must be limited because number of ongoing proposals affects
    -- contract gas consumption.
  , cMaxProposals = 500
  }

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

-- | How we derive annotations from field names for our types.
daoAnnOptions :: AnnOptions
daoAnnOptions = defaultAnnOptions { fieldAnnModifier = dropPrefixThen toSnake }

------------------------------------------------------------------------
-- Running an executable
------------------------------------------------------------------------

-- | All the contracts served by executable.
contracts :: ContractRegistry
contracts = daoContractRegistry
  [ DaoContractInfo
      -- TODO: pass the desired name of the contract
    { dciName = "DAO"
    , dciConfig = config
    , dciExtraParser = pure def
    }
  ]

-- | Attaches a reference to your git repository into the documentation.
gitRev :: DGitRevision
gitRev = $mkDGitRevision . GitRepoSettings $ \commit ->
  "https://github.com/username/reponame/tree/" <> commit
  -- TODO: update this to refer to your repository, the link will appear in
  -- the generated documentation

-- Another possible implementation, in case
-- you don't keep your code in a repository
-- gitRev = DGitRevisionUnknown

main :: IO ()
main =
  -- TODO: insert the desired name of the executable
  serveContractRegistry "DAO" gitRev contracts version