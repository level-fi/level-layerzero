import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {
    TransparentUpgradeableProxy as Proxy,
    ITransparentUpgradeableProxy as IProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin/proxy/transparent/ProxyAdmin.sol";
import {BridgeController} from "../src/bridge/BridgeController.sol";
import {C2BridgeController} from "../src/bridge/C2BridgeController.sol";

contract BscUpgradeController is Script, Test {
    address proxyAdmin;
    address controller = 0xC0717eb8ad66d0b3BF16Bbe0bAC0fb605a715A35;

    function setUp() external {
        proxyAdmin = vm.envAddress("BSC_PROXY_ADMIN");
    }

    function run() external {
        vm.startBroadcast(vm.envUint("BSC_DEPLOYER"));
        address ownerBefore = BridgeController(controller).owner();
        address bridgeProxyBefore = address(BridgeController(controller).bridgeProxy());

        address newController = 0x6D995cb1D5C2a0D981034e9d5F0Eb325aDCa49c1;

        ProxyAdmin(proxyAdmin).upgrade(IProxy(payable(controller)), address(newController));

        assertEq(ProxyAdmin(proxyAdmin).getProxyAdmin(IProxy(controller)), proxyAdmin);
        assertEq(ownerBefore, BridgeController(controller).owner());
        assertEq(bridgeProxyBefore, address(BridgeController(controller).bridgeProxy()));
        vm.stopBroadcast();
    }
}

contract ArbUpgradeController is Script, Test {
    address proxyAdmin;
    address controller = 0x92a103971f1700B716B828E9FC0392E0ae2Eed14;

    function setUp() external {
        proxyAdmin = vm.envAddress("ARB_PROXY_ADMIN");
    }

    function run() external {
        vm.startBroadcast(vm.envUint("ARB_DEPLOYER"));
        address ownerBefore = C2BridgeController(controller).owner();
        address bridgeProxyBefore = address(BridgeController(controller).bridgeProxy());

        ProxyAdmin(proxyAdmin).upgrade(IProxy(payable(controller)), address(new C2BridgeController()));

        assertEq(ProxyAdmin(proxyAdmin).getProxyAdmin(IProxy(controller)), proxyAdmin);
        assertEq(ownerBefore, C2BridgeController(controller).owner());
        assertEq(bridgeProxyBefore, address(C2BridgeController(controller).bridgeProxy()));
        vm.stopBroadcast();
    }
}
