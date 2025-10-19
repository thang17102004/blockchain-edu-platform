// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/* Lấy bản ghi từ Certificate: (student, issuer, isRegistered) */
interface ICertificate {
    function certificates(bytes32 certHash)
        external
        view
        returns (address student, address issuer, bool isRegistered);
}

/*
 * Verification — Xác minh chứng chỉ dựa trên:
 *  - Hash (certHash)
 *  - Issuer (địa chỉ ví trường)
 *  - Chữ ký ECDSA của issuer trên certHash (kiểu signMessage / EIP-191)
 * Đảm bảo: đúng trường phát hành & nội dung không bị chỉnh sửa (hash lệch là fail).
 */
contract Verification {
    ICertificate public immutable cert;

    constructor(address certificateAddress) {
        cert = ICertificate(certificateAddress);
    }

    /// @notice Trả về true nếu chứng chỉ hợp lệ (đúng issuer + chữ ký đúng).
    function verifyCertificate(
        bytes32 certHash,
        address issuerExpected,
        bytes calldata signature
    ) public view returns (bool) {
        // 1) Lấy bản ghi đã đăng ký
        (, address issuer, bool ok) = cert.certificates(certHash);
        if (!ok || issuer != issuerExpected) return false;

        // 2) Tạo digest EIP-191 theo chuẩn "Ethereum Signed Message"
        //    digest = keccak256("\x19Ethereum Signed Message:\n32" || certHash)
        bytes32 digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", certHash)
        );

        // 3) Recover địa chỉ người ký và so khớp với issuerExpected
        address signer = ECDSA.recover(digest, signature);
        return signer == issuerExpected;
    }
}
