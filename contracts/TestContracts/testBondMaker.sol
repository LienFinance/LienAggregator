// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;
import "./testBondToken.sol";
import "../utils/TransferETH.sol";

contract TestBaseBondMaker {
    struct BondGroupInfo {
        uint256 maturity;
        bytes32[] bondIDs;
    }
    mapping(uint256 => BondGroupInfo) bondGroups;
    mapping(bytes32 => address) bondToAddress;
    mapping(bytes32 => uint256) BondToGroup;
    mapping(bytes32 => uint256) BondStrikePrice;
    mapping(bytes32 => bytes32) bondIDTofnMapID;
    mapping(bytes32 => bytes) fnMapIDTofnMap;

    uint256 bondIndex = 0;
    uint256 BondGroupNumber = 0;

    event FnMapID(bytes32 fnMapID);

    function resisterFnMap(uint64[] memory points) public returns (bytes32) {
        uint256[] memory lines = zipLines(points);
        bytes memory fnMap = abi.encode(lines);
        bytes32 fnMapID = keccak256(fnMap);
        fnMapIDTofnMap[fnMapID] = fnMap;
        emit FnMapID(fnMapID);
        return fnMapID;
    }

    function zipLines(uint64[] memory points)
        internal
        pure
        returns (uint256[] memory lines)
    {
        lines = new uint256[](points.length / 4);
        for (uint256 i = 0; i < points.length / 4; i++) {
            uint256 x1U256 = uint256(points[4 * i]) << (64 + 64 + 64); // uint64
            uint256 y1U256 = uint256(points[4 * i + 1]) << (64 + 64); // uint64
            uint256 x2U256 = uint256(points[4 * i + 2]) << 64; // uint64
            uint256 y2U256 = uint256(points[4 * i + 3]); // uint64
            uint256 zip = x1U256 | y1U256 | x2U256 | y2U256;
            lines[i] = zip;
        }
    }

    function getBondIndex() public view returns (uint256) {
        return bondIndex;
    }

    function nextBondGroupID() public view returns (uint256) {
        return bondIndex + 1;
    }

    function getFnMap(bytes32 fnMapID) public view returns (bytes memory) {
        return fnMapIDTofnMap[fnMapID];
    }

    function getBond(bytes32 bondID)
        external
        view
        returns (
            address bondAddress,
            uint256 maturity,
            uint64 solidStrikePrice,
            bytes32 fnMapID
        )
    {
        uint256 bondGroupID = BondToGroup[bondID];
        return (
            bondToAddress[bondID],
            bondGroups[bondGroupID].maturity,
            uint64(BondStrikePrice[bondID]),
            bondIDTofnMapID[bondID]
        );
    }

    function getBondGroup(uint256 bondGroupID)
        external
        view
        returns (bytes32[] memory, uint256)
    {
        return (
            bondGroups[bondGroupID].bondIDs,
            bondGroups[bondGroupID].maturity
        );
    }
}

