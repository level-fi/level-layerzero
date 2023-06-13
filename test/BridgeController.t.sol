// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import {TransparentUpgradeableProxy as Proxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin/proxy/transparent/ProxyAdmin.sol";
import {IERC20} from "openzeppelin/interfaces/IERC20.sol";
import {LayerZeroEndpoint} from "./mocks/LayerZeroEndpoint.t.sol";
import {C2LevelToken} from "../src/tokens/C2LevelToken.sol";
import {LevelToken} from "../src/mocks/LevelToken.sol";
import {BridgeProxy} from "../src/bridge/BridgeProxy.sol";
import {BridgeController} from "../src/bridge/BridgeController.sol";
import {C2BridgeController} from "../src/bridge/C2BridgeController.sol";

contract BridgeControllerUpgradableTest is Test {
    event Initialized(uint8);

    function test_init_bridge_controller() external {
        address localEndPoint = address(bytes20("localEndpoint"));
        address localToken = address(bytes20("localToken"));
        address proxyAdmin = address(bytes20("proxyAdmin"));

        Proxy _localProxy = new Proxy(address(new BridgeProxy()), proxyAdmin, new bytes(0));
        BridgeProxy localProxy = BridgeProxy(address(_localProxy));

        Proxy _localController = new Proxy(address(new BridgeController()), proxyAdmin, new bytes(0));
        BridgeController localController = BridgeController(address(_localController));

        vm.expectRevert();
        localController.initialize(address(0), address(localProxy));

        vm.expectRevert();
        localController.initialize(address(localToken), address(0));

        vm.expectEmit(address(localController));
        emit Initialized(1);
        localController.initialize(address(localToken), address(localProxy));

        vm.expectRevert();
        localProxy.initialize(address(0), address(localEndPoint));

        vm.expectRevert();
        localProxy.initialize(address(localController), address(0));

        vm.expectEmit(address(localProxy));
        emit Initialized(1);
        localProxy.initialize(address(localController), address(localEndPoint));
    }

    function test_init_c2_bridge_controller() external {
        address localEndPoint = address(bytes20("localEndpoint"));
        address localToken = address(bytes20("localToken"));
        address proxyAdmin = address(bytes20("proxyAdmin"));

        Proxy _localProxy = new Proxy(address(new BridgeProxy()), proxyAdmin, new bytes(0));
        BridgeProxy localProxy = BridgeProxy(address(_localProxy));

        Proxy _localController = new Proxy(address(new C2BridgeController()), proxyAdmin, new bytes(0));
        C2BridgeController localController = C2BridgeController(address(_localController));

        vm.expectRevert();
        localController.initialize(address(0), address(localProxy));

        vm.expectRevert();
        localController.initialize(address(localToken), address(0));

        vm.expectEmit(address(localController));
        emit Initialized(1);
        localController.initialize(address(localToken), address(localProxy));

        vm.expectRevert();
        localProxy.initialize(address(0), address(localEndPoint));

        vm.expectRevert();
        localProxy.initialize(address(localController), address(0));

        vm.expectEmit(address(localProxy));
        emit Initialized(1);
        localProxy.initialize(address(localController), address(localEndPoint));
    }
}

