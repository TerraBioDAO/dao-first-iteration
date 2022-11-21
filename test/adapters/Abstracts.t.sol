// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "test/base/BaseDaoTest.sol";
import "src/extensions/Agora.sol";
import "src/interfaces/IAgora.sol";
import "src/abstracts/Adapter.sol";
import "src/abstracts/ProposerAdapter.sol";

contract AdapterImpl is Adapter {
    bytes4 public constant slot = bytes4("a");

    constructor(address core) Adapter(core, slot) {}

    function onlyCoreMock() external view onlyCore returns (bool) {
        return true;
    }

    function onlyExtensionMock(bytes4 slot_) external view onlyExtension(slot_) returns (bool) {
        return true;
    }

    function onlyMemberMock() external onlyMember returns (bool) {
        return true;
    }

    function onlyProposerMock() external onlyProposer returns (bool) {
        return true;
    }

    function onlyAdminMock() external onlyAdmin returns (bool) {
        return true;
    }
}

contract ProposerImpl is ProposerAdapter {
    bytes4 public constant slot = bytes4("b");
    bytes32 public executedProposal;

    constructor(address core) Adapter(core, slot) {}

    function pausedMock() external view paused returns (bool) {
        return true;
    }

    function _executeProposal(bytes32 proposalId) internal override {
        executedProposal = proposalId;
    }

    function newProposal() external returns (bytes32) {
        IAgora(_slotAddress(Slot.AGORA)).submitProposal(
            slot,
            bytes28("a"),
            true,
            bytes4("one"),
            0,
            address(5)
        );
        _newProposal();
        return bytes32(bytes.concat(slot, bytes28("a")));
    }
}

