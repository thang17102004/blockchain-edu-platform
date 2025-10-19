// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * OpenZeppelin v5 imports:
 * - ERC20, ERC20Burnable: token chuẩn & có burn
 * - Pausable: tạm dừng khi cần
 * - AccessControl: phân quyền admin & backend
 */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EduToken is ERC20, ERC20Burnable, Pausable, AccessControl {
    // Quyền admin mặc định (có thể set phí, đúc token, đổi treasury, pause,...)
    bytes32 public constant DEFAULT_ADMIN_ROLE_ALIAS = DEFAULT_ADMIN_ROLE;
    // Quyền BACKEND: server của bạn dùng quyền này để "thu phí" bằng allowance
    bytes32 public constant BACKEND_ROLE = keccak256("BACKEND_ROLE");

    // Các hành động trong hệ thống
    enum Action {
        UploadCV,        // 0
        VerifyProfile,   // 1
        AccessProfile    // 2
    }

    // Địa chỉ nhận phí
    address public treasury;

    // Bảng phí theo từng hành động (đơn vị: smallest unit của token, mặc định 18 decimals)
    mapping(Action => uint256) public feeByAction;

    // ===== Sự kiện =====
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event FeeUpdated(Action indexed action, uint256 oldFee, uint256 newFee);
    event ActionCharged(Action indexed action, address indexed user, uint256 amount, address indexed operator);

    constructor(
        string memory name_,
        string memory symbol_,
        address treasury_,
        uint256 initialSupply_,        // ví dụ: 1_000_000 * 1e18
        uint256 feeUploadCV_,          // ví dụ: 1e18  (1 EDU)
        uint256 feeVerifyProfile_,     // ví dụ: 2e18  (2 EDU)
        uint256 feeAccessProfile_      // ví dụ: 5e17  (0.5 EDU)
    ) ERC20(name_, symbol_) {
        require(treasury_ != address(0), "Treasury is zero");
        treasury = treasury_;

        // Cấp quyền cho deployer làm admin
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // (Tuỳ chọn) cũng có thể grant BACKEND_ROLE cho deployer ngay lúc đầu:
        _grantRole(BACKEND_ROLE, msg.sender);

        // Đúc initial supply cho admin (deployer)
        if (initialSupply_ > 0) {
            _mint(msg.sender, initialSupply_);
        }

        // Set phí mặc định
        feeByAction[Action.UploadCV] = feeUploadCV_;
        feeByAction[Action.VerifyProfile] = feeVerifyProfile_;
        feeByAction[Action.AccessProfile] = feeAccessProfile_;
    }

    // ====== Chức năng thu phí do NGƯỜI DÙNG tự gọi (không cần allowance) ======
    function payForAction(Action action) external whenNotPaused {
        uint256 fee = feeByAction[action];
        require(fee > 0, "Fee is zero");
        _transfer(_msgSender(), treasury, fee);
        emit ActionCharged(action, _msgSender(), fee, _msgSender());
    }

    // ====== Chức năng thu phí do BACKEND gọi thay mặt user (cần allowance) ======
    /**
     * Quy trình:
     * 1) User approve cho địa chỉ BACKEND một hạn mức: approve(backend, N)
     * 2) BACKEND gọi chargeUser(user, action) -> hợp đồng sẽ trừ allowance & chuyển phí về treasury
     */
    function chargeUser(address user, Action action)
        external
        whenNotPaused
        onlyRole(BACKEND_ROLE)
    {
        require(user != address(0), "User is zero");
        uint256 fee = feeByAction[action];
        require(fee > 0, "Fee is zero");

        // Tôn trọng allowance của người dùng dành cho BACKEND (msg.sender)
        _spendAllowance(user, _msgSender(), fee);
        _transfer(user, treasury, fee);
        emit ActionCharged(action, user, fee, _msgSender());
    }

    // ====== Quản trị ======
    function setFee(Action action, uint256 newFee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 old = feeByAction[action];
        feeByAction[action] = newFee;
        emit FeeUpdated(action, old, newFee);
    }

    function setTreasury(address newTreasury)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newTreasury != address(0), "Treasury is zero");
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryChanged(old, newTreasury);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }

    // Admin có thể đúc thêm nếu hệ thống cần (tuỳ mô hình tokenomics)
    function mint(address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _mint(to, amount);
    }

    // Override hook để chặn transfer khi đang pause (trừ mint/burn nội bộ)
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20)
    {
        require(!paused(), "Token paused");
        super._update(from, to, value);
    }
}
