// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import "../abstracts/Extension.sol";
import "../interfaces/IBank.sol";
import "../interfaces/IProposerAdapter.sol";
import "../helpers/Constants.sol";

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
    function newCommitment(
        address user,
        bytes32 proposalId,
        uint96 lockedAmount,
        uint32 lockPeriod,
        uint96 advanceDeposit
    ) external onlyAdapter(Slot.VOTING) returns (uint96 voteWeight) {
        require(!_users[user].commitmentsList.contains(proposalId), "Bank: already committed");

        Account memory _account = _users[user].account;

        // check for available balance
        if (block.timestamp >= _account.nextRetrieval) {
            _account = _updateUserAccount(_account, user);
        }

        // calcul amount to deposit in the contract
        uint256 toTransfer;
        if (_account.availableBalance >= lockedAmount) {
            _account.availableBalance -= lockedAmount;
        } else {
            toTransfer = lockedAmount - _account.availableBalance;
            _account.availableBalance = 0;
        }

        _depositTransfer(user, toTransfer + advanceDeposit);

        uint32 retrievalDate = uint32(block.timestamp) + lockPeriod;
        _account.availableBalance += advanceDeposit;
        _account.lockedBalance += lockedAmount;

        if (_account.nextRetrieval > retrievalDate) {
            _account.nextRetrieval = retrievalDate;
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
        _users[user].account = _account;

        emit NewCommitment(proposalId, user, lockPeriod, lockedAmount);
    }

    function withdrawAmount(address user, uint128 amount) external onlyAdapter(Slot.VOTING) {
        Account memory _account = _users[user].account;

        if (block.timestamp >= _account.nextRetrieval) {
            _account = _updateUserAccount(_account, user);
        }

        require(_account.availableBalance <= amount, "Bank: insuffisant available balance");
        _account.availableBalance -= amount;
        _users[user].account = _account;
        _withdrawTransfer(user, amount);
        emit Withdrawn(user, amount);
    }

    function advancedDeposit(address user, uint128 amount)
        external
        onlyAdapter(ISlotEntry(msg.sender).slotId())
    {
        _users[user].account.availableBalance += amount;
        _depositTransfer(user, amount);
    }

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

    function vaultCommit(
        bytes4 vaultId,
        address tokenAddr,
        uint128 amount
    ) external onlyAdapter(Slot.FINANCING) {
        //require(_vaults[vaultId].isExist, "Bank: inexistant vaultId");
        /*require(
            _vaults[vaultId].balance[tokenAddr].availableBalance >= amount,
            "Bank: not enough in the vault"
        );*/

        _vaults[vaultId].balance[tokenAddr].availableBalance -= amount;
        _vaults[vaultId].balance[tokenAddr].commitedBalance += amount;

        emit VaultAmountCommitted(vaultId, tokenAddr, amount);
    }

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

    /* //////////////////////////
                GETTERS
    ////////////////////////// */
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

    function getVaultBalances(bytes4 vaultId, address tokenAddr)
        external
        view
        returns (uint128, uint128)
    {
        //require(this.isVaultExist(vaultId), "Bank: non-existent vaultId");
        //require(this.isTokenInVaultTokenList(vaultId, tokenAddr), "Bank: token not in vault list");
        Balance memory b = _vaults[vaultId].balance[tokenAddr];
        return (b.availableBalance, b.commitedBalance);
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
