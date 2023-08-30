import "forge-std/Script.sol";
import {
    TransparentUpgradeableProxy as Proxy,
    ITransparentUpgradeableProxy as IProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin/proxy/transparent/ProxyAdmin.sol";
import {BridgeProxy} from "../src/bridge/BridgeProxy.sol";
import {C2BridgeController} from "../src/bridge/C2BridgeController.sol";
import "../src/tokens/C2LevelToken.sol";

contract Empty {}

contract Arb_DeployLvlProxy is Script {
    address LvlToken;
    uint16 arb_chainId = 110;
    address proxyAdmin;
    address bscL0Endpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;

    function setUp() external {
        proxyAdmin = vm.envAddress("ARB_PROXY_ADMIN");
    }

    function run() external {
        vm.startBroadcast(vm.envUint("ARB_DEPLOYER"));
        for (uint256 i = 0; i < 7; i++) {
            new Empty();
        }
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
        C2BridgeController controller;
        {
            Proxy proxy = new Proxy(
                address(new C2BridgeController()),
                proxyAdmin,
                new bytes(0)
            );
            controller = C2BridgeController(address(proxy));
        }

        bridgeProxy.initialize(address(controller), bscL0Endpoint);

        {
            Proxy proxy = new Proxy(
                address(new C2LevelToken()), 
                proxyAdmin,
                abi.encodeWithSelector(C2LevelToken.initialize.selector, address(controller))
            );
            LvlToken = address(proxy);
            // C2LevelToken(LvlToken).initialize();
        }

        console.log(address(msg.sender), address(0x6442b001c5AcCE8cb71986ad65B22684821A927A).balance);
        controller.initialize(LvlToken, address(bridgeProxy));
        controller.setValidator(0x6442b001c5AcCE8cb71986ad65B22684821A927A);

        vm.stopBroadcast();
    }
}
