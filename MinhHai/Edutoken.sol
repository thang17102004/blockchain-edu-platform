// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EduTokenSimple {
    // ====== Thông tin cơ bản về Token ======
    string public name = "EduToken";
    string public symbol = "EDU";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    // Ai đang giữ bao nhiêu token?
    mapping(address => uint256) public balanceOf;

    // ====== Các hành động cần trả phí ======
    enum Action { UploadCV, VerifyProfile, AccessProfile }

    // Phí cho từng hành động, ví dụ: UploadCV = 1 EDU, Verify = 2 EDU,...
    mapping(Action => uint256) public feeByAction;

    // Địa chỉ được nhận tất cả phí (ví dụ admin hoặc treasury)
    address public treasury;

    // ====== Sự kiện ======
    event Transfer(address indexed from, address indexed to, uint256 value);
    event ActionPaid(Action indexed action, address indexed user, uint256 amount);

    // ====== Constructor: chạy khi deploy ======
    constructor(
        uint256 initialSupply,
        address treasuryAddress,
        uint256 feeUpload,
        uint256 feeVerify,
        uint256 feeAccess
    ) {
        treasury = treasuryAddress;
        feeByAction[Action.UploadCV] = feeUpload;
        feeByAction[Action.VerifyProfile] = feeVerify;
        feeByAction[Action.AccessProfile] = feeAccess;

        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply; // Admin giữ toàn bộ token lúc đầu
    }

    // ====== Chuyển token cho người khác ======
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Khong du token");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // ====== Trả phí cho hành động ======
    function payForAction(Action action) external returns (bool) {
        uint256 fee = feeByAction[action];
        require(balanceOf[msg.sender] >= fee, "Khong du token de tra phi");

        balanceOf[msg.sender] -= fee;
        balanceOf[treasury] += fee;

        emit Transfer(msg.sender, treasury, fee);
        emit ActionPaid(action, msg.sender, fee);
        return true;
    }
}
