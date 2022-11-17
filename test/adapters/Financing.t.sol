// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

//import "openzeppelin-contracts/utils/Counters.sol";
import "test/base/BaseDaoTest.sol";
import "src/adapters/Financing.sol";

contract FinancingSlots {
    // BEGIN COPY VARS from contract to test
    // run 'forge inspect Financing storage --pretty'
    //+-------------------+-----------------------------------------------+------+--------+-------+--------------------------------------+
    //| Name              | Type                                          | Slot | Offset | Bytes | Contract                             |
    //+==================================================================================================================================+
    //| _paused           | bool                                          | 0    | 0      | 1     | src/adapters/Financing.sol:Financing |
    //|-------------------+-----------------------------------------------+------+--------+-------+--------------------------------------|
    //| _ongoingProposals | struct Counters.Counter                       | 1    | 0      | 32    | src/adapters/Financing.sol:Financing |
    //|-------------------+-----------------------------------------------+------+--------+-------+--------------------------------------|
    //| proposals         | mapping(bytes28 => struct Financing.Proposal) | 2    | 0      | 32    | src/adapters/Financing.sol:Financing |
    //+-------------------+-----------------------------------------------+------+--------+-------+--------------------------------------+
    //
    // Respect order !
    //
    using Counters for Counters.Counter;

    struct Proposal {
        address applicant; // the proposal applicant address
        uint256 amount; // the amount requested for funding
    }

    bool private _paused;

    Counters.Counter private _ongoingProposals;

    mapping(bytes28 => Proposal) private proposals; // slot 2

    // END COPY VARS

    function getProposal(bytes28 index) public view returns (Proposal memory) {
        return proposals[index];
    }

    function getOngoingProposals() public view returns (uint256) {
        return _ongoingProposals.current();
    }

    /*
    function setProposal(bytes28 index, Proposal memory _proposal) public {
        Proposal storage proposal = proposals[index];
        proposal.applicant = _proposal.applicant;
        proposal.amount = _proposal.amount;
    }
    */
}

