// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Verification - Hợp đồng xác minh chứng chỉ
/// @author ...
/// @notice Cho phép đăng ký issuer, phát hành chứng chỉ (bằng on-chain call hoặc bằng signature), xác minh và thu hồi.
contract Verification {
    address public owner;

    // Issuers được owner phê duyệt
    mapping(address => bool) public isIssuer;

    // Bản ghi chứng chỉ: certHash -> issuerAddress (người phát hành)
    mapping(bytes32 => address) public issuedBy;

    // Nếu true => chứng chỉ đã bị thu hồi (invalid)
    mapping(bytes32 => bool) public revoked;

    /// Events
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address indexed issuer);
    event CertificateIssued(bytes32 indexed certHash, address indexed issuer);
    event CertificateRevoked(bytes32 indexed certHash, address indexed issuer);

    modifier onlyOwner() {
        require(msg.sender == owner, "Chua phai owner");
        _;
    }

    modifier onlyIssuer() {
        require(isIssuer[msg.sender], "Chua phai issuer da dang ky");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// Owner chuyển quyền
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    /// Owner thêm issuer
    function addIssuer(address issuer) external onlyOwner {
        require(issuer != address(0), "Invalid address");
        require(!isIssuer[issuer], "Da la issuer");
        isIssuer[issuer] = true;
        emit IssuerAdded(issuer);
    }

    /// Owner gỡ issuer
    function removeIssuer(address issuer) external onlyOwner {
        require(isIssuer[issuer], "Chua la issuer");
        isIssuer[issuer] = false;
        emit IssuerRemoved(issuer);
    }

    /// Issuer phát hành chứng chỉ bằng cách gọi on-chain (issuer tự đăng)
    /// certHash: keccak256 của nội dung chứng chỉ (ví dụ JSON, hoặc PDF hash)
    function issueCertificateOnChain(bytes32 certHash) external onlyIssuer {
        require(certHash != bytes32(0), "Invalid cert hash");
        require(issuedBy[certHash] == address(0), "Da duoc phat hanh");
        issuedBy[certHash] = msg.sender;
        revoked[certHash] = false;
        emit CertificateIssued(certHash, msg.sender);
    }

    /// Bất kỳ ai cũng có thể nộp certHash + signature do issuer ký off-chain
    /// Nếu signature valid và signer là issuer đã đăng ký => hợp đồng sẽ ghi nhận cert là phát hành bởi signer
    /// signature phải là signature theo chuẩn eth_sign (65 bytes: r(32) + s(32) + v(1))
    function submitCertificateWithSignature(bytes32 certHash, bytes memory signature) external {
        require(certHash != bytes32(0), "Invalid cert hash");
        require(issuedBy[certHash] == address(0), "Da duoc phat hanh");

        address signer = recoverSigner(certHash, signature);
        require(signer != address(0), "Invalid signature");
        require(isIssuer[signer], "Signer khong phai issuer da dang ky");

        issuedBy[certHash] = signer;
        revoked[certHash] = false;
        emit CertificateIssued(certHash, signer);
    }

    /// Owner hoặc issuer (người phát hành) có thể thu hồi chứng chỉ
    function revokeCertificate(bytes32 certHash) external {
        address issuerAddr = issuedBy[certHash];
        require(issuerAddr != address(0), "Chua duoc phat hanh");
        // Chỉ owner hoặc chính issuer mới được revoke
        require(msg.sender == owner || msg.sender == issuerAddr, "Khong co quyen revoke");
        revoked[certHash] = true;
        emit CertificateRevoked(certHash, issuerAddr);
    }

    /// Hàm kiểm tra chứng chỉ: trả về true nếu:
    /// - có bản ghi issuedBy[certHash] (đã được phát hành)
    /// - chưa bị revoke
    /// - (tùy: signature không bắt buộc ở đây vì issuedBy lưu issuer)
    function verifyCertificate(bytes32 certHash) external view returns (bool valid, address issuerAddr, bool isRevoked) {
        issuerAddr = issuedBy[certHash];
        isRevoked = revoked[certHash];
        valid = (issuerAddr != address(0) && !isRevoked);
    }

    /// Helper: xác minh signature (chuẩn Ethereum signed message)
    /// signature: r(32) + s(32) + v(1)
    function recoverSigner(bytes32 certHash, bytes memory signature) public pure returns (address) {
        require(signature.length == 65, "Signature length must be 65");
        bytes32 r;
        bytes32 s;
        uint8 v;

        // signature layout: [0:32] r, [32:64] s, [64] v
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // EIP-191: "\x19Ethereum Signed Message:\n32" + message
        bytes32 ethMessageHash = prefixed(certHash);
        // ecrecover
        address signer = ecrecover(ethMessageHash, v, r, s);
        return signer;
    }

    /// Tạo Ethereum Signed Message hash từ bytes32
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        // note: certHash is already 32 bytes, so length string is "32"
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
