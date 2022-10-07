# DAO progress

# Core

# Extensions
## Agora
- [ ] Vote type
  - [x] Yes/No
  - [ ] Preference
  - [ ] Percentage
- [ ] Dynamical proposal status?
- [ ] total vote count?
- [ ] Batch functions
### States
`(bytes32 => Proposal) proposals;`  
`(bytes4 => VoteParam) voteParams;`  
`(bytes32 => mapping(address => bool)) votes;`  
### Entry points
- **submitProposal**  
Access: All adapters  

- **changeVoteParams**  
Access: `Voting.sol`

- **submitVote**  
Access: `Voting.sol`



## Bank
- [ ] Commitments
  - [ ] manage user balance/ proposal
  - [ ] use user's available balance
- [ ] Vault management
- [ ] Batch functions

# Adapters
## Voting

### Managing
### Onboarding
### Financing

---
## Utils
### Abstract
#### CoreGuard
#### SlotGuard
### Library
#### Slot
#### ScoreUtils 