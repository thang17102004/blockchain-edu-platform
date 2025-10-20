// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Certificate {
    // Cấu trúc dữ liệu chứng chỉ
    struct CertificateData {
        string studentName;      // Tên sinh viên
        string courseName;       // Tên khóa học / chuyên ngành
        string certHash;         // Hash của chứng chỉ (dữ liệu PDF, JSON...)
        string signature;        // Chữ ký số của trường
        address studentWallet;   // Địa chỉ ví sinh viên
        uint256 issueDate;       // Ngày phát hành
    }

    address public admin;  // Ví của nhà trường (admin)
    mapping(string => CertificateData) public certificates; // certHash => dữ liệu chứng chỉ

    event CertificateIssued(string certHash, address indexed student);

    constructor() {
        admin = msg.sender; // Người triển khai hợp đồng là admin
    }

    // Modifier chỉ cho phép admin thực hiện
    modifier onlyAdmin() {
        require(msg.sender == admin, "Chi admin moi duoc phep!");
        _;
    }

    // Phát hành chứng chỉ mới
    function issueCertificate(
        string memory _studentName,
        string memory _courseName,
        string memory _certHash,
        string memory _signature,
        address _studentWallet
    ) public onlyAdmin {
        require(bytes(certificates[_certHash].certHash).length == 0, "Chung chi da ton tai!");
        
        certificates[_certHash] = CertificateData({
            studentName: _studentName,
            courseName: _courseName,
            certHash: _certHash,
            signature: _signature,
            studentWallet: _studentWallet,
            issueDate: block.timestamp
        });

        emit CertificateIssued(_certHash, _studentWallet);
    }

    // Kiểm tra chứng chỉ hợp lệ
    function verifyCertificate(string memory _certHash)
        public
        view
        returns (CertificateData memory)
    {
        require(bytes(certificates[_certHash].certHash).length != 0, "Chung chi khong ton tai!");
        return certificates[_certHash];
    }
}
