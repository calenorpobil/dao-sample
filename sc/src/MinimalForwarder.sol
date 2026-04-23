// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MinimalForwarder {
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }

    bytes32 private constant TYPE_HASH = keccak256(
        "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)"
    );

    bytes32 private immutable DOMAIN_SEPARATOR;
    mapping(address => uint256) private _nonces;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("MinimalForwarder"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function getNonce(address from) public view returns (uint256) {
        return _nonces[from];
    }

    function verify(ForwardRequest calldata req, bytes calldata signature) public view returns (bool) {
        address signer = recoverSigner(req, signature);
        return signer == req.from && req.nonce == _nonces[req.from];
    }

    function execute(ForwardRequest calldata req, bytes calldata signature)
        external
        payable
        returns (bool, bytes memory)
    {
        require(verify(req, signature), "MinimalForwarder: invalid signature");

        _nonces[req.from] = req.nonce + 1;

        (bool success, bytes memory result) = req.to.call{gas: req.gas, value: req.value}(
            abi.encodePacked(req.data, req.from)
        );

        return (success, result);
    }

    function getTypedDataHash(ForwardRequest calldata req) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(TYPE_HASH, req.from, req.to, req.value, req.gas, req.nonce, keccak256(req.data)))
            )
        );
    }

    function recoverSigner(ForwardRequest calldata req, bytes calldata signature) internal view returns (address) {
        bytes32 digest = getTypedDataHash(req);
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(digest, v, r, s);
    }

    function splitSignature(bytes calldata sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "MinimalForwarder: invalid signature length");
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
    }
}
