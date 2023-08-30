pragma solidity 0.8.18;

import "forge-std/Script.sol";

import {TransparentUpgradeableProxy as Proxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {BridgeProxy} from "../src/bridge/BridgeProxy.sol";
import {BridgeController} from "../src/bridge/BridgeController.sol";
import {C2BridgeController} from "../src/bridge/C2BridgeController.sol";
import {C2LevelGovernanceToken} from "../src/tokens/C2LevelGovernanceToken.sol";

library BscAddresses {
    address constant devProxyAdmin = 0x3fF830dbC1CF4dCA3c16203F2F29CE48C2E83CE8;
    address constant l0Endpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
    address constant LGO = 0xBe2B6C5E31F292009f495DDBda88e28391C9815E;
    address constant validator = 0x0068308Fb3c1c1DB1601567B674aF730B3d10374;
}

library ArbAddresses {
    address constant devProxyAdmin = 0xe272BE38919DE58B3803e8e0b219b1aB969A0557;
    address constant l0Endpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
    address constant validator = 0x0068308Fb3c1c1DB1601567B674aF730B3d10374;
}

contract DeployLGOBridge is Script {
    modifier broadcast(string memory key) {
        vm.startBroadcast(vm.envUint(key));
        _;
        vm.stopBroadcast();
    }

    modifier usingFork(string memory name) {
        vm.createSelectFork(vm.rpcUrl(name));
        _;
    }

    function run() external {
        _deployBsc();
        _deployArb();
    }

    function _deployBsc() internal usingFork("bsc") broadcast("BSC_DEPLOYER") {
        BridgeProxy bridgeProxy;
        {
            Proxy proxy = new Proxy(
                address(new BridgeProxy()), 
                BscAddresses.devProxyAdmin,
                new bytes(0)
            );
            bridgeProxy = BridgeProxy(address(proxy));
        }

        // deploy controller
        BridgeController controller;
        {
            Proxy proxy = new Proxy(
                address(new BridgeController()), 
                BscAddresses.devProxyAdmin,
                new bytes(0)
            );
            controller = BridgeController(address(proxy));
        }

        bridgeProxy.initialize(address(controller), BscAddresses.l0Endpoint);
        controller.initialize(BscAddresses.LGO, address(bridgeProxy));
        controller.setValidator(BscAddresses.validator);
        controller.setValidatorFee(1333333333333333);
    }

    function _deployArb() internal usingFork("arbitrum") broadcast("ARB_DEPLOYER") {
        BridgeProxy bridgeProxy;
        {
            Proxy proxy = new Proxy(
                address(new BridgeProxy()),
                ArbAddresses.devProxyAdmin,
                new bytes(0)
            );
            bridgeProxy = BridgeProxy(address(proxy));
        }

        // deploy controller
        C2BridgeController controller;
        {
            Proxy proxy = new Proxy(
                address(new C2BridgeController()),
                ArbAddresses.devProxyAdmin,
                new bytes(0)
            );
            controller = C2BridgeController(address(proxy));
        }

        bridgeProxy.initialize(address(controller), ArbAddresses.l0Endpoint);

        address LGO;
        {
            Proxy proxy = new Proxy(
                address(new C2LevelGovernanceToken()), 
                ArbAddresses.devProxyAdmin,
                abi.encodeWithSelector(C2LevelGovernanceToken.initialize.selector, address(controller))
            );
            LGO = address(proxy);
        }

        controller.initialize(LGO, address(bridgeProxy));
        controller.setValidator(ArbAddresses.validator);
        controller.setValidatorFee(55555555555555);
    }
}
