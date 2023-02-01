// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { Extension, Slot, IDaoCore } from "../abstracts/Extension.sol";
import { IBank } from "../interfaces/IBank.sol";
import { IProposerAdapter } from "../interfaces/IProposerAdapter.sol";
import { Constants } from "../helpers/Constants.sol";
import { ISlotEntry } from "../interfaces/ISlotEntry.sol";

/**
 * @title Extension contract for funding and commitment process
 * @notice End users do not interact directly with this contract (read-only)
 *
 * @dev The contract stores:
 *      - users commitment for voting
 *      - DAO's vaults
 * When user vote they commit an amount of $TBIO into this contract on
 * different amount of time to calculate their vote weight. Thus users
 * express their level of commitment through the amount of token and time
 * period they lock tokens in this contract.
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

    /**
     * @notice Address of the Terrabio token
     * @return token contract address
     */
    address public immutable terraBioToken;
    uint32 internal immutable MAX_TIMESTAMP;

    /// @dev track users account by their address
    mapping(address => User) private _users;

    /// @dev track DAO's vault by their ID
    mapping(bytes4 => Vault) private _vaults;

    /**
     * @dev The Terrabio token is set as an `immutable` variable
     *
     * @param core address of DaoCore
     * @param terraBioTokenAddr address of the Terrabio token
     */
    constructor(address core, address terraBioTokenAddr) Extension(core, Slot.BANK) {
        terraBioToken = terraBioTokenAddr;
        MAX_TIMESTAMP = type(uint32).max;
    }

    /*//////////////////////////////////////////////////////////
                            PUBLIC FONCTIONS 
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Called by VOTING adapter to commit an user's vote, then
     * a vote weight for a specific proposal is received.
     * @dev Users can commit only once, without cancelation, the contract check if the
     * user have already TBIO in his account, otherwise the contract take from
     * owner's balance (Bank must be approved).
     * {lockPeriod} is chosen among a set of period and cannot be custom
     * User's balance is updated before checking his account, see {_updateUserAccount}
     *
     * @param user user's address
     * @param proposalId proposal to commit on
     * @param lockedAmount amount of token to lock
     * @param lockPeriod period of time to lock tokens
     * @param advanceDeposit amount of token user want to deposit into his account
     * @return voteWeight weight of the vote for this proposal
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
     * @notice Called by VOTING adapter to initiate a withdrawal from
     * an user's account. User can only withdraw unlocked token.
     *
     * @param user user's address
     * @param amount amount of token to withdraw
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
     * @notice Called by any adapter which implement this function, used
     * to fill user's account in prevision of future votes.
     *
     * @param user user's address
     * @param amount amount of token to deposit
     */
    function advancedDeposit(address user, uint128 amount)
        external
        onlyAdapter(ISlotEntry(msg.sender).slotId())
    {
        _users[user].account.availableBalance += amount;
        _depositTransfer(user, amount);
    }

    /**
     * @notice Called by FINANCING adapter to deposit an amount of
     * token into the vault. Tokens address should be registered into
     * the vault.
     * @dev WARNING: This function should restricted in the FINANCING adapter,
     * to prevent any user to abuse of other user's Bank approval.
     *
     * @param vaultId vaultID to depose on
     * @param tokenAddr token contract address to deposit
     * @param tokenOwner token amount provenance
     * @param amount amount of token to deposit
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
     * @notice Called by FINANCING adapter to create a vault in the DAO
     * @dev `address(0)` is used to manage blockchain native token. Checking
     * if tokenAddr is an ERC20 is not 100% useful and can be bypassed.
     *
     * @param vaultId vaultID to create
     * @param tokenList list of token address the vault can manage
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
     * @notice Called by FINANCING adapter when a transaction request is
     * created, allow to block an amount of token during the request acceptation
     * period.
     * @dev Funds are commited to prevent transaction request on inexistant funds
     * MISSING IMPL: funds committed must return available when the transaction request
     * is rejected
     *
     * @param vaultId vaultID to commit
     * @param tokenAddr token address the vault will commit funds
     * @param destinationAddr future address of transferred funds
     * @param amount amount of token to commit
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
     * @notice Called by FINANCING adapter when a transaction request
     * is accepted. Funds are transferred to the destination address.
     * @dev For $TBIO, ff the the destination address is a member of the DAO, funds
     * are internally transferred into his account (without calling transfer)
     *
     * @param vaultId vaultID from where funds are transferred
     * @param tokenAddr token address of funds sended
     * @param destinationAddr address who will receive funds
     * @param amount amount of token to send
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
            IDaoCore(_core).hasRole(destinationAddr, ROLE_MEMBER)
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

    /*//////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////*/

    /**
     * @notice Get user's balance details
     * @param user user's address to check
     * @return availableBalance user's available balance
     * @return lockedBalance user's commited balance for votes
     */
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

    /**
     * @notice Get the list of proposals user have commited token on
     * @param user user's address to check
     * @return list of proposalId
     */
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

    /**
     * @notice Get an user's commitment details
     * @param user user's address to check
     * @param proposalId proposal to check
     * @return amount of token locked
     * @return received vote weight
     * @return period of lock
     * @return timestamp when user can withdraw tokens
     */
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

    /**
     * @notice Get the next timestamp when an user can withdraw tokens
     *
     * @param user user's address to check
     * @return nextRetrievalDate timestamp when an user can withdraw tokens, return 0 if no more
     * commitment
     */
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

    /**
     * @notice Get balance details of a vault
     *
     * @param vaultId vaultID to to check
     * @param tokenAddr address to check balance
     * @return available balance
     * @return commited balance
     */
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

    /**
     * @notice Get list of registered token of a vault
     *
     * @param vaultId vaultID to to check
     * @return list of token address
     */
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

    /**
     * @notice Check if a specifi token address is registered in a vault
     *
     * @param vaultId vaultID to to check
     * @param tokenAddr address to check
     * @return true if token address is registered
     */
    function isTokenInVaultTokenList(bytes4 vaultId, address tokenAddr)
        external
        view
        returns (bool)
    {
        return _vaults[vaultId].tokenList.contains(tokenAddr);
    }

    /**
     * @notice Check if a vault exist
     *
     * @param vaultId vaultID to to check
     * @return true if the vault exist
     */
    function isVaultExist(bytes4 vaultId) external view returns (bool) {
        return _vaults[vaultId].isExist;
    }

    /*//////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////*/

    /**
     * @dev Deposit only if amount is greater than 0, used for deposit
     * $TBIO into user's account.
     *
     * @param account user address who deposit
     * @param amount amount user deposit
     */
    function _depositTransfer(address account, uint256 amount) internal {
        if (amount > 0) {
            IERC20(terraBioToken).transferFrom(account, address(this), amount);
            emit Deposit(account, amount);
        }
    }

    /**
     * @dev Used to withdraw an amount from user's account to
     * his address. Check are done before calling this function.
     *
     * @param account user address who withdraw
     * @param amount amount user withdraw
     */
    function _withdrawTransfer(address account, uint256 amount) internal {
        IERC20(terraBioToken).transfer(account, amount);
        emit Withdrawn(account, amount);
    }

    /**
     * @dev Update user's balance regarding unlocking of tokens.
     * The function take and return the {Account} struct in memory.
     *
     * @param account user {Account}
     * @param user user's address
     * @return Updated {Account} struct
     */
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

    /**
     * @dev Check the lock period and calculate the vote weight
     * @param lockPeriod time period the amount of token
     * @param lockAmount amount of token to lock
     * @return calculated vote weight
     */
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
