// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/HashedTimelock.sol";

address constant destination = 0x00d5779052B17649349B464A184ada29E43333F4;

bytes32 constant valid_hash_lock_preimage = 0x9F2FCC7C90DE090D6B87CD7E9718C1EA6CB21118FC2D5DE9F97E5DB6AC1E9C10;
bytes32 constant expected_hash_lock = 0xABED1BA808548F4FD0D239C8BA4840C81F52F91C7D8E6543D40ADE934DC7D886;
bytes32 constant expected_contract_id = 0x59B8BE3403E4FC027302D343F99AEC335A1348E354037E04B3CC97C2BBC46D3E;

contract HashedTimelockTest is Test {
	uint248 public value;
    HashedTimelock public htlc;

    function setUp() public {
        htlc = new HashedTimelock();
    }

    function testNewContractStoresContractData() public {
		// Act:
		htlc.newContract{value: 666}(payable(destination), expected_hash_lock, 100);

		// Assert:
		address reciever;
		uint amount;
		bytes32 hashlock;
		uint timelock;
		bool withdrawn;
		bool refunded;
		bytes memory preimage;
		(, reciever, amount, hashlock, timelock, withdrawn, refunded, preimage) =
			htlc.getContract(expected_contract_id);

		assertEq(destination, reciever);
		assertEq(666, amount);
		assertEq(expected_hash_lock, hashlock);
		assertEq(100, timelock);
		assertFalse(withdrawn);
		assertFalse(refunded);
		assertEq(new bytes(0), preimage);
	}

	function iToHex(bytes memory buffer) public pure returns (string memory) {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        return string(abi.encodePacked("0x", converted));
    }

	function testCanWithdrawUsingShortPreimage() public {
		// Arrange:
		//  FTR, sha256 is 1DD8312636F6A0BF3D21FA2855E63072507453E93A5CED4301B364E91C9D87D6
		htlc.newContract{value: 666}(payable(destination), 0x796A3E4EAC5A2BD225C147EE5F358B75255F9782E46DDDA286A2139398A23FB7, 100);

		// Act: withdraw as receiver, use short preimage
		bytes1 preimage1 = 0xCC;
		vm.prank(destination);
		htlc.withdraw(0xFD53FCBA575F2EC2E38DA070859425852063FA6B3903EBA8E4FACBE8482847BB, abi.encodePacked(preimage1));

		// Assert:
		address reciever;
		uint amount;
		bytes32 hashlock;
		uint timelock;
		bool withdrawn;
		bool refunded;
		bytes memory preimage;
		(, reciever, amount, hashlock, timelock, withdrawn, refunded, preimage) =
			htlc.getContract(0xFD53FCBA575F2EC2E38DA070859425852063FA6B3903EBA8E4FACBE8482847BB);

		assertEq(destination, reciever);
		assertEq(666, amount);
		assertEq(0x796A3E4EAC5A2BD225C147EE5F358B75255F9782E46DDDA286A2139398A23FB7, hashlock);
		assertEq(100, timelock);
		assertTrue(withdrawn);
		assertFalse(refunded);
		assertEq(abi.encodePacked(preimage1), preimage);
	}

	function testCanWithdrawUsing32bytePreimage() public {
		// Arrange:
		//  FTR, sha256 is ACE84F09D49226D391E3704FF36B0CB5A61C0A0727E6BC5A7188E5C273A740DB
		htlc.newContract{value: 666}(payable(destination), expected_hash_lock, 100);

		// Act: withdraw as receiver
		vm.prank(destination);
		htlc.withdraw(expected_contract_id, abi.encodePacked(valid_hash_lock_preimage));

		// Assert:
		address reciever;
		uint amount;
		bytes32 hashlock;
		uint timelock;
		bool withdrawn;
		bool refunded;
		bytes memory preimage;
		(, reciever, amount, hashlock, timelock, withdrawn, refunded, preimage) =
			htlc.getContract(expected_contract_id);

		assertEq(destination, reciever);
		assertEq(666, amount);
		assertEq(expected_hash_lock, hashlock);
		assertEq(100, timelock);
		assertTrue(withdrawn);
		assertFalse(refunded);
		assertEq(abi.encodePacked(valid_hash_lock_preimage), preimage);
	}

	function fill(bytes memory buffer, uint fill_byte_value, uint length) public {
		uint256 fill_value = fill_byte_value;
		fill_value = fill_value * 0x101010101010101010101010101010101010101010101010101010101010101;

		assembly {
			let b_addr := add(buffer, 0x20)
			let limit := and(length, not(0x1f))

			for { let i := 0 } lt(i, limit) { i := add(i, 0x20) } {
				mstore(b_addr, fill_value)
				b_addr := add(b_addr, 0x20)
			}

			let leftover := sub(length, limit)
			for { let i := 0 } lt(i, leftover) { i := add(i, 1) } {
				mstore8(b_addr, fill_value)
				b_addr := add(b_addr, 1)
			}
		}
	}

	function testCanWithdrawUsing1MaPreimage() public {
		// Arrange:
		//  FTR, sha256 is CDC76E5C9914FB9281A1C7E284D73E67F1809A48A497200E046D39CCC7112CD0
		htlc.newContract{value: 666}(payable(destination), 0x80D1189477563E1B5206B2749F1AFE4807E5705E8BD77887A60187A712156688, 100);

		// Act: withdraw as receiver
		bytes memory million_a = new bytes(1000000);
		fill(million_a, 0x61, 1000000);

		vm.prank(destination);
		htlc.withdraw(0xFA0DBF1E81F8FA7FEB4A82C9399AF96CB8DD2313177BAB0C8935644B2AA16381, abi.encodePacked(million_a));

		// Assert:
		address reciever;
		uint amount;
		bytes32 hashlock;
		uint timelock;
		bool withdrawn;
		bool refunded;
		bytes memory preimage;
		(, reciever, amount, hashlock, timelock, withdrawn, refunded, preimage) =
			htlc.getContract(0xFA0DBF1E81F8FA7FEB4A82C9399AF96CB8DD2313177BAB0C8935644B2AA16381);

		assertEq(destination, reciever);
		assertEq(666, amount);
		assertEq(0x80D1189477563E1B5206B2749F1AFE4807E5705E8BD77887A60187A712156688, hashlock);
		assertEq(100, timelock);
		assertTrue(withdrawn);
		assertFalse(refunded);
		assertEq(abi.encodePacked(million_a), preimage);
	}

	function testFailCannotWithdrawAsNonReceiver() public {
		// Arrange:
		htlc.newContract{value: 666}(payable(destination), expected_hash_lock, 100);

		// Act + Assert: withdraw as dummy address
		vm.prank(address(0));
		htlc.withdraw(expected_contract_id, abi.encodePacked(valid_hash_lock_preimage));
	}
}
