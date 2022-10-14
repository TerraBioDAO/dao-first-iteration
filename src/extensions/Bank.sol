// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import "../helpers/Slot.sol";
import "../guards/CoreGuard.sol";
import "../extensions/IAgora.sol";

/**
 * @notice Should be the only contract to approve to move tokens
 *
 * Manage only the TBIO token
 */

contract Bank is CoreGuard, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address public immutable terraBioToken;
    uint64 internal constant DAY = 86400;
    uint32 internal immutable MAX_TIMESTAMP;

    event NewCommitment(
        bytes32 indexed proposalId,
        address indexed account,
        uint256 indexed lockPeriod,
        uint256 lockedAmount
    );
    event Deposit(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    struct User {
        Account account;
        mapping(bytes32 => Commitment) commitments;
        EnumerableSet.Bytes32Set commitmentsList;
    }

    struct Account {
        uint128 availableBalance;
        uint96 lockedBalance; // until 100_000 proposals
        uint32 nextRetrieval;
    }

    /**
     * @notice Max amount locked per proposal is 50_000
     * With a x50 multiplier the voteWeight is at 2.5**24
     * Which is less than 2**96 (uint96)
     * lockPeriod and retrievalDate can be stored in uint32
     * the retrieval date would overflow if it is set to 82 years
     */
    struct Commitment {
        uint96 lockedAmount;
        uint96 voteWeight;
        uint32 lockPeriod;
        uint32 retrievalDate;
    }

    mapping(address => User) private _users;

    mapping(address => mapping(bytes4 => uint256)) public internalBalances;

    //mapping(bytes4 => uint256) public vaultsBalance;
    //mapping(bytes32 => uint256) public financingProposalsBalance;

    constructor(address core, address terraBioTokenAddr) CoreGuard(core, Slot.BANK) {
        terraBioToken = terraBioTokenAddr;
        uint32 maxTimestamp;
        unchecked {
            --maxTimestamp;
        }
        MAX_TIMESTAMP = maxTimestamp;
    }

    function userAdvanceDeposit(address user, uint128 amount)
        external
        onlyAdapter(ISlotEntry(msg.sender).slotId())
    {
        _users[user].account.availableBalance += amount;
        _depositTransfer(user, amount);
    }

    function newCommitment(
        address user,
        bytes32 proposalId,
        uint96 lockedAmount,
        uint32 lockPeriod,
        uint96 advanceDeposit
    ) external onlyAdapter(Slot.VOTING) returns (uint96 voteWeight) {
        require(!_users[user].commitmentsList.contains(proposalId), "Bank: already committed");

        Account memory a = _users[user].account;

        // check for available balance
        if (block.timestamp >= a.nextRetrieval) {
            a = _updateUserAccount(a, user);
        }

        // calcul amount to deposit in the contract
        uint256 toTransfer;
        if (a.availableBalance >= lockedAmount) {
            a.availableBalance -= lockedAmount;
        } else {
            toTransfer = lockedAmount - a.availableBalance;
            a.availableBalance = 0;
        }

        _depositTransfer(user, toTransfer + advanceDeposit);

        uint32 retrievalDate = uint32(block.timestamp) + lockPeriod;
        a.availableBalance += advanceDeposit;
        a.lockedBalance += lockedAmount;

        if (a.nextRetrieval > retrievalDate) {
            a.nextRetrieval = retrievalDate;
        }

        voteWeight = _calculVoteWeight(lockPeriod, lockedAmount);

        _users[user].commitmentsList.add(proposalId);
        _users[user].commitments[proposalId] = Commitment(
            lockedAmount,
            voteWeight,
            lockPeriod,
            retrievalDate
        );
        _users[user].account = a;

        emit NewCommitment(proposalId, user, lockPeriod, lockedAmount);
    }

    function withdrawAmount(address user, uint128 amount) external onlyAdapter(Slot.VOTING) {
        Account memory a = _users[user].account;

        if (block.timestamp >= a.nextRetrieval) {
            a = _updateUserAccount(a, user);
        }

        require(a.availableBalance <= amount, "Bank: insuffisant available balance");
        a.availableBalance -= amount;
        _users[user].account = a;
        _withdrawTransfer(user, amount);
    }

    function executeFinancingProposal(address applicant, uint256 amount)
        external
        onlyAdapter(Slot.FINANCING)
        returns (bool)
    {
        require(
            IERC20(terraBioToken).balanceOf(address(this)) >= amount,
            "Bank: insufficient funds in bank"
        );

        // todo : adjust vaultsBalance and financingProposalsBalance

        return IERC20(terraBioToken).transfer(applicant, amount);
    }

    function recoverProposalFunds(bytes32 proposalId, address member)
        external
        onlyAdapter(Slot.FINANCING)
    {
        IAgora agora = IAgora(IDaoCore(_core).getSlotContractAddr(Slot.AGORA));
        require(
            agora.getProposal(proposalId).status == IAgora.ProposalStatus.EXECUTED,
            "Bank: not executed"
        );

        uint256 balance = _users[member].commitments[proposalId].lockedAmount;
        require(balance > 0, "Bank: no funds for this proposal");

        IERC20(terraBioToken).transferFrom(address(this), member, balance);
    }

    function getBalances(address user)
        external
        view
        returns (uint128 availableBalance, uint128 lockedBalance)
    {
        Account memory a = _users[user].account;
        availableBalance = a.availableBalance;
        lockedBalance = a.lockedBalance;

        uint256 timestamp = block.timestamp;
        for (uint256 i; i < _users[user].commitmentsList.length(); ) {
            Commitment memory c = _users[user].commitments[_users[user].commitmentsList.at(i)];
            if (timestamp >= c.retrievalDate) {
                availableBalance += c.lockedAmount;
                lockedBalance -= c.lockedAmount;
            }
        }
    }

    function getCommitmentsList(address user) external view returns (bytes32[] memory) {
        uint256 length = _users[user].commitmentsList.length();
        bytes32[] memory commitmentsList = new bytes32[](length);
        for (uint256 i; i < length; ) {
            commitmentsList[i] = _users[user].commitmentsList.at(i);
        }

        return commitmentsList;
    }

    function getCommitment(address user, bytes32 proposalId)
        external
        view
        returns (
            uint96,
            uint96,
            uint32,
            uint32
        )
    {
        Commitment memory c = _users[user].commitments[proposalId];
        require(c.lockedAmount > 0, "Bank: inexistant commitment");
        return (c.lockedAmount, c.voteWeight, c.lockPeriod, c.retrievalDate);
    }

    function getNextRetrievalDate(address user) external view returns (uint32 nextRetrievalDate) {
        nextRetrievalDate = _users[user].account.nextRetrieval;

        if (block.timestamp >= nextRetrievalDate) {
            nextRetrievalDate = MAX_TIMESTAMP;
            uint256 timestamp = block.timestamp;
            for (uint256 i; i < _users[user].commitmentsList.length(); ) {
                Commitment memory c = _users[user].commitments[_users[user].commitmentsList.at(i)];

                if (c.retrievalDate > timestamp) {
                    if (c.retrievalDate < nextRetrievalDate) {
                        nextRetrievalDate = c.retrievalDate;
                    }
                }

                unchecked {
                    ++i;
                }
            }

            // return 0 if no more commitments
            if (nextRetrievalDate == MAX_TIMESTAMP) {
                delete nextRetrievalDate;
            }
        }
    }

    // INTERNAL FONCTION
    function _depositTransfer(address account, uint256 amount) internal {
        if (amount > 0) {
            IERC20(terraBioToken).transferFrom(account, address(this), amount);
            emit Deposit(account, amount);
        }
    }

    function _withdrawTransfer(address account, uint256 amount) internal {
        IERC20(terraBioToken).transfer(account, amount);
        emit Withdrawn(account, amount);
    }

    function _changeInternalBalance(
        address account,
        bytes4 unit,
        bool isDeposit,
        uint256 amount
    ) internal {
        uint256 balance = internalBalances[account][unit];
        if (!isDeposit) {
            require(amount <= balance, "Bank: insufficiant balance");
            internalBalances[account][unit] -= amount;
        } else {
            internalBalances[account][unit] += amount;
        }
    }

    function _updateUserAccount(Account memory account, address user)
        internal
        returns (Account memory)
    {
        uint256 timestamp = block.timestamp;
        uint32 nextRetrievalDate;
        unchecked {
            --nextRetrievalDate; // set maximal value
        }

        // check the commitments list

        // read each time? => _users[user].commitmentsList.length();
        for (uint256 i; i < _users[user].commitmentsList.length(); ) {
            bytes32 proposalId = _users[user].commitmentsList.at(i);
            Commitment memory c = _users[user].commitments[proposalId];

            // is over?
            if (timestamp >= c.retrievalDate) {
                account.availableBalance += c.lockedAmount;
                account.lockedBalance -= c.lockedAmount;
                delete _users[user].commitments[proposalId];
                _users[user].commitmentsList.remove(proposalId);
            } else {
                // store the next retrieval
                if (nextRetrievalDate > c.retrievalDate) {
                    nextRetrievalDate = c.retrievalDate;
                }
            }

            // loop
            unchecked {
                ++i;
            }
        }
        account.nextRetrieval = nextRetrievalDate;

        // return memory object
        return account;
    }

    function _calculVoteWeight(uint32 lockPeriod, uint96 lockAmount)
        internal
        pure
        returns (uint96)
    {
        if (lockPeriod == DAY) {
            return lockAmount / 10;
        } else if (lockPeriod == 7 * DAY) {
            return lockPeriod;
        } else if (lockPeriod == 15 * DAY) {
            return lockPeriod * 2;
        } else if (lockPeriod == 30 * DAY) {
            return lockPeriod * 4;
        } else if (lockPeriod == 120 * DAY) {
            return lockPeriod * 25;
        } else if (lockPeriod == 365 * DAY) {
            return lockPeriod * 50;
        } else {
            revert("Bank: incorrect lock period");
        }
    }
}