contract TestBondMaker is TestBaseBondMaker, TransferETH {
    function registerBondPair(uint256 maturity, uint256 strikePrice) public {
        testBondToken sbtBond = new testBondToken();
        bytes32 sbtBondID = keccak256(abi.encode(address(sbtBond), bondIndex));
        for (uint256 k = 0; k < 2; k++) {
            bondIndex += 1;
            bondGroups[bondIndex].maturity = maturity;
            uint256 bondLength = k == 0 ? 2 : 4;

            for (uint256 j = 0; j < bondLength; j++) {
                if (j == 0) {
                    BondStrikePrice[sbtBondID] = strikePrice;
                    bondGroups[bondIndex].bondIDs.push(sbtBondID);
                    bondToAddress[sbtBondID] = address(sbtBond);
                    BondToGroup[sbtBondID] = bondIndex;
                } else {
                    testBondToken bond = new testBondToken();
                    bytes32 bondID = keccak256(
                        abi.encode(address(bond), bondIndex)
                    );
                    BondStrikePrice[bondID] = 0;
                    bondGroups[bondIndex].bondIDs.push(bondID);
                    bondToAddress[bondID] = address(bond);
                    BondToGroup[bondID] = bondIndex;
                }
            }
        }
    }

    function registerBondPair2(
        uint256 maturity,
        uint256 strikePrice,
        bytes32[] memory fnMapIDs
    ) public {
        testBondToken sbtBond = new testBondToken();
        bytes32 sbtBondID = keccak256(
            abi.encode(address(sbtBond), fnMapIDs[0])
        );
        for (uint256 k = 0; k < 2; k++) {
            bondIndex += 1;
            bondGroups[bondIndex].maturity = maturity;
            uint256 bondLength = k == 0 ? 2 : 4;

            for (uint256 j = 0; j < bondLength; j++) {
                if (j == 0) {
                    BondStrikePrice[sbtBondID] = strikePrice;
                    bondGroups[bondIndex].bondIDs.push(sbtBondID);
                    bondToAddress[sbtBondID] = address(sbtBond);
                    BondToGroup[sbtBondID] = bondIndex;
                    bondIDTofnMapID[sbtBondID] = fnMapIDs[0];
                } else {
                    testBondToken bond = new testBondToken();
                    bytes32 bondID = keccak256(
                        abi.encode(address(bond), fnMapIDs[j])
                    );
                    BondStrikePrice[bondID] = 0;
                    bondGroups[bondIndex].bondIDs.push(bondID);
                    bondToAddress[bondID] = address(bond);
                    BondToGroup[bondID] = bondIndex;
                    bondIDTofnMapID[bondID] = fnMapIDs[j];
                }
            }
        }
    }

    function exchangeEquivalentBonds(
        uint256 inputBondGroupID,
        uint256 outputBondGroupID,
        uint256 amount,
        bytes32[] calldata exceptionBonds
    ) external returns (bool) {
        bytes32[] memory inputBondIDs = bondGroups[inputBondGroupID].bondIDs;
        bytes32[] memory outputBondIDs = bondGroups[outputBondGroupID].bondIDs;
        bytes32 exceptionBondID = exceptionBonds[0];
        for (uint256 i = 1; i < inputBondIDs.length; i++) {
            testBondToken(payable(bondToAddress[inputBondIDs[i]])).burn(
                msg.sender,
                amount
            );
        }
        for (uint256 i = 1; i < outputBondIDs.length; i++) {
            testBondToken(payable(bondToAddress[outputBondIDs[i]])).mint(
                msg.sender,
                amount
            );
        }

        return true;
    }

    function issueNewBonds(uint256 bondGroupID)
        external
        payable
        virtual
        returns (uint256 amount)
    {
        bytes32[] memory bondIDs = bondGroups[bondGroupID].bondIDs;
        amount = msg.value / 10000000000;
        for (uint256 i = 0; i < bondIDs.length; i++) {
            testBondToken(payable(bondToAddress[bondIDs[i]])).mint{
                value: msg.value / bondIDs.length
            }(msg.sender, amount);
        }
    }

    function reverseBondGroupToCollateral(uint256 bondGroupID, uint256 amount)
        external
        returns (bool)
    {
        bytes32[] memory inputBondIDs = bondGroups[bondGroupID].bondIDs;
        for (uint256 i = 1; i < inputBondIDs.length; i++) {
            testBondToken(payable(bondToAddress[inputBondIDs[i]])).burn(
                msg.sender,
                amount
            );
        }
        _transferETH(msg.sender, amount * 10**10);
        return true;
    }
}

