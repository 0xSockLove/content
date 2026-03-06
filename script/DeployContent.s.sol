// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {Content} from "../src/Content.sol";

/// @title DeployContent
/// @author 0xSockLove
/// @notice Deployment script for Content contract
/// @dev Bytecode for Gnosis Safe's CreateCall: forge inspect Content bytecode
contract DeployContent is Script {
    function run() public returns (Content) {
        vm.startBroadcast();
        Content content = new Content();
        vm.stopBroadcast();

        console.log("Content has now been deployed to:", address(content));

        return content;
    }
}
