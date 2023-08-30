import "forge-std/Script.sol";
import {TransparentUpgradeableProxy as Proxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin/proxy/transparent/ProxyAdmin.sol";
import {BridgeProxy} from "../src/bridge/BridgeProxy.sol";
import {BridgeController} from "../src/bridge/BridgeController.sol";

contract Bsc_DeployLvlProxy is Script {
    address LvlToken;
    uint16 bsc_chainId = 102;
    address proxyAdmin;
    address bscL0Endpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;

    function setUp() external {
        proxyAdmin = vm.envAddress("BSC_PROXY_ADMIN");
        LvlToken = vm.envAddress("BSC_LVL");
    }

    function run() external {
        vm.startBroadcast(vm.envUint("BSC_DEPLOYER"));
        // deploy proxy
        BridgeProxy bridgeProxy;
        {
            Proxy proxy = new Proxy(
                address(new BridgeProxy()), 
                proxyAdmin,
                new bytes(0)
            );
            bridgeProxy = BridgeProxy(address(proxy));
        }

        // deploy controller
        BridgeController controller;
        {
            Proxy proxy = new Proxy(
                address(new BridgeController()), 
                proxyAdmin,
                new bytes(0)
            );
            controller = BridgeController(address(proxy));
        }

        bridgeProxy.initialize(address(controller), bscL0Endpoint);
        controller.initialize(LvlToken, address(bridgeProxy));

        vm.stopBroadcast();
    }
}
