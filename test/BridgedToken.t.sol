import "forge-std/Test.sol";
import {TransparentUpgradeableProxy as Proxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin/proxy/transparent/ProxyAdmin.sol";
import "src/tokens/C2LevelToken.sol";

contract BrigedTokenTest is Test {
    C2LevelToken remoteToken;
    address controller = address(bytes20("c2.controller"));
    address owner = address(bytes20("owner"));
    address eve = address(bytes20("eve"));

    function setUp() external {
        vm.startPrank(owner);
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        Proxy _remoteToken =
            new Proxy(address(new C2LevelToken()), address(proxyAdmin), abi.encodeWithSelector(C2LevelToken.initialize.selector));
        remoteToken = C2LevelToken(address(_remoteToken));
        vm.stopPrank();
    }

    function test_init() external {
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        Proxy _remoteToken =
            new Proxy(address(new C2LevelToken()), address(proxyAdmin), abi.encodeWithSelector(C2LevelToken.initialize.selector));
        C2LevelToken token = C2LevelToken(address(_remoteToken));
        assertEq(token.decimals(), 18);
    }

    event BridgeControllerSet(address);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function test_only_owner_can_set_controller() external {
        vm.prank(eve);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        remoteToken.setBridgeController(controller);

        vm.prank(owner);
        vm.expectEmit(address(remoteToken));
        emit BridgeControllerSet(controller);
        remoteToken.setBridgeController(controller);
    }

    function test_only_minter_can_mint() external {
        vm.prank(owner);
        remoteToken.setBridgeController(controller);

        vm.prank(eve);
        vm.expectRevert(bytes("!minter"));
        remoteToken.mint(address(1), 1 ether);

        vm.prank(controller);
        vm.expectEmit(address(remoteToken));
        emit Transfer(address(0), address(1), 1 ether);
        remoteToken.mint(address(1), 1 ether);
    }

    event Paused(address sender);
    event Unpaused(address sender);

    function test_only_owner_can_pause() external {
        vm.prank(eve);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        remoteToken.pause();

        vm.prank(owner);
        vm.expectEmit(address(remoteToken));
        emit Paused(owner);
        remoteToken.pause();

        vm.prank(owner);
        remoteToken.setBridgeController(controller);

        vm.prank(controller);
        vm.expectRevert(bytes("Pausable: paused"));
        remoteToken.mint(address(1), 1 ether);
    }

    function test_only_owner_can_unpause() external {
        vm.prank(owner);
        remoteToken.pause();

        vm.prank(eve);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        remoteToken.unpause();

        vm.prank(owner);
        vm.expectEmit(address(remoteToken));
        emit Unpaused(owner);
        remoteToken.unpause();
    }

    function test_approved_user_can_burn() external {
        address user1 = address(bytes20("user1"));
        address user2 = address(bytes20("user2"));
        deal(address(remoteToken), user1, 10 ether);

        vm.prank(user1);
        vm.expectEmit(address(remoteToken));
        emit Transfer(address(user1), address(0), 1 ether);
        remoteToken.burn(1 ether);

        vm.prank(user2);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        remoteToken.burnFrom(user1, 1 ether);

        vm.prank(user1);
        remoteToken.approve(user2, 1 ether);
        vm.prank(user2);
        vm.expectEmit(address(remoteToken));
        emit Transfer(address(user1), address(0), 1 ether);
        remoteToken.burnFrom(user1, 1 ether);
    }
}
