// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import {TransparentUpgradeableProxy as Proxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin/proxy/transparent/ProxyAdmin.sol";
import {LayerZeroEndpoint} from "./mocks/LayerZeroEndpoint.sol";
import {C2LevelToken} from "../src/C2LevelToken.sol";
import {LevelToken} from "../src/mocks/LevelToken.sol";
import {BridgeProxy} from "../src/BridgeProxy.sol";
import {BridgePool} from "../src/BridgePool.sol";
import {C2BridgePool} from "../src/C2BridgePool.sol";

contract BridgeTokenTest is Test {
    uint16 constant LOCAL_CHAIN_ID = 10102;
    uint16 constant REMOTE_CHAIN_ID = 10143;
    address constant ZERO_ADDR = address(0);

    address owner;
    address user1 = vm.addr(uint256(keccak256(abi.encodePacked("user1"))));
    address validator = vm.addr(uint256(keccak256(abi.encodePacked("validator"))));
    address controller = vm.addr(uint256(keccak256(abi.encodePacked("controller"))));

    LayerZeroEndpoint localEndPoint;
    LayerZeroEndpoint remoteEndPoint;
    LevelToken localToken;
    BridgeProxy localProxy;
    BridgePool localPool;

    // remote
    C2LevelToken remoteToken;
    BridgeProxy remoteProxy;
    C2BridgePool remotePool;

    function setUp() public {
        owner = msg.sender;
        vm.startPrank(owner);
        address proxyAdmin = address(new ProxyAdmin());

        localEndPoint = new LayerZeroEndpoint(LOCAL_CHAIN_ID);
        remoteEndPoint = new LayerZeroEndpoint(REMOTE_CHAIN_ID);

        localToken = new LevelToken();
        remoteToken = new C2LevelToken();

        console.log("localToken", address(localToken));
        console.log("remoteToken", address(remoteToken));

        Proxy _localProxy = new Proxy(address(new BridgeProxy()), proxyAdmin, new bytes(0));
        localProxy = BridgeProxy(address(_localProxy));

        Proxy _remoteProxy = new Proxy(address(new BridgeProxy()), proxyAdmin, new bytes(0));
        remoteProxy = BridgeProxy(address(_remoteProxy));

        Proxy _localPool = new Proxy(address(new BridgePool()), proxyAdmin, new bytes(0));
        localPool = BridgePool(address(_localPool));

        Proxy _remotePool = new Proxy(address(new C2BridgePool()), proxyAdmin, new bytes(0));
        remotePool = C2BridgePool(address(_remotePool));

        console.log("local Proxy", address(localProxy));
        console.log("remote Proxy", address(remoteProxy));
        console.log("User1", user1);

        /// Initialize

        localPool.initialize(address(localToken), address(localProxy), validator);
        remotePool.initialize(address(remoteToken), address(remoteProxy), validator, controller);

        localProxy.initialize(address(localPool), address(localEndPoint));
        remoteProxy.initialize(address(remotePool), address(remoteEndPoint));

        localProxy.setTrustedRemoteAddress(REMOTE_CHAIN_ID, abi.encodePacked(address(remoteProxy)));
        remoteProxy.setTrustedRemoteAddress(LOCAL_CHAIN_ID, abi.encodePacked(address(localProxy)));

        localEndPoint.setDestLzEndpoint(address(remoteProxy), address(remoteEndPoint));
        remoteEndPoint.setDestLzEndpoint(address(localProxy), address(localEndPoint));
        remoteToken.setBridgePool(address(remotePool));
        vm.stopPrank();
    }

    function testBridge() public {
        vm.warp(1);
        // LOCAL -> REMOTE
        vm.startPrank(owner);
        localToken.transfer(user1, 100_000e18);

        vm.stopPrank();

        vm.deal(user1, 100 ether);
        vm.startPrank(user1);

        (uint256 _nativeFee,) = localPool.estimateSendTokensFee(REMOTE_CHAIN_ID, user1, 100 ether);

        localToken.approve(address(localPool), 100 ether);
        localPool.bridge{value: _nativeFee}(REMOTE_CHAIN_ID, user1, 100 ether);

        vm.stopPrank();

        vm.startPrank(validator);
        (address _to, uint256 _amount) =
            remotePool.creditQueue(LOCAL_CHAIN_ID, abi.encodePacked(address(localProxy), address(remoteProxy)), 1);
        console.log(_to, _amount);
        remotePool.approveTransfer(LOCAL_CHAIN_ID, abi.encodePacked(address(localProxy), address(remoteProxy)), 1);
        assertEq(remoteToken.balanceOf(address(remotePool)), 0);
        assertEq(remoteToken.balanceOf(user1), 100e18);
        assertEq(localToken.balanceOf(address(localPool)), 100e18);

        vm.stopPrank();

        // vm.startPrank(owner);
        // remotePool.pauseSendTokens(true);
        // vm.stopPrank();

        // vm.startPrank(user1);

        // (_nativeFee,) = localPool.estimateSendTokensFee(REMOTE_CHAIN_ID, user1, 100 ether);

        // localToken.approve(address(localPool), 100 ether);
        // localPool.bridge{value: _nativeFee}(REMOTE_CHAIN_ID, user1, 100 ether);

        // vm.stopPrank();

        // REMOTE -> LOCAL
        vm.startPrank(user1);

        (_nativeFee,) = remotePool.estimateSendTokensFee(LOCAL_CHAIN_ID, user1, 100 ether);

        remoteToken.approve(address(remotePool), 100 ether);
        remotePool.bridge{value: _nativeFee}(LOCAL_CHAIN_ID, user1, 100 ether);
        vm.stopPrank();

        vm.startPrank(validator);
        (_to, _amount) =
            localPool.creditQueue(REMOTE_CHAIN_ID, abi.encodePacked(address(remoteProxy), address(localProxy)), 1);
        console.log(_to, _amount);
        localPool.approveTransfer(REMOTE_CHAIN_ID, abi.encodePacked(address(remoteProxy), address(localProxy)), 1);
        assertEq(remoteToken.balanceOf(address(remotePool)), 0);
        assertEq(remoteToken.balanceOf(user1), 0);
        assertEq(localToken.balanceOf(address(localPool)), 0);
        assertEq(localToken.balanceOf(user1), 100_000e18);

        vm.stopPrank();
    }

    function testBurn() public {
        vm.warp(1);
        vm.mockCall(
            address(remotePool), abi.encodeWithSelector(remotePool.MAIN_CHAIN_ID.selector), abi.encode(LOCAL_CHAIN_ID)
        );
        console.log("Main", remotePool.MAIN_CHAIN_ID());
        // LOCAL -> REMOTE
        vm.startPrank(owner);
        localToken.transfer(user1, 100_000e18);

        vm.stopPrank();

        vm.deal(user1, 100 ether);
        vm.deal(controller, 100 ether);
        vm.startPrank(user1);

        (uint256 _nativeFee,) = localPool.estimateSendTokensFee(REMOTE_CHAIN_ID, user1, 100 ether);

        localToken.approve(address(localPool), 100 ether);
        localPool.bridge{value: _nativeFee}(REMOTE_CHAIN_ID, user1, 100 ether);

        vm.stopPrank();

        vm.startPrank(validator);
        (address _to, uint256 _amount) =
            remotePool.creditQueue(LOCAL_CHAIN_ID, abi.encodePacked(address(localProxy), address(remoteProxy)), 1);
        console.log(_to, _amount);
        remotePool.approveTransfer(LOCAL_CHAIN_ID, abi.encodePacked(address(localProxy), address(remoteProxy)), 1);
        assertEq(remoteToken.balanceOf(address(remotePool)), 0);
        assertEq(remoteToken.balanceOf(user1), 100e18);
        assertEq(localToken.balanceOf(address(localPool)), 100e18);

        vm.stopPrank();

        vm.startPrank(user1);
        remoteToken.burn(100e18);

        assertEq(remoteToken.burnDebtAmount(), 100e18);
        vm.stopPrank();

        vm.startPrank(controller);
        (_nativeFee,) = remotePool.estimateBurnFee();
        remotePool.burn{value: _nativeFee}();
        assertEq(remoteToken.burnDebtAmount(), 0);
        vm.stopPrank();

        vm.startPrank(validator);
        localPool.approveBurn(REMOTE_CHAIN_ID, abi.encodePacked(address(remoteProxy), address(localProxy)), 1);
        assertEq(localToken.balanceOf(address(localPool)), 0);
        assertEq(
            localPool.burnQueue(REMOTE_CHAIN_ID, abi.encodePacked(address(remoteProxy), address(localProxy)), 1), 0
        );
        vm.stopPrank();
    }
}
