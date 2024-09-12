// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

interface IProxy {
    function read() external view returns (int224 value, uint32 timestamp);

    function api3ServerV1() external view returns (address);
}

contract ExchangeRateAdaptor {
    // Updating the proxy address is a security-critical action which is why
    // we have made it immutable.
    address public immutable proxyA;
    address public immutable proxyB;

    constructor(address _proxyA, address _proxyB) {
        proxyA = _proxyA;
        proxyB = _proxyB;
    }

    function read() external view returns (int224 value, uint32 timestamp) {
        (int224 valueA, uint32 timestampA) = IProxy(proxyA).read();
        (int224 valueB, uint32 timestampB) = IProxy(proxyB).read();
        require(timestampA + 1 days > block.timestamp, "Timestamp older than one day");
        require(timestampB + 1 days > block.timestamp, "Timestamp older than one day");
        value = valueA * valueB / 10 ** 18;
        // returning the oldest timestamp
        timestamp = (timestampA < timestampB) ? timestampA : timestampB;
    }

    function readProxyA() external view returns (int224 value, uint32 timestamp) {
        (value, timestamp) = IProxy(proxyA).read();
    }

    function readProxyB() external view returns (int224 value, uint32 timestamp) {
        (value, timestamp) = IProxy(proxyB).read();
    }
}
