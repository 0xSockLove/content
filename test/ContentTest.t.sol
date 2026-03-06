// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Content} from "../src/Content.sol";

/// @title ContentTest
/// @author 0xSockLove
/// @notice Test suite for Content contract
/// @dev Tests all custom logic plus integration with OpenZeppelin ERC1155 and Ownable
contract ContentTest is Test, ERC1155Holder {
    Content public content;

    string public constant TEST_IPFS_URI = "ipfs://QmTest";

    function setUp() public {
        content = new Content();
    }

    function test_Mint_Success() public {
        uint256 id = content.mint(TEST_IPFS_URI, 100);

        assertEq(id, 1);
        assertEq(content.balanceOf(address(this), 1), 100);
        assertEq(content.uri(1), TEST_IPFS_URI);
    }

    function test_Mint_SequentialIds() public {
        assertEq(content.mint("ipfs://1", 1), 1);
        assertEq(content.mint("ipfs://2", 1), 2);
        assertEq(content.mint("ipfs://3", 1), 3);
    }

    function test_Mint_RevertsIfNotOwner() public {
        vm.prank(address(0xdead));
        vm.expectRevert();
        content.mint(TEST_IPFS_URI, 1);
    }

    function test_Mint_RevertsIfEmptyURI() public {
        vm.expectRevert(Content.EmptyURI.selector);
        content.mint("", 1);
    }

    function test_Mint_RevertsIfZeroAmount() public {
        vm.expectRevert(Content.ZeroAmount.selector);
        content.mint(TEST_IPFS_URI, 0);
    }

    function test_Mint_EmitsMintedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Content.Minted(1, 100, TEST_IPFS_URI);
        content.mint(TEST_IPFS_URI, 100);
    }

    function test_Uri_ReturnsEmptyForNonexistentToken() public view {
        string memory uri = content.uri(999);
        assertEq(uri, "");
    }

    function test_Transfer_Success() public {
        uint256 id = content.mint(TEST_IPFS_URI, 100);

        content.safeTransferFrom(address(this), address(0xdead), id, 50, "");

        assertEq(content.balanceOf(address(this), id), 50);
        assertEq(content.balanceOf(address(0xdead), id), 50);
    }

    function testFuzz_Mint_AnyAmount(uint128 amount) public {
        vm.assume(amount > 0);

        uint256 id = content.mint(TEST_IPFS_URI, amount);

        assertEq(content.balanceOf(address(this), id), amount);
        assertEq(content.uri(id), TEST_IPFS_URI);
    }

    function testFuzz_Mint_AnyURI(string calldata uri) public {
        vm.assume(bytes(uri).length > 0 && bytes(uri).length < 10000);

        uint256 id = content.mint(uri, 1);

        assertEq(content.uri(id), uri);
        assertEq(content.balanceOf(address(this), id), 1);
    }
}