contract Abstracts_test is BaseDaoTest {
    Agora internal agora;
    AdapterImpl internal adapterImpl;
    ProposerImpl internal proposerImpl;
    address internal PROPOSER_IMPL;
    address internal ADAPTER_IMPL;
    address internal AGORA;
    address internal VOTING;

    bytes4 internal constant ONE_SECOND_VOTE = bytes4("one");

    function setUp() public {
        _deployDao(address(501));
        agora = new Agora(DAO);
        AGORA = address(agora);
        _branch(Slot.AGORA, AGORA);
        VOTING = _branchMock(Slot.VOTING, false);

        adapterImpl = new AdapterImpl(DAO);
        ADAPTER_IMPL = address(adapterImpl);
        proposerImpl = new ProposerImpl(DAO);
        PROPOSER_IMPL = address(proposerImpl);

        vm.prank(VOTING);
        agora.changeVoteParams(ONE_SECOND_VOTE, IAgora.Consensus.MEMBER, 1, 0, 10000, 0);
    }

    /* //////////////////////////
            ADAPTERS
    ////////////////////////// */
    function testPassModifiers(address user) public {
        vm.assume(user != ZERO && user != AGORA && user != ADMIN);
        vm.prank(DAO);
        assertTrue(adapterImpl.onlyCoreMock());
        vm.prank(AGORA);
        assertTrue(adapterImpl.onlyExtensionMock(Slot.AGORA));

        vm.prank(ADMIN);
        dao.changeMemberStatus(user, ROLE_MEMBER, true);

        vm.prank(user);
        assertTrue(adapterImpl.onlyMemberMock());

        vm.prank(ADMIN);
        assertTrue(adapterImpl.onlyAdminMock());
    }

    function testCannotPassModifiers() public {
        vm.startPrank(address(777));
        vm.expectRevert("Adapter: not the core");
        adapterImpl.onlyCoreMock();

        vm.expectRevert("Adapter: wrong extension");
        adapterImpl.onlyExtensionMock(Slot.AGORA);

        vm.expectRevert("Adapter: not a member");
        adapterImpl.onlyMemberMock();

        vm.expectRevert("Adapter: not an admin");
        adapterImpl.onlyAdminMock();
    }

    function testEraseAdapter() public {
        vm.deal(ADAPTER_IMPL, 50e18);
        vm.prank(AGORA);
        adapterImpl.eraseAdapter();

        assertEq(ADAPTER_IMPL.balance, 0);
        assertEq(DAO.balance, 50e18);
    }

    function testCannotEraseAdapter() public {
        _branch(adapterImpl.slot(), ADAPTER_IMPL);

        vm.expectRevert("Adapter: unplug from DaoCore");
        vm.prank(AGORA);
        adapterImpl.eraseAdapter();
    }

    /* //////////////////////////
           PROPOSER ADAPTERS
    ////////////////////////// */
    function testPassPaused(bool isPaused) public {
        if (isPaused) {
            vm.prank(ADMIN);
            proposerImpl.pauseAdapter();
            vm.expectRevert("Adapter: paused");
            proposerImpl.pausedMock();
        } else {
            assertTrue(proposerImpl.pausedMock());
        }
    }

    function testCannotNewProposal() public {
        _branch(proposerImpl.slot(), PROPOSER_IMPL);
        vm.prank(ADMIN);
        proposerImpl.desactive();

        vm.expectRevert("Proposer: adapter desactived");
        proposerImpl.newProposal();
    }

    function testFinalizeProposal(bool isAccepted) public {
        _branch(proposerImpl.slot(), PROPOSER_IMPL);
        bytes32 proposalId = proposerImpl.newProposal();

        assertEq(proposerImpl.ongoingProposals(), 1);

        if (isAccepted) {
            vm.prank(VOTING);
            agora.submitVote(proposalId, address(5), 50, 0);
        }
        vm.warp(10);

        vm.prank(ADMIN);
        proposerImpl.finalizeProposal(proposalId);

        if (isAccepted) {
            assertEq(proposerImpl.executedProposal(), proposalId);
        } else {
            assertEq(proposerImpl.executedProposal(), bytes32(0));
        }

        assertEq(proposerImpl.archivedProposals(), 1);
        assertEq(proposerImpl.ongoingProposals(), 0);
    }

    function testDesactive() public {
        vm.prank(ADMIN);
        proposerImpl.desactive();

        assertTrue(proposerImpl.isDesactived());
    }

    function testCannotDesactive() public {
        _branch(proposerImpl.slot(), PROPOSER_IMPL);
        proposerImpl.newProposal();
        vm.warp(100);

        vm.prank(ADMIN);
        vm.expectRevert("Proposer: still ongoing proposals");
        proposerImpl.desactive();
    }

    function testDeleteArchive() public {
        _branch(proposerImpl.slot(), PROPOSER_IMPL);
        bytes32 proposalId = proposerImpl.newProposal();
        vm.warp(100);
        vm.prank(ADMIN);
        proposerImpl.finalizeProposal(proposalId);
        assertEq(proposerImpl.archivedProposals(), 1);
        vm.prank(AGORA);
        proposerImpl.deleteArchive(bytes32(0));
        assertEq(proposerImpl.archivedProposals(), 0);
    }

    function testEraseProposerAdapter() public {
        vm.deal(PROPOSER_IMPL, 50e18);
        vm.prank(ADMIN);
        proposerImpl.desactive();
        vm.prank(AGORA);
        proposerImpl.eraseAdapter();

        assertEq(PROPOSER_IMPL.balance, 0);
        assertEq(DAO.balance, 50e18);
    }

    function testCannotEraseProposerAdapter() public {
        // not desactivated
        vm.prank(AGORA);
        vm.expectRevert("Proposer: cannot erase");
        proposerImpl.eraseAdapter();

        // add archive
        _branch(proposerImpl.slot(), PROPOSER_IMPL);
        bytes32 proposalId = proposerImpl.newProposal();
        vm.warp(100);
        vm.prank(ADMIN);
        proposerImpl.finalizeProposal(proposalId);

        vm.prank(ADMIN);
        proposerImpl.desactive();

        vm.prank(AGORA);
        vm.expectRevert("Proposer: cannot erase");
        proposerImpl.eraseAdapter();

        // remove archive
        vm.prank(AGORA);
        proposerImpl.deleteArchive(bytes32(0));

        vm.expectRevert("Adapter: wrong extension");
        proposerImpl.eraseAdapter();
    }
}
