// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import {TransparentUpgradeableProxy as Proxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin/proxy/transparent/ProxyAdmin.sol";
import {LayerZeroEndpoint} from "./mocks/LayerZeroEndpoint.sol";
import {C2LevelToken} from "../src/C2LevelToken.sol";
import {LevelToken} from "../src/mocks/LevelToken.sol";
import {BridgeProxy} from "../src/BridgeProxy.sol";
import {BridgeController} from "../src/BridgeController.sol";
import {C2BridgeController} from "../src/C2BridgeController.sol";

contract BridgeTokenTest is Test {
    uint16 constant LOCAL_CHAIN_ID = 10102;
    uint16 constant REMOTE_CHAIN_ID = 10143;
    address constant ZERO_ADDR = address(0);

    address owner;
    address user1 = vm.addr(uint256(keccak256(abi.encodePacked("user1"))));
    address validator = vm.addr(uint256(keccak256(abi.encodePacked("validator"))));

    LayerZeroEndpoint localEndPoint;
    LayerZeroEndpoint remoteEndPoint;
    LevelToken localToken;
    BridgeProxy localProxy;
    BridgeController localController;

    // remote
    C2LevelToken remoteToken;
    BridgeProxy remoteProxy;
    C2BridgeController remoteController;

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

        Proxy _localController = new Proxy(address(new BridgeController()), proxyAdmin, new bytes(0));
        localController = BridgeController(address(_localController));

        Proxy _remoteController = new Proxy(address(new C2BridgeController()), proxyAdmin, new bytes(0));
        remoteController = C2BridgeController(address(_remoteController));

        console.log("local Proxy", address(localProxy));
        console.log("remote Proxy", address(remoteProxy));
        console.log("User1", user1);

        /// Initialize

        localController.initialize(address(localToken), address(localProxy), validator);
        remoteController.initialize(address(remoteToken), address(remoteProxy), validator);

        localProxy.initialize(address(localController), address(localEndPoint));
        remoteProxy.initialize(address(remoteController), address(remoteEndPoint));

        localProxy.setTrustedRemoteAddress(REMOTE_CHAIN_ID, abi.encodePacked(address(remoteProxy)));
        remoteProxy.setTrustedRemoteAddress(LOCAL_CHAIN_ID, abi.encodePacked(address(localProxy)));

        localEndPoint.setDestLzEndpoint(address(remoteProxy), address(remoteEndPoint));
        remoteEndPoint.setDestLzEndpoint(address(localProxy), address(localEndPoint));
        remoteToken.setBridgeController(address(remoteController));
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

        (uint256 _nativeFee,) = localController.estimateSendTokensFee(REMOTE_CHAIN_ID, user1, 100 ether);

        localToken.approve(address(localController), 100 ether);
        localController.bridge{value: _nativeFee}(REMOTE_CHAIN_ID, user1, 100 ether);

        vm.stopPrank();

        vm.startPrank(validator);
        (address _to, uint256 _amount) =
            remoteController.creditQueue(LOCAL_CHAIN_ID, abi.encodePacked(address(localProxy), address(remoteProxy)), 1);
        console.log(_to, _amount);
        remoteController.approveTransfer(LOCAL_CHAIN_ID, abi.encodePacked(address(localProxy), address(remoteProxy)), 1);
        assertEq(remoteToken.balanceOf(address(remoteController)), 0);
        assertEq(remoteToken.balanceOf(user1), 100e18);
        assertEq(localToken.balanceOf(address(localController)), 100e18);

        vm.stopPrank();

        // vm.startPrank(owner);
        // remoteController.pauseSendTokens(true);
        // vm.stopPrank();

        // vm.startPrank(user1);

        // (_nativeFee,) = localController.estimateSendTokensFee(REMOTE_CHAIN_ID, user1, 100 ether);

        // localToken.approve(address(localController), 100 ether);
        // localController.bridge{value: _nativeFee}(REMOTE_CHAIN_ID, user1, 100 ether);

        // vm.stopPrank();

        // REMOTE -> LOCAL
        vm.startPrank(user1);

        (_nativeFee,) = remoteController.estimateSendTokensFee(LOCAL_CHAIN_ID, user1, 100 ether);

        remoteToken.approve(address(remoteController), 100 ether);
        remoteController.bridge{value: _nativeFee}(LOCAL_CHAIN_ID, user1, 100 ether);
        vm.stopPrank();

        vm.startPrank(validator);
        (_to, _amount) =
            localController.creditQueue(REMOTE_CHAIN_ID, abi.encodePacked(address(remoteProxy), address(localProxy)), 1);
        console.log(_to, _amount);
        localController.approveTransfer(REMOTE_CHAIN_ID, abi.encodePacked(address(remoteProxy), address(localProxy)), 1);
        assertEq(remoteToken.balanceOf(address(remoteController)), 0);
        assertEq(remoteToken.balanceOf(user1), 0);
        assertEq(localToken.balanceOf(address(localController)), 0);
        assertEq(localToken.balanceOf(user1), 100_000e18);

        vm.stopPrank();
    }
}
