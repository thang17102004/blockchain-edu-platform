// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * Verification.sol — Hợp đồng xác minh chứng chỉ
 * ------------------------------------------------
 * 📌 Mục tiêu:
 *  - Doanh nghiệp nhập: certHash, issuerExpected, signature
 *  - Hệ thống kiểm: certHash đã đăng ký? issuer có khớp? chữ ký có do issuer ký?
 *  - Trả về: true/false (đúng/sai), không ghi trạng thái on-chain
 *
 * ⚠️ Ký theo EIP-191 (signMessage) => dùng toEthSignedMessageHash trước khi recover.
 */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// (MỚI) OpenZeppelin v5 tách toEthSignedMessageHash sang MessageHashUtils
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * Giao tiếp tối thiểu với Certificate.sol:
 * - certificates(certHash) trả về (student, issuer, isRegistered)
 *   để ta đối chiếu issuer & tình trạng đăng ký.
 */
interface ICertificate {
    function certificates(bytes32 certHash)
        external
        view
        returns (address studentAddress, address issuerAddress, bool isRegistered);
}

contract Verification {
    using ECDSA for bytes32;
    // (MỚI) enable certHash.toEthSignedMessageHash()
    using MessageHashUtils for bytes32;

    /// Địa chỉ hợp đồng Certificate đã triển khai (immutable để tiết kiệm gas)
    ICertificate public immutable certContract;

    constructor(address certificateContractAddress) {
        require(certificateContractAddress != address(0), "Zero certificate addr");
        certContract = ICertificate(certificateContractAddress);
    }

    /**
     * @notice Xác minh chứng chỉ dựa trên hash, issuer kỳ vọng và chữ ký của issuer.
     * @param certHash        Hash (bytes32) của nội dung chứng chỉ (đã chuẩn hoá & keccak256 off-chain)
     * @param issuerExpected  Địa chỉ ví trường phát hành mà bên xác minh kỳ vọng
     * @param signature       Chữ ký ECDSA do issuer ký trên certHash theo EIP-191 (signMessage)
     * @return isValid        true nếu hợp lệ; false nếu chữ ký không khớp (các lỗi dữ liệu sẽ revert)
     *
     * Quy trình:
     * 1) Lấy (student, issuer, isRegistered) từ Certificate bằng certHash.
     * 2) Yêu cầu certHash đã đăng ký & issuer trong sổ cái == issuerExpected.
     * 3) Tạo messageHash chuẩn EIP-191 từ certHash rồi recover signer từ signature.
     * 4) Hợp lệ nếu recoveredSigner == issuerExpected.
     */
    function verifyCertificate(
        bytes32 certHash,
        address issuerExpected,
        bytes calldata signature
    ) external view returns (bool isValid) {
        (, address issuerOnChain, bool isRegistered) = certContract.certificates(certHash);

        // 1) certHash phải tồn tại trong sổ cái phát hành
        require(isRegistered, "Certificate: hash not registered");

        // 2) Issuer trong sổ cái phải khop issuerExpected
        require(issuerOnChain == issuerExpected, "Certificate: issuer mismatch");

        // 3) Xac minh chu ky (EIP-191): signMessage(arrayify(certHash))
        bytes32 messageHash = certHash.toEthSignedMessageHash(); // <— ĐÃ ĐỔI
        address recoveredSigner = ECDSA.recover(messageHash, signature);

        // 4) Kết luận
        return (recoveredSigner == issuerExpected);
    }

    /**
     * @notice Tiện ích: trả ra địa chỉ đã ký (phục vụ debug client).
     * @dev Không đụng tới Certificate, chỉ recover từ certHash + signature.
     */
    function recoverSigner(bytes32 certHash, bytes calldata signature)
        external
        pure
        returns (address)
    {
        return ECDSA.recover(certHash.toEthSignedMessageHash(), signature); // <— ĐÃ ĐỔI
    }
}
