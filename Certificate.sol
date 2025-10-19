// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Certificate
 * @dev Hợp đồng dùng để Nhà trường (Issuer) phát hành và lưu trữ hash chứng chỉ.
 */
contract Certificate is Ownable {
    // Mapping lưu trữ địa chỉ của các Trường/Issuer được ủy quyền (true nếu được ủy quyền)
    mapping(address => bool) public authorizedIssuers;

    // Struct để lưu trữ chi tiết Chứng chỉ
    struct Cert {
        address studentAddress;  // Địa chỉ ví của sinh viên
        address issuerAddress;   // Địa chỉ ví của trường đã ký
        bool isRegistered;       // Đánh dấu đã được đăng ký
    }

    // Mapping lưu trữ chi tiết chứng chỉ bằng hash
    mapping(bytes32 => Cert) public certificates; // Hash chứng chỉ -> Chi tiết Cert

    // Sự kiện được phát ra khi một chứng chỉ mới được phát hành
    event CertificateIssued(
        bytes32 indexed certHash,
        address indexed student,
        address indexed issuer
    );

    // Khởi tạo Owner là người triển khai
    constructor() Ownable(msg.sender) {} 

    modifier onlyAuthorizedIssuer() {
        require(authorizedIssuers[msg.sender], "Only authorized issuer can issue certificates");
        _;
    }

    /**
     * @dev Đăng ký địa chỉ của Trường/Tổ chức được phép phát hành chứng chỉ.
     */
    function setIssuerAuthorization(address _issuer, bool _status) public onlyOwner {
        authorizedIssuers[_issuer] = _status;
    }

    /**
     * @dev Hàm Phát hành (Lưu trữ) chứng chỉ.
     */
    function issueCertificate(bytes32 _certHash, address _studentAddress)
        public
        onlyAuthorizedIssuer
    {
        require(!certificates[_certHash].isRegistered, "Certificate already issued");

        certificates[_certHash] = Cert({
            studentAddress: _studentAddress,
            issuerAddress: msg.sender,
            isRegistered: true
        });

        emit CertificateIssued(_certHash, _studentAddress, msg.sender);
    }
}