contract BridgeControllerTest is Test {
    uint16 constant LOCAL_CHAIN_ID = 10102;
    uint16 constant REMOTE_CHAIN_ID = 10106;
    address constant ZERO_ADDR = 0x0000000000000000000000000000000000000000;

    address owner = address(uint160(uint256(keccak256("leveloper"))));
    address user1 = address(uint160(uint256(keccak256("user1"))));
    address user2 = address(uint160(uint256(keccak256("user2"))));
    address validator = address(uint160(uint256(keccak256("validator"))));

    LayerZeroEndpoint localEndPoint;
    LayerZeroEndpoint remoteEndPoint;

    LevelToken localToken;
    BridgeProxy localProxy;
    BridgeController localController;

    // remote
    C2LevelToken remoteToken;
    BridgeProxy remoteProxy;
    C2BridgeController remoteController;

    address proxyAdmin = address(new ProxyAdmin());

    function _deployLocalChain() internal {
        Proxy _localProxy = new Proxy(address(new BridgeProxy()), proxyAdmin, new bytes(0));
        localProxy = BridgeProxy(address(_localProxy));

        Proxy _localController = new Proxy(address(new BridgeController()), proxyAdmin, new bytes(0));
        localController = BridgeController(address(_localController));

        localController.initialize(address(localToken), address(localProxy));
        localProxy.initialize(address(localController), address(localEndPoint));

        localController.setValidator(validator);
    }

    function _deployRemoteChain() internal {
        Proxy _remoteProxy = new Proxy(address(new BridgeProxy()), proxyAdmin, new bytes(0));
        remoteProxy = BridgeProxy(address(_remoteProxy));

        Proxy _remoteController = new Proxy(address(new C2BridgeController()), proxyAdmin, new bytes(0));
        remoteController = C2BridgeController(address(_remoteController));

        remoteController.initialize(address(remoteToken), address(remoteProxy));
        remoteProxy.initialize(address(remoteController), address(remoteEndPoint));

        remoteController.setValidator(validator);
    }

    function setUp() public {
        vm.startPrank(owner);

        // setup mock endpoint
        localEndPoint = new LayerZeroEndpoint(LOCAL_CHAIN_ID);
        remoteEndPoint = new LayerZeroEndpoint(REMOTE_CHAIN_ID);

        // deploy tokens
        localToken = new LevelToken();
        Proxy _remoteToken = new Proxy(address(new C2LevelToken()), proxyAdmin, new bytes(0));
        remoteToken = C2LevelToken(address(_remoteToken));

        _deployLocalChain();
        _deployRemoteChain();
        remoteToken.initialize(address(remoteController));

        // wire up bridge
        localProxy.setTrustedRemoteAddress(REMOTE_CHAIN_ID, abi.encodePacked(address(remoteProxy)));
        remoteProxy.setTrustedRemoteAddress(LOCAL_CHAIN_ID, abi.encodePacked(address(localProxy)));
        localEndPoint.setDestLzEndpoint(address(remoteProxy), address(remoteEndPoint));
        remoteEndPoint.setDestLzEndpoint(address(localProxy), address(localEndPoint));

        vm.stopPrank();

        // deal some gas
        vm.deal(user1, 10 ether);
        vm.deal(user1, 10 ether);
    }

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function test_user_can_init_bridge_from_local() public {
        uint256 amount = 10 ether;
        deal(address(localToken), user1, amount);
        (uint256 fee,) = localController.estimateSendTokensFee(REMOTE_CHAIN_ID, user2, 10 ether);

        uint256 user_balance_before = localToken.balanceOf(user1);

        vm.startPrank(user1);
        localToken.approve(address(localController), amount);

        vm.expectEmit(address(localToken));
        emit Transfer(user1, address(localController), amount);
        localController.bridge{value: fee}(REMOTE_CHAIN_ID, user2, 10 ether);
        vm.stopPrank();

        assertEq(localToken.balanceOf(user1) + amount, user_balance_before);
        // expect message added with nonce 1
        {
            (uint256 debitAmount, address debitTo) = localController.debitInfo(REMOTE_CHAIN_ID, address(localProxy), 1);
            assertEq(debitAmount, amount);
            assertEq(debitTo, user2);
        }

        // since mock endpoint short circuit to receive proxy, we will check for delivered message here
        {
            bytes memory msgPath = abi.encodePacked(address(localProxy), address(remoteProxy));
            (uint256 creditAmount, address to, bool approved) = remoteController.creditQueue(LOCAL_CHAIN_ID, msgPath, 1);
            assertEq(creditAmount, amount);
            assertEq(to, user2);
            assertFalse(approved);
        }
    }

    /// @notice remote chain use C2BridgeController which use mint/burn token instead of lock/unlock
    function test_user_can_init_bridge_from_remote_chain() public {
        uint256 amount = 10 ether;
        deal(address(remoteToken), user1, amount);
        (uint256 fee,) = remoteController.estimateSendTokensFee(LOCAL_CHAIN_ID, user1, 10 ether);

        uint256 user_balance_before = remoteToken.balanceOf(user1);

        vm.startPrank(user1);
        remoteToken.approve(address(remoteController), amount);
        vm.expectEmit(address(remoteToken));
        emit Transfer(user1, address(0), amount);
        remoteController.bridge{value: fee}(LOCAL_CHAIN_ID, user2, 10 ether);
        vm.stopPrank();

        assertEq(remoteToken.balanceOf(user1) + amount, user_balance_before);
        // expect message added with nonce 1
        {
            (uint256 debitAmount, address debitTo) = remoteController.debitInfo(LOCAL_CHAIN_ID, address(remoteProxy), 1);
            assertEq(debitAmount, amount);
            assertEq(debitTo, user2);
        }

        // since mock endpoint short circuit to receive proxy, we will check for delivered message here
        {
            bytes memory msgPath = abi.encodePacked(address(remoteProxy), address(localProxy));
            (uint256 creditAmount, address to, bool approved) = localController.creditQueue(REMOTE_CHAIN_ID, msgPath, 1);
            assertEq(creditAmount, amount);
            assertEq(to, user2);
            assertFalse(approved);
        }
    }

    function test_user_cannot_bridge_with_fee_to_low() external {
        uint256 amount = 10 ether;
        deal(address(localToken), user1, amount * 3);
        (uint256 feeWithoutValidatorFee,) = localController.estimateSendTokensFee(REMOTE_CHAIN_ID, user2, amount);

        vm.startPrank(user1);
        localToken.approve(address(localController), type(uint256).max);

        vm.expectRevert(bytes("LayerZeroMock: not enough native for fees"));
        localController.bridge{value: feeWithoutValidatorFee / 2}(REMOTE_CHAIN_ID, user2, amount);

        localController.bridge{value: feeWithoutValidatorFee}(REMOTE_CHAIN_ID, user2, amount);
        vm.stopPrank();
    }

    function test_validator_should_take_validator_fee() external {
        uint256 amount = 10 ether;
        deal(address(localToken), user1, amount * 3);
        vm.prank(user1);
        localToken.approve(address(localController), type(uint256).max);

        (uint256 feeWithoutValidatorFee,) = localController.estimateSendTokensFee(REMOTE_CHAIN_ID, user2, amount);
        // with validator fee > 0;
        vm.prank(owner);
        uint256 validatorFee = 0.001 ether;
        localController.setValidatorFee(0.001 ether);
        vm.prank(user1);
        vm.expectRevert(bytes("LayerZeroMock: not enough native for fees"));
        localController.bridge{value: feeWithoutValidatorFee}(REMOTE_CHAIN_ID, user2, amount);

        uint256 validator_balance_before = validator.balance;
        (uint256 fee,) = localController.estimateSendTokensFee(REMOTE_CHAIN_ID, user2, 100 ether);
        vm.prank(user1);
        localController.bridge{value: fee}(REMOTE_CHAIN_ID, user2, amount);
        assertEq(validator.balance, validator_balance_before + validatorFee);
    }

    function test_validator_can_approve_transfer_on_remote_chain() external {
        test_user_can_init_bridge_from_local();

        vm.prank(user2);
        vm.expectRevert(bytes("!Validator"));
        bytes memory msgPath = abi.encodePacked(address(localProxy), address(remoteProxy));
        remoteController.approveTransfer(LOCAL_CHAIN_ID, msgPath, 1, user2, 10 ether);

        // wrong amount
        vm.prank(validator);
        vm.expectRevert(bytes("Not exists"));
        remoteController.approveTransfer(LOCAL_CHAIN_ID, msgPath, 1, user2, 11 ether);

        // wrong nonce
        vm.prank(validator);
        vm.expectRevert(bytes("Not exists"));
        remoteController.approveTransfer(LOCAL_CHAIN_ID, msgPath, 2, user2, 10 ether);

        // wrong recipient
        vm.prank(validator);
        vm.expectRevert(bytes("Not exists"));
        remoteController.approveTransfer(LOCAL_CHAIN_ID, msgPath, 2, address(bytes20("joe")), 10 ether);

        // pass
        uint256 prior_recipient_balance = remoteToken.balanceOf(user2);
        vm.prank(validator);
        remoteController.approveTransfer(LOCAL_CHAIN_ID, msgPath, 1, user2, 10 ether);
        assertEq(remoteToken.balanceOf(user2), prior_recipient_balance + 10 ether);

        // repeated approve
        vm.prank(validator);
        vm.expectRevert(bytes("Not exists"));
        remoteController.approveTransfer(LOCAL_CHAIN_ID, msgPath, 1, user2, 10 ether);
    }

    function test_validator_can_approve_transfer_on_local_chain() external {
        test_user_can_init_bridge_from_remote_chain();
        // we deal remote token from air to user1, so we need to airdrop some to controller too
        deal(address(localToken), address(localController), 10 ether);

        vm.prank(user2);
        vm.expectRevert(bytes("!Validator"));
        bytes memory msgPath = abi.encodePacked(address(remoteProxy), address(localProxy));
        localController.approveTransfer(REMOTE_CHAIN_ID, msgPath, 1, user2, 10 ether);

        // wrong amount
        vm.prank(validator);
        vm.expectRevert(bytes("Not exists"));
        localController.approveTransfer(REMOTE_CHAIN_ID, msgPath, 1, user2, 11 ether);

        // wrong nonce
        vm.prank(validator);
        vm.expectRevert(bytes("Not exists"));
        localController.approveTransfer(REMOTE_CHAIN_ID, msgPath, 2, user2, 10 ether);

        // wrong recipient
        vm.prank(validator);
        vm.expectRevert(bytes("Not exists"));
        localController.approveTransfer(REMOTE_CHAIN_ID, msgPath, 2, address(bytes20("joe")), 10 ether);

        // pass
        uint256 prior_recipient_balance = localToken.balanceOf(user2);
        vm.prank(validator);
        localController.approveTransfer(REMOTE_CHAIN_ID, msgPath, 1, user2, 10 ether);
        assertEq(localToken.balanceOf(user2), prior_recipient_balance + 10 ether);

        // repeated approve
        vm.prank(validator);
        vm.expectRevert(bytes("Not exists"));
        localController.approveTransfer(REMOTE_CHAIN_ID, msgPath, 1, user2, 10 ether);
    }

    event ValidatorSet(address);

    function test_only_owner_can_set_validator() external {
        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        localController.setValidator(user1);

        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        remoteController.setValidator(user1);

        vm.prank(owner);
        vm.expectEmit(address(localController));
        emit ValidatorSet(user1);
        localController.setValidator(user1);
    }

    event ValidatorFeeSet(uint256);

    function test_only_owner_can_set_validator_fee() external {
        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        localController.setValidatorFee(0.001 ether);

        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        localController.setValidatorFee(0.001 ether);

        vm.prank(owner);
        vm.expectRevert("> MAX_VALIDATOR_FEE");
        localController.setValidatorFee(1 ether);

        vm.prank(owner);
        vm.expectEmit(address(localController));
        emit ValidatorFeeSet(0.001 ether);
        localController.setValidatorFee(0.001 ether);
    }

    event Paused(address sender);
    event Unpaused(address sender);

    function test_only_owner_can_pause_on_remote_chain() external {
        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        remoteController.pauseSendTokens();

        vm.prank(owner);
        vm.expectEmit(address(remoteController));
        emit Paused(owner);
        remoteController.pauseSendTokens();

        vm.startPrank(user1);
        vm.expectRevert(bytes("Pausable: paused"));
        remoteController.bridge{value: 0.01 ether}(LOCAL_CHAIN_ID, user2, 10 ether);
    }

    function test_only_owner_can_pause_on_local_chain() external {
        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        localController.pauseSendTokens();

        vm.prank(owner);
        vm.expectEmit(address(localController));
        emit Paused(owner);
        localController.pauseSendTokens();

        vm.startPrank(user1);
        vm.expectRevert(bytes("Pausable: paused"));
        localController.bridge{value: 0.01 ether}(REMOTE_CHAIN_ID, user2, 10 ether);
    }

    function test_only_owner_can_unpause_on_remote_chain() external {
        vm.prank(owner);
        remoteController.pauseSendTokens();

        vm.prank(user2);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        remoteController.unpauseSendTokens();

        vm.prank(owner);
        vm.expectEmit(address(remoteController));
        emit Unpaused(owner);
        remoteController.unpauseSendTokens();
    }

    function test_only_owner_can_unpause_on_local_chain() external {
        vm.prank(owner);
        localController.pauseSendTokens();

        vm.prank(user2);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        localController.unpauseSendTokens();

        vm.prank(owner);
        vm.expectEmit(address(localController));
        emit Unpaused(owner);
        localController.unpauseSendTokens();
    }
}
