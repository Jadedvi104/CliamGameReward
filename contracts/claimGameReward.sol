//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract ClaimGameReward is Ownable, ReentrancyGuard {
    uint256 public withdrawalFee = 5000 * 1e18;
    uint256 public maximumWithdraw = 100000 * 1e18;
    uint256 public ecioTax = 10;

    IERC20 ECIO_TOKEN;
    IERC20 LAKRIMA_TOKEN;

    struct Userinfo {
        uint32 lastClaimTime;
        uint32 startCountTime;
        uint256 stackCount;
        uint256 userWithdrawFee;
    }

    /************************ mapping ***************************/
    mapping(address => Userinfo) public userInfo;

    /************************ event ***************************/

    event withdrawEvent(
        address user,
        uint256 amount,
        uint256 dynm,
        uint32 input
    );

    /************************ Setup ***************************/

    function setupEcioContract(IERC20 ecioToken) external onlyOwner {
        ECIO_TOKEN = ecioToken;
    }

    function setupLakrimaContract(IERC20 lakrimaToken) external onlyOwner {
        LAKRIMA_TOKEN = lakrimaToken;
    }

    function setupWithdrawalFee(uint256 newRate) public onlyOwner {
        withdrawalFee = newRate;
    }

    function setupEcioTax(uint256 newRate) public onlyOwner {
        ecioTax = newRate;
    }

    function setupMaximumWithDraw(uint256 newRate) public onlyOwner {
        maximumWithdraw = newRate;
    }

    /************************** View *************************/

    function getNextClaim(address user) public view returns (uint256) {
        return userInfo[user].startCountTime + 36 hours;
    }

    function getUserWithdrawFee(address user) public view returns (uint256) {
        return userInfo[user].userWithdrawFee;
    }

    /************************** Action *************************/

    function withdraw(
        address user,
        uint256 amount,
        uint256 dynmFee,
        uint32 input
    ) external onlyOwner nonReentrant {
        compare36Hours(user);

        uint256 userBalance = ECIO_TOKEN.balanceOf(user);

        if (userInfo[user].stackCount > 1) {
            increaseTax(user);
        } else {
            userInfo[user].userWithdrawFee = withdrawalFee;
            userInfo[user].startCountTime = uint32(block.timestamp);
        }

        require(
            userBalance >= userInfo[user].userWithdrawFee,
            "ECIO: your balance is not enough for the fee"
        );
        require(
            amount <= maximumWithdraw,
            "ECIO: the amount exceeds the limit"
        );

        ECIO_TOKEN.transferFrom(
            user,
            address(this),
            userInfo[user].userWithdrawFee
        );

        if (input == 0) {
            ECIO_TOKEN.transfer(user, amount);
        } else if (input == 1) {
            LAKRIMA_TOKEN.transfer(user, amount);
        }

        userInfo[user].lastClaimTime = uint32(block.timestamp);

        emit withdrawEvent(user, amount, dynmFee, input);
    }

    // increase stackCount if user withdraw within 36 hours
    function compare36Hours(address user) internal {
        uint32 amountTime = uint32(block.timestamp) -
            userInfo[user].startCountTime;
        if (amountTime <= 36 hours) {
            userInfo[user].stackCount = userInfo[user].stackCount + 1;
        } else if (amountTime > 36 hours) {
            userInfo[user].stackCount = 1;
        }
    }

    function increaseTax(address user) internal {
        userInfo[user].userWithdrawFee = calculation(user);
    }

    // calculate fee if user withdraw within 36 hours
    function calculation(address user) public view returns (uint256) {
        uint256 userStackCount = userInfo[user].stackCount - 1;
        uint256 result = withdrawalFee;

        result =
            (result * ((100 + ecioTax)**userStackCount)) /
            (100**userStackCount);

        return result;
    }

    // transfer token
    function transfer(
        address _contractAddress,
        address _to,
        uint256 _amount
    ) public onlyOwner {
        IERC20 _token = IERC20(_contractAddress);
        _token.transfer(_to, _amount);
    }
}
