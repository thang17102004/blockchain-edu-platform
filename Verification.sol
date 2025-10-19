// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interface ERC20 cơ bản
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Verification is IERC20 {
    // Thông tin token ERC20
    string public name = "Certificate Token";
    string public symbol = "CERT";
    uint8 public decimals = 0; // Chứng chỉ không chia nhỏ
    uint256 private _totalSupply;
    
    // Mapping cho ERC20
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Cấu trúc chứng chỉ
    struct Certificate {
        string studentName;      // Tên sinh viên
        string certificateHash;  // Hash của chứng chỉ
        string signature;        // Chữ ký số
        string issuer;           // Tổ chức phát hành
        uint256 issueDate;       // Ngày phát hành
        bool isValid;            // Trạng thái: true = hợp lệ, false = đã thu hồi
        bool exists;             // Kiểm tra chứng chỉ có tồn tại không
    }
    
    // Mapping lưu chứng chỉ theo địa chỉ sinh viên
    mapping(address => Certificate) public certificates;
    
    // Mapping lưu danh sách sinh viên đã được cấp chứng chỉ
    address[] public studentList;
    
    // Mapping kiểm tra sinh viên đã có chứng chỉ chưa
    mapping(address => bool) public hasGraduated;
    
    // Chủ sở hữu contract (trường học/tổ chức)
    address public owner;
    
    // Events
    event CertificateIssued(
        address indexed student,
        string studentName,
        string certificateHash,
        uint256 issueDate
    );
    
    event CertificateRevoked(
        address indexed student,
        string reason
    );
    
    event CertificateVerified(
        address indexed student,
        bool isValid
    );
    
    // Modifier chỉ owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Chi truong phat hanh moi co quyen");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        _totalSupply = 0;
    }
    
    // ==================== CHỨC NĂNG CHÍNH ====================
    
    /**
     * @dev Cấp chứng chỉ cho sinh viên
     * Cho phép doanh nghiệp xác minh chứng chỉ của sinh viên dựa trên hash, chữ ký, và issuer
     */
    function issueCertificate(
        address student,
        string memory studentName,
        string memory certificateHash,
        string memory signature,
        string memory issuer
    ) public onlyOwner {
        require(!hasGraduated[student], "Sinh vien da duoc cap chung chi");
        require(student != address(0), "Dia chi sinh vien khong hop le");
        require(bytes(studentName).length > 0, "Ten sinh vien khong duoc trong");
        require(bytes(certificateHash).length > 0, "Hash chung chi khong duoc trong");
        require(bytes(signature).length > 0, "Chu ky khong duoc trong");
        require(bytes(issuer).length > 0, "Ten to chuc phat hanh khong duoc trong");
        
        // Tạo chứng chỉ mới
        certificates[student] = Certificate({
            studentName: studentName,
            certificateHash: certificateHash,
            signature: signature,
            issuer: issuer,
            issueDate: block.timestamp,
            isValid: true,
            exists: true
        });
        
        // Đánh dấu sinh viên đã tốt nghiệp
        hasGraduated[student] = true;
        
        // Thêm vào danh sách sinh viên
        studentList.push(student);
        
        // Mint 1 token cho sinh viên (đại diện cho 1 chứng chỉ)
        _balances[student] += 1;
        _totalSupply += 1;
        
        emit CertificateIssued(student, studentName, certificateHash, block.timestamp);
        emit Transfer(address(0), student, 1);
    }
    
    /**
     * @dev Xác minh chứng chỉ của sinh viên
     * Đảm bảo chứng chỉ do trường phát hành và chưa bị chỉnh sửa
     */
    function verifyCertificate(
        address student,
        string memory certificateHash,
        string memory signature,
        string memory issuer
    ) public view returns (bool isValid, string memory message) {
        // Kiểm tra chứng chỉ có tồn tại không
        if (!certificates[student].exists) {
            return (false, "Chung chi khong ton tai");
        }
        
        Certificate memory cert = certificates[student];
        
        // Kiểm tra chứng chỉ đã bị thu hồi chưa
        if (!cert.isValid) {
            return (false, "Chung chi da bi thu hoi");
        }
        
        // Kiểm tra hash
        if (keccak256(bytes(cert.certificateHash)) != keccak256(bytes(certificateHash))) {
            return (false, "Hash chung chi khong khop");
        }
        
        // Kiểm tra chữ ký
        if (keccak256(bytes(cert.signature)) != keccak256(bytes(signature))) {
            return (false, "Chu ky khong hop le");
        }
        
        // Kiểm tra issuer
        if (keccak256(bytes(cert.issuer)) != keccak256(bytes(issuer))) {
            return (false, "To chuc phat hanh khong khop");
        }
        
        return (true, "Chung chi hop le");
    }
    
    /**
     * @dev Thu hồi chứng chỉ (khi phát hiện gian lận hoặc chứng chỉ không hợp lệ)
     */
    function revokeCertificate(
        address student,
        string memory reason
    ) public onlyOwner {
        require(certificates[student].exists, "Chung chi khong ton tai");
        require(certificates[student].isValid, "Chung chi da bi thu hoi truoc do");
        
        // Đánh dấu chứng chỉ không hợp lệ
        certificates[student].isValid = false;
        
        emit CertificateRevoked(student, reason);
    }
    
    /**
     * @dev Lấy thông tin chi tiết chứng chỉ
     */
    function getCertificateDetails(address student) 
        public 
        view 
        returns (
            string memory studentName,
            string memory certificateHash,
            string memory signature,
            string memory issuer,
            uint256 issueDate,
            bool isValid
        ) 
    {
        require(certificates[student].exists, "Chung chi khong ton tai");
        
        Certificate memory cert = certificates[student];
        return (
            cert.studentName,
            cert.certificateHash,
            cert.signature,
            cert.issuer,
            cert.issueDate,
            cert.isValid
        );
    }
    
    /**
     * @dev Kiểm tra nhanh trạng thái chứng chỉ
     */
    function checkCertificateStatus(address student) 
        public 
        view 
        returns (bool exists, bool isValid) 
    {
        return (certificates[student].exists, certificates[student].isValid);
    }
    
    /**
     * @dev Lấy tổng số chứng chỉ đã phát hành
     */
    function getTotalCertificates() public view returns (uint256) {
        return studentList.length;
    }
    
    /**
     * @dev Lấy danh sách tất cả sinh viên đã được cấp chứng chỉ
     */
    function getAllStudents() public view returns (address[] memory) {
        return studentList;
    }
    
    // ==================== CHỨC NĂNG ERC20 - ĐÃ SỬA ====================
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev Chứng chỉ không thể chuyển nhượng
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert("Chung chi khong the chuyen nhuong");
    }
    
    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }
    
    /**
     * @dev Không cho phép approve vì chứng chỉ không thể chuyển
     */
    function approve(address, uint256) public pure override returns (bool) {
        revert("Chung chi khong the uy quyen");
    }
    
    /**
     * @dev Không cho phép transferFrom vì chứng chỉ không thể chuyển
     */
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert("Chung chi khong the chuyen nhuong");
    }
}