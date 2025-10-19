// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// Import thư viện ECDSA từ OpenZeppelin để dùng hàm recover
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// Khai báo giao diện (Interface) để gọi hàm từ Hợp đồng Certificate.sol
interface ICertificate {
    // Định nghĩa hàm mapping (view function) để lấy dữ liệu chứng chỉ
    function certificates(bytes32 _certHash) 
        external 
        view 
        returns (address studentAddress, address issuerAddress, bool isRegistered);
}

/**
 * @title Verification
 * @dev Hợp đồng cho phép doanh nghiệp xác minh chứng chỉ dựa trên hash, issuer và chữ ký.
 */
contract Verification {
    using ECDSA for bytes32; 
    
    ICertificate public certContract;

    constructor(address _certificateContractAddress) {
        // Thiết lập liên kết đến hợp đồng Certificate đã triển khai
        certContract = ICertificate(_certificateContractAddress);
    }

    /**
     * @dev Hàm chính để xác minh tính hợp lệ của Chứng chỉ.
     * @param _certHash Hash của chứng chỉ.
     * @param _issuerExpected Địa chỉ của trường mà sinh viên khẳng định phát hành.
     * @param _signature Chữ ký điện tử của Issuer trên mã hash chứng chỉ.
     * @return isVerified True nếu chứng chỉ hợp lệ.
     */
    function verifyCertificate(
        bytes32 _certHash,
        address _issuerExpected,
        bytes memory _signature
    ) public view returns (bool isVerified) {
        // Lấy dữ liệu đã đăng ký từ hợp đồng Certificate.sol
        (address registeredStudent, address registeredIssuer, bool isRegistered) = certContract.certificates(_certHash);

        // 1. Kiểm tra Hash và Issuer
        require(isRegistered, "Certificate hash not registered (Invalid hash or not issued)");
        require(registeredIssuer == _issuerExpected, "Registered Issuer mismatch (Issuer address is wrong)");

        // 2. KHỐI LỆNH ĐÃ SỬA: Xác minh Chữ ký
        // Tách quá trình xử lý hash thành hai bước để tránh lỗi cú pháp:
        
        // 2a. Tạo hash có tiền tố theo chuẩn Ethereum (EIP-191)
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(_certHash);
        
        // 2b. Phục hồi địa chỉ người ký bằng messageHash
        address recoveredSigner = ECDSA.recover(messageHash, _signature);
        
        // 3. Kết luận: Chữ ký phải được ký bởi đúng Issuer đã đăng ký.
        return recoveredSigner == _issuerExpected;
    }
}