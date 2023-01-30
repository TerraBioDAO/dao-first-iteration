// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { IAccessControl } from "openzeppelin-contracts/access/AccessControl.sol";

import { Extension, Slot, IDaoCore } from "../abstracts/Extension.sol";
import { IBank } from "../interfaces/IBank.sol";
import { IProposerAdapter } from "../interfaces/IProposerAdapter.sol";
import { Constants } from "../helpers/Constants.sol";
import { ISlotEntry } from "../interfaces/ISlotEntry.sol";

/**
 * @notice Should be the only contract to approve to move tokens
 *
 * Manage only the TBIO token
 */

contract Bank is Extension, ReentrancyGuard, IBank, Constants {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct User {
        Account account;
        mapping(bytes32 => Commitment) commitments;
        EnumerableSet.Bytes32Set commitmentsList;
    }

    struct Vault {
        bool isExist;
        EnumerableSet.AddressSet tokenList;
        mapping(address => Balance) balance;
    }

    address public immutable terraBioToken;
    uint32 internal immutable MAX_TIMESTAMP;

    mapping(address => User) private _users;
    mapping(bytes4 => Vault) private _vaults;

    constructor(address core, address terraBioTokenAddr) Extension(core, Slot.BANK) {
        terraBioToken = terraBioTokenAddr;
        MAX_TIMESTAMP = type(uint32).max;
    }

    /* //////////////////////////
            PUBLIC FUNCTIONS
    ////////////////////////// */
    /**
     * @notice allow users to lock TBIO in several period of time in the contract,
     * and receive a vote weight for a specific proposal
     *
     * User can commit only once, without cancelation, the contract check if the
     * user have already TBIO in his account, otherwise the contract take from
     * owner's balance (Bank must be approved).
     */
    function newCommitment(
        address user,
        bytes32 proposalId,
        uint96 lockedAmount,
        uint32 lockPeriod,
        uint96 advanceDeposit
    ) external onlyAdapter(Slot.VOTING) returns (uint96 voteWeight) {
        require(!_users[user].commitmentsList.contains(proposalId), "Bank: already committed");

        Account memory account_ = _users[user].account;

        // check for available balance
        if (block.timestamp >= account_.nextRetrieval) {
            account_ = _updateUserAccount(account_, user);
        }

        // calcul amount to deposit in the contract
        uint256 toTransfer;
        if (account_.availableBalance >= lockedAmount) {
            account_.availableBalance -= lockedAmount;
        } else {
            toTransfer = lockedAmount - account_.availableBalance;
            account_.availableBalance = 0;
        }

        _depositTransfer(user, toTransfer + advanceDeposit);

        uint32 retrievalDate = uint32(block.timestamp) + lockPeriod;
        account_.availableBalance += advanceDeposit;
        account_.lockedBalance += lockedAmount;

        if (account_.nextRetrieval > retrievalDate) {
            account_.nextRetrieval = retrievalDate;
        }

        voteWeight = _calculVoteWeight(lockPeriod, lockedAmount);

        // storage writing
        _users[user].commitmentsList.add(proposalId);
        _users[user].commitments[proposalId] = Commitment(
            lockedAmount,
            voteWeight,
            lockPeriod,
            retrievalDate
        );
        _users[user].account = account_;

        emit NewCommitment(proposalId, user, lockPeriod, lockedAmount);
    }

    /**
     * @notice allow member to withdraw available balance of TBIO, only from
     * owner's account.
     */
    function withdrawAmount(address user, uint128 amount) external onlyAdapter(Slot.VOTING) {
        Account memory account_ = _users[user].account;

        if (block.timestamp >= account_.nextRetrieval) {
            account_ = _updateUserAccount(account_, user);
        }

        require(account_.availableBalance <= amount, "Bank: insuffisant available balance");
        account_.availableBalance -= amount;
        _users[user].account = account_;
        _withdrawTransfer(user, amount);
        emit Withdrawn(user, amount);
    }

    /**
     * @notice allows member to deposit TBIO in their account, enable
     * deposit for several vote.
     *
     * NOTE users can also do an `advancedDeposit` when they call `newCommitment`
     */
    function advancedDeposit(address user, uint128 amount)
        external
        onlyAdapter(ISlotEntry(msg.sender).slotId())
    {
        _users[user].account.availableBalance += amount;
        _depositTransfer(user, amount);
    }

    /**
     * @notice used to deposit funds in a specific vault, funds are
     * stored on the Bank contract, from a specific address (which has
     * approved Bank)
     *
     * SECURITY! any member who has approved the Bank can be attacked
     * a security check should be implemented here or in `Financing`
     */
    function vaultDeposit(
        bytes4 vaultId,
        address tokenAddr,
        address tokenOwner,
        uint128 amount
    ) external onlyAdapter(Slot.FINANCING) {
        require(_vaults[vaultId].isExist, "Bank: inexistant vaultId");
        require(_vaults[vaultId].tokenList.contains(tokenAddr), "Bank: unregistred token");

        IERC20(tokenAddr).transferFrom(tokenOwner, address(this), amount);
        _vaults[vaultId].balance[tokenAddr].availableBalance += amount;
        emit VaultTransfer(vaultId, tokenAddr, tokenOwner, address(this), amount);
    }

    /**
     * @notice allow admin to create a vault in the Bank,
     * with an associated tokenList.
     *
     * address(0) is used to manage blockchain native token, checking
     * if tokenAddr is an ERC20 is not 100% useful, only prevent mistake
     */
    function createVault(bytes4 vaultId, address[] memory tokenList)
        external
        onlyAdapter(Slot.FINANCING)
    {
        require(!_vaults[vaultId].isExist, "Bank: vault already exist");
        for (uint256 i; i < tokenList.length; ) {
            //require(address(IERC20(tokenList[i])) != address(0), "Bank: non erc20 token");
            _vaults[vaultId].tokenList.add(tokenList[i]);
            unchecked {
                ++i;
            }
        }
        _vaults[vaultId].isExist = true;

        emit VaultCreated(vaultId);
    }

    /**
     * @notice called when a transaction request on a vault is done.
     * Funds are commited to prevent an overcommitment for member and thus
     * block the transaction request
     *
     * TODO funds committed must return available when the transaction request
     * is rejected
     */
    function vaultCommit(
        bytes4 vaultId,
        address tokenAddr,
        address destinationAddr,
        uint128 amount
    ) external onlyAdapter(Slot.FINANCING) {
        require(_vaults[vaultId].isExist, "Bank: inexistant vaultId");
        require(
            _vaults[vaultId].balance[tokenAddr].availableBalance >= amount,
            "Bank: not enough in the vault"
        );

        _vaults[vaultId].balance[tokenAddr].availableBalance -= amount;
        _vaults[vaultId].balance[tokenAddr].commitedBalance += amount;

        emit VaultAmountCommitted(vaultId, tokenAddr, destinationAddr, amount);
    }

    /**
     * @notice called when a transaction request is accepted,
     * funds are transferred to the destination address
     */
    function vaultTransfer(
        bytes4 vaultId,
        address tokenAddr,
        address destinationAddr,
        uint128 amount
    ) external nonReentrant onlyAdapter(Slot.FINANCING) returns (bool) {
        _vaults[vaultId].balance[tokenAddr].commitedBalance -= amount;

        if (
            tokenAddr == address(terraBioToken) &&
            IAccessControl(_core).hasRole(ROLE_MEMBER, destinationAddr)
        ) {
            // TBIO case
            // applicant is a member receive proposal amount on his internal account
            // he should withdraw it if needed
            _users[destinationAddr].account.availableBalance += amount;

            emit VaultTransfer(vaultId, tokenAddr, address(this), address(this), amount);
            return true;
        }

        // important nonReentrant here as we don't track proposalId and balance associated
        IERC20(tokenAddr).transfer(destinationAddr, amount);

        emit VaultTransfer(vaultId, tokenAddr, address(this), destinationAddr, amount);

        return true;
    }

    /* //////////////////////////
                GETTERS
    ////////////////////////// */
    function getBalances(address user)
        external
        view
        returns (uint128 availableBalance, uint128 lockedBalance)
    {
        Account memory account_ = _users[user].account;
        availableBalance = account_.availableBalance;
        lockedBalance = account_.lockedBalance;

        uint256 timestamp = block.timestamp;
        for (uint256 i; i < _users[user].commitmentsList.length(); ) {
            Commitment memory commitment_ = _users[user].commitments[
                _users[user].commitmentsList.at(i)
            ];
            if (timestamp >= commitment_.retrievalDate) {
                availableBalance += commitment_.lockedAmount;
                lockedBalance -= commitment_.lockedAmount;
            }

            unchecked {
                ++i;
            }
        }
    }

    function getCommitmentsList(address user) external view returns (bytes32[] memory) {
        uint256 length = _users[user].commitmentsList.length();
        bytes32[] memory commitmentsList = new bytes32[](length);
        for (uint256 i; i < length; ) {
            commitmentsList[i] = _users[user].commitmentsList.at(i);

            unchecked {
                ++i;
            }
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
        Commitment memory commitment_ = _users[user].commitments[proposalId];
        require(commitment_.lockedAmount > 0, "Bank: inexistant commitment");
        return (
            commitment_.lockedAmount,
            commitment_.voteWeight,
            commitment_.lockPeriod,
            commitment_.retrievalDate
        );
    }

    function getNextRetrievalDate(address user) external view returns (uint32 nextRetrievalDate) {
        nextRetrievalDate = _users[user].account.nextRetrieval;

        if (block.timestamp >= nextRetrievalDate) {
            nextRetrievalDate = MAX_TIMESTAMP;
            uint256 timestamp = block.timestamp;
            for (uint256 i; i < _users[user].commitmentsList.length(); ) {
                Commitment memory commitment_ = _users[user].commitments[
                    _users[user].commitmentsList.at(i)
                ];

                if (commitment_.retrievalDate > timestamp) {
                    if (commitment_.retrievalDate < nextRetrievalDate) {
                        nextRetrievalDate = commitment_.retrievalDate;
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

    function getVaultBalances(bytes4 vaultId, address tokenAddr)
        external
        view
        returns (uint128, uint128)
    {
        //require(this.isVaultExist(vaultId), "Bank: non-existent vaultId");
        //require(this.isTokenInVaultTokenList(vaultId, tokenAddr), "Bank: token not in vault list");
        Balance memory balance_ = _vaults[vaultId].balance[tokenAddr];
        return (balance_.availableBalance, balance_.commitedBalance);
    }

    function getVaultTokenList(bytes4 vaultId) external view returns (address[] memory) {
        uint256 length = _vaults[vaultId].tokenList.length();
        address[] memory tokenList = new address[](length);
        for (uint256 i; i < length; ) {
            tokenList[i] = _vaults[vaultId].tokenList.at(i);
            unchecked {
                ++i;
            }
        }
        return tokenList;
    }

    function isTokenInVaultTokenList(bytes4 vaultId, address tokenAddr)
        external
        view
        returns (bool)
    {
        return _vaults[vaultId].tokenList.contains(tokenAddr);
    }

    function isVaultExist(bytes4 vaultId) external view returns (bool) {
        return _vaults[vaultId].isExist;
    }

    /* //////////////////////////
        INTERNAL FUNCTIONS
    ////////////////////////// */
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

    function _updateUserAccount(Account memory account, address user)
        internal
        returns (Account memory)
    {
        uint256 timestamp = block.timestamp;
        uint32 nextRetrievalDate = MAX_TIMESTAMP;

        // check the commitments list

        // read each time? => _users[user].commitmentsList.length();
        for (uint256 i; i < _users[user].commitmentsList.length(); ) {
            bytes32 proposalId = _users[user].commitmentsList.at(i);
            Commitment memory commitment_ = _users[user].commitments[proposalId];

            // is over?
            if (timestamp >= commitment_.retrievalDate) {
                account.availableBalance += commitment_.lockedAmount;
                account.lockedBalance -= commitment_.lockedAmount;
                delete _users[user].commitments[proposalId];
                _users[user].commitmentsList.remove(proposalId);
            } else {
                // store the next retrieval
                if (nextRetrievalDate > commitment_.retrievalDate) {
                    nextRetrievalDate = commitment_.retrievalDate;
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
        if (lockPeriod == 1 days) {
            return lockAmount / 10;
        } else if (lockPeriod == 7 days) {
            return lockAmount;
        } else if (lockPeriod == 15 days) {
            return lockAmount * 2;
        } else if (lockPeriod == 30 days) {
            return lockAmount * 4;
        } else if (lockPeriod == 120 days) {
            return lockAmount * 25;
        } else if (lockPeriod == 365 days) {
            return lockAmount * 50;
        } else {
            revert("Bank: incorrect lock period");
        }
    }
}