contract Financing_test is BaseDaoTest {
    using stdStorage for StdStorage;
    using Slot for bytes28;

    IDaoCore public core;
    IERC20 public token;
    IBank public bank;
    IAgora public agora;

    Financing public financing;

    FinancingSlots financingSlots;

    address public constant TOKEN_ADDRESS = address(0xee);
    address public constant CORE = address(0xff);
    address public constant AGORA = address(uint160(uint32(Slot.AGORA)));
    address public constant BANK = address(uint160(uint32(Slot.BANK)));

    address public constant NOT_ADMIN = address(0x0b);
    address public constant PROPOSER = address(0x0c);
    address public constant NOT_PROPOSER = address(0x0d);
    address public constant APPLICANT = address(0x0e);
    address public constant NOT_RIGHT_ADAPTER = address(0x0f);
    address public constant MEMBER = address(0x1a);
    address public constant NOT_MEMBER = address(0x1b);

    bytes32 public constant PROPOSAL = keccak256("a proposal");
    bytes32 public constant ANOTHER_PROPOSAL = keccak256("another proposal");

    uint256 public constant AMOUNT = 10**20;

    function setUp() public {
        // Set contracts with revert calls by default
        // Calls will not revert if they are mocked
        token = ERC20_reverts(TOKEN_ADDRESS);
        core = Core_reverts(CORE);
        bank = Bank_reverts(BANK);
        agora = Agora_reverts(AGORA);
        ADMIN = address(0x0a);
        ///////////

        financing = new Financing(address(core));

        financingSlots = new FinancingSlots();

        // Core mocks
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.AGORA),
            abi.encode(AGORA)
        );
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.BANK),
            abi.encode(BANK)
        );

        // Bank mocks
        vm.mockCall(
            address(bank),
            abi.encodeWithSelector(bank.terraBioToken.selector),
            abi.encode(TOKEN_ADDRESS)
        );
        vm.mockCall(
            address(bank),
            abi.encodeWithSelector(bank.vaultCommit.selector),
            abi.encode(true) // useless for setter
        );
        vm.mockCall(
            address(bank),
            abi.encodeWithSelector(bank.vaultTransfer.selector),
            abi.encode(true) // useless for setter
        );

        // Agora mocks
        vm.mockCall(
            address(agora),
            abi.encodeWithSelector(agora.submitProposal.selector),
            abi.encode(true) // useless for setter
        );
    }

    function calculateSlotForProposals(bytes28 index) public pure returns (bytes32) {
        // mapping(bytes28 => Proposal) public proposals;  @slot 2
        // pattern
        return keccak256(abi.encode(bytes28(index), 2));
    }

    function calculateSlotForOngoingProposals() public pure returns (bytes32) {
        // struct Counters.Counter private _ongoingProposals;  @slot 1
        // pattern
        return bytes32(uint256(1));
    }

    // Test slot pattern
    //
    // If some variables have not getters
    // First create FinancingSlots contract to retrieve slot with stdstore or vm.accesses
    // and test if retrieved and calculated are equals
    function testSlotsForProposals(bytes28 index) public {
        vm.record();
        //////////////////////
        // mapping(bytes28 => Proposal) private proposals;

        // with getter
        financingSlots.getProposal(index);

        bytes32[] memory lastReadSlots = getLastReadSlots(address(financingSlots));
        assertEq(lastReadSlots.length, 2); // two values expected
        assertLt(uint256(lastReadSlots[0]), uint256(lastReadSlots[1]));
        assertEq(uint256(lastReadSlots[0]) + 1, uint256(lastReadSlots[1]));

        /* can do the same with setter
        financingSlots.setProposal(index, FinancingSlots.Proposal(address(0), 0));

        bytes32[] memory lastWrittenSlots = getLastWrittenSlots(address(financingSlots));
        assertEq(lastWrittenSlots.length, 2); // one value expected
        assertLt(uint256(lastWrittenSlots[0]), uint256(lastWrittenSlots[1]));
        */
        /* with Foundry StdStorage
        // Doesn't work !?
        uint256 retrievedSlot = stdstore
        .target(address(financingSlots))
        .sig("getProposal(bytes28)")
        .with_key(index)
        .find();
        */

        bytes32 calculatedSlot = calculateSlotForProposals(index);

        assertEq(lastReadSlots[0], calculatedSlot);
    }

    function testSlotsForOngoingProposals() public {
        vm.record();

        //////////////////////
        // struct Counters.Counter private _ongoingProposals;

        // with getter
        financingSlots.getOngoingProposals();

        bytes32[] memory lastReadSlots = getLastReadSlots(address(financingSlots));
        assertEq(lastReadSlots.length, 1); // one value expected
        assertEq(lastReadSlots[0], calculateSlotForOngoingProposals());
    }

    function testSubmitProposal_onlyProposer_revert() public {
        // Setup
        ///////////
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, NOT_PROPOSER, ROLE_PROPOSER),
            abi.encode(false)
        );
        Financing.TransactionRequest memory proposal = Financing.TransactionRequest(
            APPLICANT,
            AMOUNT,
            TREASURY,
            TOKEN_ADDRESS
        );
        vm.prank(NOT_PROPOSER);
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, NOT_PROPOSER, ROLE_PROPOSER)
        );
        vm.expectRevert("Adapter: not a proposer");
        financing.submitTransactionRequest(
            TREASURY,
            proposal.amount,
            proposal.applicant,
            TREASURY,
            TOKEN_ADDRESS,
            0
        );
    }

    function testSubmitProposal_amount_revert() public {
        // Setup
        ///////////
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, ROLE_PROPOSER),
            abi.encode(true)
        );
        Financing.TransactionRequest memory proposal = Financing.TransactionRequest(
            APPLICANT,
            0,
            TREASURY,
            TOKEN_ADDRESS
        );
        vm.prank(PROPOSER);
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, ROLE_PROPOSER)
        );

        vm.expectRevert("Financing: invalid requested amount");
        financing.submitTransactionRequest(
            TREASURY,
            proposal.amount,
            proposal.applicant,
            TREASURY,
            TOKEN_ADDRESS,
            0
        );
    }

    function testSubmitProposal() public {
        // Setup
        ///////////
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, ROLE_PROPOSER),
            abi.encode(true)
        );
        Financing.TransactionRequest memory proposal = Financing.TransactionRequest(
            APPLICANT,
            AMOUNT,
            TREASURY,
            TOKEN_ADDRESS
        );
        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));

        ///////////////////////
        // Expected calls
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, ROLE_PROPOSER)
        );
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.AGORA)
        );
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.BANK)
        );
        // vm.expectCall(
        //     address(core),
        //     abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.AGORA)
        // );
        // vm.expectCall(
        //     address(core),
        //     abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.BANK)
        // );
        vm.expectCall(
            address(bank),
            abi.encodeWithSelector(
                bank.vaultCommit.selector,
                TREASURY,
                TOKEN_ADDRESS,
                uint128(proposal.amount)
            )
        );
        vm.expectCall(
            address(agora),
            abi.encodeWithSelector(
                agora.submitProposal.selector,
                Slot.FINANCING,
                proposalId,
                true,
                VOTE_STANDARD,
                0,
                PROPOSER
            )
        );
        ///////////////////////

        vm.prank(PROPOSER);
        financing.submitTransactionRequest(
            VOTE_STANDARD,
            proposal.amount,
            proposal.applicant,
            TREASURY,
            TOKEN_ADDRESS,
            0
        );

        // check value with calculated slot
        bytes32 slot = calculateSlotForProposals(proposalId);

        assertEq(uint256(vm.load(address(financing), slot)), uint256(uint160(APPLICANT)));
        assertEq(uint256(vm.load(address(financing), bytes32(uint256(slot) + 1))), AMOUNT);
    }

    function testCreateVault_onlyAdmin_revert() public {
        // Setup
        ///////////
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, NOT_ADMIN, ROLE_ADMIN),
            abi.encode(false)
        );

        bytes4 vaultId = bytes4(keccak256("a vault"));
        address[] memory tokenList = new address[](1);
        tokenList[0] = TOKEN_ADDRESS;

        vm.prank(NOT_ADMIN);
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, NOT_ADMIN, ROLE_ADMIN)
        );
        vm.expectRevert("Adapter: not an admin");
        financing.createVault(vaultId, tokenList);
    }

    function testCreateVault() public {
        // Setup
        ///////////
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, ADMIN, ROLE_ADMIN),
            abi.encode(true)
        );

        bytes4 vaultId = bytes4(keccak256("a vault"));
        address[] memory tokenList = new address[](1);
        tokenList[0] = TOKEN_ADDRESS;

        vm.mockCall(
            address(bank),
            abi.encodeWithSelector(bank.createVault.selector, vaultId, tokenList),
            abi.encode(false) // useless
        );

        vm.prank(ADMIN);
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, ADMIN, ROLE_ADMIN)
        );
        vm.expectCall(
            address(bank),
            abi.encodeWithSelector(bank.createVault.selector, vaultId, tokenList)
        );
        financing.createVault(vaultId, tokenList);
    }

    function setUpFinalizeProposal() public {
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, ROLE_PROPOSER),
            abi.encode(true)
        );

        vm.prank(PROPOSER);
        financing.submitTransactionRequest(
            VOTE_STANDARD,
            AMOUNT,
            APPLICANT,
            TREASURY,
            TOKEN_ADDRESS,
            0
        );
    }

    function testFinalizeProposal_onlyMember_revert() public {
        // Setup
        setUpFinalizeProposal();
        ///////////

        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, NOT_MEMBER, ROLE_MEMBER),
            abi.encode(false)
        );

        bytes32 coreProposalId = keccak256("A proposal with full pattern");

        vm.prank(NOT_MEMBER);
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, NOT_MEMBER, ROLE_MEMBER)
        );
        vm.expectRevert("Adapter: not a member");
        financing.finalizeProposal(coreProposalId);
    }

    function testFinalizeProposal_notToFinalize_revert(uint8 status) public {
        // Is possible with 'IAgora.ProposalStatus status' ?
        vm.assume(status <= 7 && status != uint8(IAgora.ProposalStatus.TO_FINALIZE));

        // Setup
        setUpFinalizeProposal();
        ///////////

        bytes32 coreProposalId = keccak256("A proposal with full pattern");

        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, MEMBER, ROLE_MEMBER),
            abi.encode(true)
        );
        vm.mockCall(
            address(agora),
            abi.encodeWithSelector(agora.getProposalStatus.selector, coreProposalId),
            abi.encode(status)
        );

        vm.prank(MEMBER);
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, MEMBER, ROLE_MEMBER)
        );
        vm.expectCall(
            address(agora),
            abi.encodeWithSelector(agora.getProposalStatus.selector, coreProposalId)
        );
        vm.expectRevert("Financing: proposal cannot be finalized");
        financing.finalizeProposal(coreProposalId);
    }

    function testFinalizeProposal_without_execution() public {
        ///////////////////////
        // Setup
        setUpFinalizeProposal();

        ///////////////////////
        // Initial state
        Financing.TransactionRequest memory proposal = Financing.TransactionRequest(
            APPLICANT,
            AMOUNT,
            TREASURY,
            TOKEN_ADDRESS
        );
        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));
        bytes32 slot = calculateSlotForProposals(proposalId);

        assertEq(uint256(vm.load(address(financing), slot)), uint256(uint160(APPLICANT)));
        assertEq(uint256(vm.load(address(financing), bytes32(uint256(slot) + 1))), AMOUNT);

        slot = calculateSlotForOngoingProposals();
        assertEq(uint256(vm.load(address(financing), slot)), uint256(1));

        bytes32 coreProposalId = proposalId.concatWithSlot(Slot.FINANCING);

        ///////////////////////
        // Mocked calls
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, MEMBER, ROLE_MEMBER),
            abi.encode(true)
        );
        vm.mockCall(
            address(agora),
            abi.encodeWithSelector(agora.getProposalStatus.selector, coreProposalId),
            abi.encode(IAgora.ProposalStatus.TO_FINALIZE)
        );
        IAgora.VoteResult voteResult = IAgora.VoteResult.REJECTED;
        vm.mockCall(
            address(agora),
            abi.encodeWithSelector(agora.getVoteResult.selector, coreProposalId),
            abi.encode(voteResult)
        );
        vm.mockCall(
            address(agora),
            abi.encodeWithSelector(
                agora.finalizeProposal.selector,
                coreProposalId,
                MEMBER,
                voteResult
            ),
            abi.encode("")
        );

        ///////////////////////
        // Expected calls
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, MEMBER, ROLE_MEMBER)
        );
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.AGORA)
        );

        vm.expectCall(
            address(agora),
            abi.encodeWithSelector(agora.getProposalStatus.selector, coreProposalId)
        );
        vm.expectCall(
            address(agora),
            abi.encodeWithSelector(agora.getVoteResult.selector, coreProposalId)
        );
        vm.expectCall(
            address(agora),
            abi.encodeWithSelector(
                agora.finalizeProposal.selector,
                coreProposalId,
                MEMBER,
                voteResult
            )
        );
        ///////////////////////

        vm.prank(MEMBER);
        financing.finalizeProposal(coreProposalId);

        ///////////////////////
        // check state values with calculated slot
        slot = calculateSlotForProposals(proposalId);
        assertEq(uint256(vm.load(address(financing), slot)), uint256(0));
        assertEq(uint256(vm.load(address(financing), bytes32(uint256(slot) + 1))), uint256(0));

        slot = calculateSlotForOngoingProposals();
        assertEq(uint256(vm.load(address(financing), slot)), uint256(1));
    }

    function testFinalizeProposal_with_execution() public {
        ///////////////////////
        // Setup
        setUpFinalizeProposal();

        ///////////////////////
        // Initial state
        Financing.TransactionRequest memory proposal = Financing.TransactionRequest(
            APPLICANT,
            AMOUNT,
            TREASURY,
            TOKEN_ADDRESS
        );
        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));
        bytes32 slot = calculateSlotForProposals(proposalId);

        assertEq(uint256(vm.load(address(financing), slot)), uint256(uint160(APPLICANT)));
        assertEq(uint256(vm.load(address(financing), bytes32(uint256(slot) + 1))), AMOUNT);

        bytes32 coreProposalId = proposalId.concatWithSlot(Slot.FINANCING);

        ///////////////////////
        // Mocked calls
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, MEMBER, ROLE_MEMBER),
            abi.encode(true)
        );
        vm.mockCall(
            address(agora),
            abi.encodeWithSelector(agora.getProposalStatus.selector, coreProposalId),
            abi.encode(IAgora.ProposalStatus.TO_FINALIZE)
        );
        IAgora.VoteResult voteResult = IAgora.VoteResult.ACCEPTED;
        vm.mockCall(
            address(agora),
            abi.encodeWithSelector(agora.getVoteResult.selector, coreProposalId),
            abi.encode(voteResult)
        );
        vm.mockCall(
            address(agora),
            abi.encodeWithSelector(
                agora.finalizeProposal.selector,
                coreProposalId,
                MEMBER,
                voteResult
            ),
            abi.encode("")
        );

        ///////////////////////
        // Expected calls
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, MEMBER, ROLE_MEMBER)
        );
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.getSlotContractAddr.selector, Slot.AGORA)
        );

        vm.expectCall(
            address(agora),
            abi.encodeWithSelector(agora.getProposalStatus.selector, coreProposalId)
        );
        vm.expectCall(
            address(agora),
            abi.encodeWithSelector(agora.getVoteResult.selector, coreProposalId)
        );
        vm.expectCall(
            address(agora),
            abi.encodeWithSelector(
                agora.finalizeProposal.selector,
                coreProposalId,
                MEMBER,
                voteResult
            )
        );
        vm.expectCall(address(bank), abi.encodeWithSelector(bank.vaultTransfer.selector));
        ///////////////////////

        vm.prank(MEMBER);
        financing.finalizeProposal(coreProposalId);

        ///////////////////////
        // check state values with calculated slot
        slot = calculateSlotForProposals(proposalId);
        assertEq(uint256(vm.load(address(financing), slot)), uint256(0));
        assertEq(uint256(vm.load(address(financing), bytes32(uint256(slot) + 1))), uint256(0));

        slot = calculateSlotForOngoingProposals();
        assertEq(uint256(vm.load(address(financing), slot)), uint256(0));
    }
}