contract TestERC20BondMaker is TestBaseBondMaker {
    address collateralAddress;

    constructor(address _collateralAddress) {
        collateralAddress = _collateralAddress;
    }

    function issueNewBonds(uint256 bondGroupID, uint256 amount)
        external
        returns (uint256)
    {
        IERC20(collateralAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );

        bytes32[] memory bondIDs = bondGroups[bondGroupID].bondIDs;
        for (uint256 i = 0; i < bondIDs.length; i++) {
            IERC20(collateralAddress).transfer(
                bondToAddress[bondIDs[i]],
                amount / bondIDs.length
            );
            testErc20BondToken(bondToAddress[bondIDs[i]]).mint(
                msg.sender,
                amount
            );
        }
        return amount;
    }

    function registerBondPair(uint256 maturity, uint256 strikePrice) public {
        testErc20BondToken sbtBond = new testErc20BondToken(collateralAddress);
        bytes32 sbtBondID = keccak256(abi.encode(address(sbtBond), bondIndex));
        for (uint256 k = 0; k < 2; k++) {
            bondIndex += 1;
            bondGroups[bondIndex].maturity = maturity;
            uint256 bondLength = k == 0 ? 2 : 4;

            for (uint256 j = 0; j < bondLength; j++) {
                if (j == 0) {
                    BondStrikePrice[sbtBondID] = strikePrice;
                    bondGroups[bondIndex].bondIDs.push(sbtBondID);
                    bondToAddress[sbtBondID] = address(sbtBond);
                    BondToGroup[sbtBondID] = bondIndex;
                } else {
                    testErc20BondToken bond = new testErc20BondToken(
                        collateralAddress
                    );
                    bytes32 bondID = keccak256(
                        abi.encode(address(bond), bondIndex)
                    );
                    BondStrikePrice[bondID] = 0;
                    bondGroups[bondIndex].bondIDs.push(bondID);
                    bondToAddress[bondID] = address(bond);
                    BondToGroup[bondID] = bondIndex;
                }
            }
        }
        BondGroupNumber += 2;
    }

    function registerBondPair2(
        uint256 maturity,
        uint256 strikePrice,
        bytes32[] memory fnMapIDs
    ) public {
        testErc20BondToken sbtBond = new testErc20BondToken(collateralAddress);
        bytes32 sbtBondID = keccak256(
            abi.encode(address(sbtBond), fnMapIDs[0])
        );
        for (uint256 k = 0; k < 2; k++) {
            bondIndex += 1;
            bondGroups[bondIndex].maturity = maturity;
            uint256 bondLength = k == 0 ? 2 : 4;

            for (uint256 j = 0; j < bondLength; j++) {
                if (j == 0) {
                    BondStrikePrice[sbtBondID] = strikePrice;
                    bondGroups[bondIndex].bondIDs.push(sbtBondID);
                    bondToAddress[sbtBondID] = address(sbtBond);
                    BondToGroup[sbtBondID] = bondIndex;
                    bondIDTofnMapID[sbtBondID] = fnMapIDs[0];
                } else {
                    testErc20BondToken bond = new testErc20BondToken(
                        collateralAddress
                    );
                    bytes32 bondID = keccak256(
                        abi.encode(address(bond), fnMapIDs[j])
                    );
                    BondStrikePrice[bondID] = 0;
                    bondGroups[bondIndex].bondIDs.push(bondID);
                    bondToAddress[bondID] = address(bond);
                    BondToGroup[bondID] = bondIndex;
                    bondIDTofnMapID[bondID] = fnMapIDs[j];
                }
            }
        }
        BondGroupNumber += 2;
    }

    function exchangeEquivalentBonds(
        uint256 inputBondGroupID,
        uint256 outputBondGroupID,
        uint256 amount,
        bytes32[] calldata exceptionBonds
    ) external returns (bool) {
        bytes32[] memory inputBondIDs = bondGroups[inputBondGroupID].bondIDs;
        bytes32[] memory outputBondIDs = bondGroups[outputBondGroupID].bondIDs;
        bytes32 exceptionBondID = exceptionBonds[0];
        for (uint256 i = 1; i < inputBondIDs.length; i++) {
            testErc20BondToken(bondToAddress[inputBondIDs[i]]).burn(
                msg.sender,
                amount
            );
        }
        for (uint256 i = 1; i < outputBondIDs.length; i++) {
            testErc20BondToken(bondToAddress[outputBondIDs[i]]).mint(
                msg.sender,
                amount
            );
        }

        return true;
    }

    function reverseBondGroupToCollateral(uint256 bondGroupID, uint256 amount)
        external
        returns (bool)
    {
        bytes32[] memory inputBondIDs = bondGroups[bondGroupID].bondIDs;
        for (uint256 i = 1; i < inputBondIDs.length; i++) {
            testBondToken(payable(bondToAddress[inputBondIDs[i]])).burn(
                msg.sender,
                amount
            );
        }
        IERC20(collateralAddress).transfer(msg.sender, amount);
        return true;
    }
}
