// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

//import "openzeppelin-contracts/utils/Counters.sol";
import "test/base/BaseTest.sol";
import "test/reverts/Core_reverts.sol";
import "test/reverts/Bank_reverts.sol";
import "test/reverts/Agora_reverts.sol";
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

    /*
    function setProposal(bytes28 index, Proposal memory _proposal) public {
        Proposal storage proposal = proposals[index];
        proposal.applicant = _proposal.applicant;
        proposal.amount = _proposal.amount;
    }
    */
}

contract Financing_test is BaseTest {
    using stdStorage for StdStorage;

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

    address public constant PROPOSER = address(0x0d);
    address public constant NOT_PROPOSER = address(0x0c);
    address public constant APPLICANT = address(0x0f);
    address public constant NOT_RIGHT_ADAPTER = address(0x0e);

    bytes32 public constant PROPOSAL = keccak256(abi.encode("a proposal"));
    bytes32 public constant ANOTHER_PROPOSAL = keccak256(abi.encode("another proposal"));

    bytes4 public constant VOTE_ID = bytes4(keccak256(abi.encode("vote params")));

    uint256 public constant AMOUNT = 10**20;

    function setUp() public {
        token = ERC20_reverts(TOKEN_ADDRESS);
        core = Core_reverts(CORE);
        bank = Bank_reverts(BANK);
        agora = Agora_reverts(AGORA);

        financing = new Financing(address(core));

        financingSlots = new FinancingSlots();

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

        // submit proposal to Agora
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

    // Test slot pattern
    //
    // If some variables have not getters
    // First create FinancingSlots contract to retrieve slot with stdstore or vm.accesses
    // and test if retrieved and calculated are equals
    function testSlotsPatterns(bytes28 index) public {
        vm.record();
        //
        // mapping(bytes28 => Proposal) public proposals;

        // with getter
        financingSlots.getProposal(index);

        bytes32[] memory lastReadSlots = getLastReadSlots(address(financingSlots));
        assertEq(lastReadSlots.length, 2); // one value expected
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

    function testSubmitProposal_onlyProposer() public {
        // Setup
        ///////////
        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, NOT_PROPOSER, Slot.USER_PROPOSER),
            abi.encode(false)
        );
        Financing.Proposal memory proposal = Financing.Proposal(APPLICANT, AMOUNT);
        vm.prank(NOT_PROPOSER);
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, NOT_PROPOSER, Slot.USER_PROPOSER)
        );
        vm.expectRevert("Adapter: not a proposer");
        financing.submitProposal(Slot.TREASURY, proposal.amount, proposal.applicant);

        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, Slot.USER_PROPOSER),
            abi.encode(true)
        );
        proposal = Financing.Proposal(APPLICANT, 0);
        vm.prank(PROPOSER);
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, Slot.USER_PROPOSER)
        );
        /*vm.expectCall(
            address(bank),
            abi.encodeWithSelector(bank.setFinancingProposalData.selector, PROPOSER, Slot.USER_PROPOSER)
        );*/
        vm.expectRevert("Financing: invalid requested amount");
        financing.submitProposal(Slot.TREASURY, proposal.amount, proposal.applicant);

        vm.mockCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, Slot.USER_PROPOSER),
            abi.encode(true)
        );
        proposal = Financing.Proposal(APPLICANT, AMOUNT);
        bytes28 proposalId = bytes28(keccak256(abi.encode(proposal)));

        vm.prank(PROPOSER);
        console.logBytes4(core.hasRole.selector);
        vm.expectCall(
            address(core),
            abi.encodeWithSelector(core.hasRole.selector, PROPOSER, Slot.USER_PROPOSER)
        );
        console.logBytes4(bank.vaultCommit.selector);
        /*vm.expectCall(
            address(bank),
            abi.encodeWithSelector(
                bank.vaultCommit.selector,
                Slot.TREASURY,
                TOKEN_ADDRESS,
                APPLICANT,
                uint128(proposal.amount)
            )
        );*/
        console.logBytes4(agora.submitProposal.selector);
        /*vm.expectCall(
            address(agora),
            abi.encodeWithSelector(
                agora.submitProposal.selector,
                Slot.TREASURY,
                proposalId,
                true,
                true,
                VOTE_ID,
                0,
                PROPOSER
            )
        );*/
        financing.submitProposal(Slot.TREASURY, proposal.amount, proposal.applicant);

        // check value with calculated slot
        bytes32 slot = calculateSlotForProposals(proposalId);

        assertEq(uint256(vm.load(address(financing), slot)), uint256(uint160(APPLICANT)));
        assertEq(uint256(vm.load(address(financing), bytes32(uint256(slot) + 1))), AMOUNT);
    }
}
