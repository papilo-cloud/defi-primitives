// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Diamond pattern: Route to different implementations based on function selector
 */
contract Diamond {
    mapping(bytes4 => address) public facets;

    function addFacet(address facet, bytes4[] memory selectors) external {
        for (uint i = 0; i < selectors.length; i++) {
            facets[selectors[i]] = facet;
        }
    }

    fallback() external payable {
        address facet = facets[msg.sig];
        require(facet != address(0), "Function does not exist");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}